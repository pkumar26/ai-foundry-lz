# Fake placeholder values — replace with your real environment details.

location            = "canadacentral"
resource_group_name = "rg-ai-foundry-lz-fake"
name_prefix         = "myai"

# BYO existing VNet (fake resource ID + firewall IP).
existing_vnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network-hub-fake/providers/Microsoft.Network/virtualNetworks/vnet-shared-eastus2-fake"
firewall_ip_address       = "10.10.0.4"

apim_publisher_email = "platform-team@contoso-fake.com"
apim_publisher_name  = "Contoso Fake AI Platform"

tags = {
  environment = "dev"
  workload    = "ai-foundry"
  owner       = "fake-team"
}

# AI Foundry projects (created in Phase 1). Add entries for more projects.
ai_projects = {
  proj1 = {
    name         = "team-alpha"
    display_name = "Team Alpha"
    description  = "First Foundry project."
  }
}

# ===========================================================================
# Phased rollout switches. Start with everything false (Phase 1), run apply,
# then flip ONE group to true and re-apply. Recommended order below.
# ===========================================================================

# --- Phase 1: baseline (networking + subnets + Log Analytics + Foundry core).
# Nothing extra to enable. Just apply with the switches below all false.
deploy_log_analytics = true

# --- Phase 2: deploy models into Foundry. Add entries to deploy; empty = none.
# Each key is the deployment name. Model + SKU must be available in var.location.
model_deployments = {
  # "gpt-5.5" = {
  #   model_name    = "gpt-5.5"
  #   model_version = "2026-04-24"
  #   sku_type      = "GlobalStandard"
  #   capacity      = 10
  # }
  # "gpt-6-astra" = {
  #   model_name    = "gpt-6-astra"
  #   model_version = "2026-09-03"
  #   sku_type      = "GlobalStandard"
  #   capacity      = 10
  # }
}

# --- Phase 3: GenAI data services.
deploy_genai_key_vault           = false # required by the Jump VM (stores its admin credentials)
deploy_genai_storage             = false
deploy_genai_cosmosdb            = false
deploy_genai_app_configuration   = false
deploy_genai_container_registry  = true
deploy_container_app_environment = false

# Optional GenAI service overrides (defaults shown; uncomment to change).
# ACR (Container Registry) — private endpoint is automatic when public access is off.
acr_name                          = "myaiacrcac001" # globally unique, 5-50 alphanumeric, NO hyphens
acr_sku                           = "Premium"       # required for private endpoints
acr_zone_redundancy_enabled       = true
acr_public_network_access_enabled = false # false -> module creates PE + privatelink.azurecr.io DNS
# ACA (Container Apps environment)
# aca_zone_redundancy_enabled        = true
# aca_internal_load_balancer_enabled = true
# Storage account
# storage_account_tier                  = "Standard"
# storage_account_replication_type      = "GRS"
# storage_access_tier                   = "Hot"
# storage_shared_access_key_enabled     = true
# storage_public_network_access_enabled = false

# --- Phase 4: knowledge services.
deploy_ai_search      = false
deploy_bing_grounding = false

# Optional AI Search overrides. Leave search_service_name unset to auto-generate
# a globally-unique name (avoids 409 name collisions on retries).
# search_service_name    = "ailz-ks-search-cac-001"
# search_sku             = "standard"
# search_replica_count   = 2
# search_partition_count = 1

# --- Phase 5: Foundry AI Agent service (also creates its BYOR data services).
deploy_ai_agent_service = false

# --- Phase 6: AI gateway (APIM is slow to create, ~30-45 min).
deploy_apim               = true
apim_name                 = "myai-apim-cac-001" # fixed name -> predictable gateway host
apim_sku_root             = "StandardV2"        # v2 SKU: public gateway + outbound VNet integration
apim_sku_capacity         = 1
apim_virtual_network_type = "External" # v2 "External" = outbound VNet integration; APIMSubnet is auto-delegated to Microsoft.Web/serverFarms and the gateway stays public
apim_deploy_sample_apis   = true       # sample APIs routing to Foundry (validate connectivity)

# --- Phase 6b: Front Door Premium + WAF -> APIM via managed Private Link.
# StandardV2 APIM keeps a PUBLIC gateway while integrating OUTBOUND into the VNet
# (APIMSubnet delegated to Microsoft.Web/serverFarms) to reach private backends.
# Front Door Premium connects to the APIM "Gateway" group over a managed Private
# Link, so no Load Balancer / Private Link Service is needed. After apply you must
# APPROVE the managed private endpoint on APIM (see the apim_resource_id output).
# front_door_private_link_target_id defaults to the APIM deployed above.
deploy_front_door = true
# front_door_private_link_target_type defaults to "Gateway" (APIM).
# front_door_origin_host_name defaults to "<apim_name>.azure-api.net".
# front_door_waf_mode = "Prevention".

# --- Azure SQL (optional): logical server + database + private endpoint.
deploy_sql_database = false
# sql_server_name      = "myai-sql-cac-001"  # globally unique, lowercase; null auto-generates
# sql_database_name    = "appdb"
# sql_database_sku     = "GP_S_Gen5_2"
# sql_server_version   = "12.0"
# sql_administrator_login = "sqladmin"        # password is generated -> `terraform output -raw sql_administrator_login_password`
# sql_public_network_access_enabled = false   # keep false so only the private endpoint can reach it
# sql_pe_subnet_resource_id defaults to the BYO VNet's PrivateEndpointSubnet

# --- Function App (optional): dedicated Premium v3 app + private-only storage.
# The app gets a delegated VNet-integration subnet and its storage account is
# reachable only through blob/queue/table private endpoints. The host uses its
# managed identity for AzureWebJobsStorage (no keys), with all egress routed
# through the VNet.
deploy_function_app = false
# function_app_name                     = "myai-func-cac-001"
# function_app_storage_name             = "myaifuncsacac001"  # <=24 lowercase alphanumeric, globally unique
# function_app_storage_replication_type = "LRS"
# function_app_subnet_address_prefix    = "10.50.9.0/24"      # must be free in the BYO VNet
# function_app_service_plan_sku         = "P1v3"              # P1v3/P2v3/P3v3 = Premium v3 (dedicated)
# function_app_service_plan_name        = "myai-func-cac-001-plan"  # null derives <function_app_name>-plan
# function_app_worker_count             = 1
# function_app_zone_balancing_enabled   = false              # true needs worker_count >= zones
# function_app_node_version             = "20"
# function_app_pe_subnet_resource_id defaults to the BYO VNet's PrivateEndpointSubnet
# DNS zones: by default the LZ's existing privatelink blob/queue/table zones are reused.
# function_app_create_dns_zones             = false  # true -> create + VNet-link the zones here
# function_app_dns_zone_resource_group_name = null   # RG holding the existing zones (null = resource_group_name)

# --- Phase 7: ops / access (firewall usually external for BYO VNet).
# To reach the Jump VM you need BOTH the Jump VM and Bastion. The Jump VM stores
# its admin credentials in the GenAI Key Vault, so deploy_genai_key_vault must
# also be true (see Phase 3 above).
deploy_bastion  = false
deploy_jumpvm   = false
deploy_buildvm  = false
deploy_firewall = false

# Jump VM customization (optional; defaults shown).
# jumpvm_name = null            # null -> <name_prefix>-jump
# jumpvm_sku  = "Standard_B2s"  # e.g. Standard_D2s_v5 for more horsepower

# Bastion customization (optional; defaults shown).
# bastion_name  = null                  # null -> <name_prefix>-bastion
# bastion_sku   = "Standard"            # Basic | Standard | Premium
# bastion_zones = ["1", "2", "3"]       # zone-redundant by default
