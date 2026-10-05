# Azure SQL logical server + database with a private endpoint. Toggle with
# deploy_sql_database. The AI/ML landing zone pattern module has no SQL
# definition, so the AVM SQL server resource module is used directly.

locals {
  sql_pe_subnet_resource_id = coalesce(var.sql_pe_subnet_resource_id, "${var.existing_vnet_resource_id}/subnets/PrivateEndpointSubnet")

  # The SQL server module does not auto-generate a name, so build one from the
  # name prefix + random suffix when sql_server_name is null (globally unique).
  sql_server_name = coalesce(var.sql_server_name, "${var.name_prefix}-sql-${random_string.search_suffix.result}")
}

# SQL private endpoints resolve against privatelink.database.windows.net. The
# pattern module doesn't create this zone (no SQL), so create + link it here.
resource "azurerm_private_dns_zone" "sql" {
  count               = var.deploy_sql_database ? 1 : 0
  name                = "privatelink.database.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
  count                 = var.deploy_sql_database ? 1 : 0
  name                  = "${var.name_prefix}-sql-dnslink"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.sql[0].name
  virtual_network_id    = var.existing_vnet_resource_id
  tags                  = var.tags
}

module "sql_server" {
  count   = var.deploy_sql_database ? 1 : 0
  source  = "Azure/avm-res-sql-server/azurerm"
  version = "0.2.1"

  name                = local.sql_server_name
  location            = var.location
  resource_group_name = var.resource_group_name
  server_version      = var.sql_server_version
  tags                = var.tags
  enable_telemetry    = false

  # Local SQL auth with a module-generated password (see output below).
  administrator_login                   = var.sql_administrator_login
  generate_administrator_login_password = true

  public_network_access_enabled = var.sql_public_network_access_enabled

  databases = {
    db = {
      name     = var.sql_database_name
      sku_name = var.sql_database_sku
    }
  }

  private_endpoints = {
    sql = {
      subnet_resource_id            = local.sql_pe_subnet_resource_id
      subresource_name              = "sqlServer"
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.sql[0].id]
    }
  }

  depends_on = [module.ai_lz]
}
