# Linux Function App that reaches its storage account entirely over the private
# network, built from Azure Verified Modules (same AVM approach as sql.tf).
# Toggle with deploy_function_app.
#
#   - avm-res-web-serverfarm         -> the App Service (Premium v3) plan
#   - avm-res-storage-storageaccount -> the app's storage, public access OFF,
#     with blob/queue/table private endpoints wired to the DNS zones below
#   - avm-res-web-site (kind = functionapp) -> the app itself, regional VNet
#     integration with all outbound routed through the VNet, and a passwordless
#     (managed-identity) AzureWebJobsStorage connection
#
# Private connectivity model (same BYO VNet as everything else):
#   - A dedicated, delegated subnet (Microsoft.Web/serverFarms) gives the app
#     regional VNet integration; vnet_route_all_traffic sends all egress there.
#   - The storage account has no public access; the host reaches blob/queue/table
#     through private endpoints that resolve via the privatelink DNS zones.
#   - The app's system-assigned identity authenticates to storage (no keys), so
#     shared-key access is disabled on the account.

locals {
  func_app_name = coalesce(var.function_app_name, "${var.name_prefix}-func-${random_string.search_suffix.result}")

  # Storage account names: <=24 chars, lowercase alphanumeric only.
  func_sa_name = coalesce(
    var.function_app_storage_name,
    substr(lower(replace("${var.name_prefix}func${random_string.search_suffix.result}", "/[^a-z0-9]/", "")), 0, 24)
  )

  func_pe_subnet_resource_id = coalesce(
    var.function_app_pe_subnet_resource_id,
    "${var.existing_vnet_resource_id}/subnets/PrivateEndpointSubnet"
  )

  # Resource group ID (parent_id required by the azapi-based web-site module).
  func_resource_group_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"

  # Parse the BYO VNet resource ID for the integration subnet (created directly,
  # like the other subnets the pattern module adds to the BYO VNet).
  func_vnet_parts = split("/", var.existing_vnet_resource_id)
  func_vnet_rg    = element(local.func_vnet_parts, 4)
  func_vnet_name  = element(local.func_vnet_parts, length(local.func_vnet_parts) - 1)

  # Storage subresource -> private DNS zone for the host's AzureWebJobsStorage
  # (blob for keys/leases, queue for triggers, table for trigger metadata).
  func_sa_private_dns = {
    blob  = "privatelink.blob.core.windows.net"
    queue = "privatelink.queue.core.windows.net"
    table = "privatelink.table.core.windows.net"
  }

  # Resource group holding the privatelink zones (defaults to the LZ's RG).
  func_dns_zone_rg = coalesce(var.function_app_dns_zone_resource_group_name, var.resource_group_name)

  # Zone IDs, whether created here or looked up from the existing LZ zones.
  func_zone_ids = {
    for key, _ in local.func_sa_private_dns : key => (
      var.function_app_create_dns_zones
      ? azurerm_private_dns_zone.function_storage[key].id
      : data.azurerm_private_dns_zone.function_storage[key].id
    )
  }
}

data "azurerm_client_config" "current" {}

# --- Dedicated regional VNet-integration subnet (delegated to serverFarms). ---
resource "azurerm_subnet" "function_integration" {
  count                = var.deploy_function_app ? 1 : 0
  name                 = "FunctionAppSubnet"
  resource_group_name  = local.func_vnet_rg
  virtual_network_name = local.func_vnet_name
  address_prefixes     = [var.function_app_subnet_address_prefix]

  delegation {
    name = "serverFarms"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }

  depends_on = [module.ai_lz]
}

# --- Private DNS zones for the storage subresources. The landing zone usually
# already provides privatelink.{blob,queue,table}.core.windows.net, so by default
# we reference the existing zones; set function_app_create_dns_zones = true to
# create (and VNet-link) them here instead. ---
data "azurerm_private_dns_zone" "function_storage" {
  for_each            = var.deploy_function_app && !var.function_app_create_dns_zones ? local.func_sa_private_dns : {}
  name                = each.value
  resource_group_name = local.func_dns_zone_rg
}

resource "azurerm_private_dns_zone" "function_storage" {
  for_each            = var.deploy_function_app && var.function_app_create_dns_zones ? local.func_sa_private_dns : {}
  name                = each.value
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "function_storage" {
  for_each              = var.deploy_function_app && var.function_app_create_dns_zones ? local.func_sa_private_dns : {}
  name                  = "${var.name_prefix}-func-${each.key}-dnslink"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.function_storage[each.key].name
  virtual_network_id    = var.existing_vnet_resource_id
  tags                  = var.tags
}

# --- Storage account (AVM): private only, shared-key disabled, PEs for the
# blob/queue/table subresources attached to the zones above. ---
module "function_storage" {
  count   = var.deploy_function_app ? 1 : 0
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "0.10.0"

  name             = local.func_sa_name
  location         = var.location
  parent_id        = local.func_resource_group_id
  tags             = var.tags
  enable_telemetry = false

  account_tier                  = "Standard"
  account_replication_type      = var.function_app_storage_replication_type
  account_kind                  = "StorageV2"
  shared_access_key_enabled     = false
  public_network_access_enabled = false

  private_endpoints = {
    for key, zone in local.func_sa_private_dns : key => {
      # Unique per subresource; the module's default name is the same for all PEs.
      name                            = "pe-${local.func_sa_name}-${key}"
      private_service_connection_name = "psc-${local.func_sa_name}-${key}"
      subnet_resource_id              = local.func_pe_subnet_resource_id
      subresource_name                = key
      private_dns_zone_resource_ids   = [local.func_zone_ids[key]]
    }
  }

  depends_on = [module.ai_lz]
}

# --- App Service plan (AVM serverfarm), Premium v3 / Linux. ---
module "function_plan" {
  count   = var.deploy_function_app ? 1 : 0
  source  = "Azure/avm-res-web-serverfarm/azurerm"
  version = "2.0.8"

  name                   = coalesce(var.function_app_service_plan_name, "${local.func_app_name}-plan")
  location               = var.location
  parent_id              = local.func_resource_group_id
  os_type                = "Linux"
  sku_name               = var.function_app_service_plan_sku
  worker_count           = var.function_app_worker_count
  zone_balancing_enabled = var.function_app_zone_balancing_enabled
  tags                   = var.tags
  enable_telemetry       = false
}

# --- Function App (AVM web-site, kind = functionapp). ---
module "function_app" {
  count   = var.deploy_function_app ? 1 : 0
  source  = "Azure/avm-res-web-site/azurerm"
  version = "0.23.0"

  name                     = local.func_app_name
  location                 = var.location
  parent_id                = local.func_resource_group_id
  kind                     = "functionapp"
  os_type                  = "Linux"
  service_plan_resource_id = module.function_plan[0].resource_id
  tags                     = var.tags
  enable_telemetry         = false

  managed_identities = {
    system_assigned = true
  }

  # Passwordless host storage: AzureWebJobsStorage uses the app's managed
  # identity against the account, reached over the private endpoints.
  storage_account_name          = local.func_sa_name
  storage_uses_managed_identity = true

  # Dedicated (Premium v3) plan needs no content share. Leave content share at
  # its default (not force-disabled): forcing it writes WEBSITE_CONTENTSHARE="",
  # which makes Azure demand the paired WEBSITE_CONTENTAZUREFILECONNECTIONSTRING.

  # Regional VNet integration + route all egress (incl. storage) through the VNet.
  virtual_network_subnet_id = azurerm_subnet.function_integration[0].id
  vnet_route_all_traffic    = true

  site_config = {
    application_stack = {
      node = {
        node_version = var.function_app_node_version
      }
    }
  }

  # The storage + its private endpoints must exist before the host starts and
  # tries to reach AzureWebJobsStorage.
  depends_on = [module.function_storage]
}

# --- App identity -> storage data planes (passwordless host access). ---
# Blob Data Owner is required for AzureWebJobsStorage; queue/table cover
# trigger metadata and diagnostic events.
resource "azurerm_role_assignment" "function_storage_blob" {
  count                            = var.deploy_function_app ? 1 : 0
  scope                            = module.function_storage[0].resource_id
  role_definition_name             = "Storage Blob Data Owner"
  principal_id                     = module.function_app[0].system_assigned_mi_principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true

  # AzureRM 4.x re-plans the Computed condition fields as unknown, which is
  # ForceNew and needlessly recreates the assignment on every apply.
  lifecycle {
    ignore_changes = [condition, condition_version]
  }
}

resource "azurerm_role_assignment" "function_storage_queue" {
  count                            = var.deploy_function_app ? 1 : 0
  scope                            = module.function_storage[0].resource_id
  role_definition_name             = "Storage Queue Data Contributor"
  principal_id                     = module.function_app[0].system_assigned_mi_principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true

  lifecycle {
    ignore_changes = [condition, condition_version]
  }
}

resource "azurerm_role_assignment" "function_storage_table" {
  count                            = var.deploy_function_app ? 1 : 0
  scope                            = module.function_storage[0].resource_id
  role_definition_name             = "Storage Table Data Contributor"
  principal_id                     = module.function_app[0].system_assigned_mi_principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true

  lifecycle {
    ignore_changes = [condition, condition_version]
  }
}
