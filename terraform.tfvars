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
deploy_genai_key_vault          = false
deploy_genai_storage            = false
deploy_genai_cosmosdb           = false
deploy_genai_app_configuration  = false
deploy_genai_container_registry = false
deploy_container_app_environment = false

# Optional GenAI service overrides (defaults shown; uncomment to change).
# ACR (Container Registry)
# acr_sku                           = "Premium"
# acr_zone_redundancy_enabled       = true
# acr_public_network_access_enabled = false
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
apim_name                 = "myai-apim-cac-001"  # fixed name -> predictable gateway host
apim_sku_root             = "Developer"          # works with the PLS pattern; Premium/StandardV2 for prod
apim_sku_capacity         = 1
apim_virtual_network_type = "Internal"
apim_deploy_sample_apis   = true          # sample APIs routing to Foundry (validate connectivity)

# --- Phase 6b: Front Door Premium + WAF -> Private Link -> internal APIM.
# TWO-STEP: (1) apply Phase 6 first (leave the two switches below false) so APIM
# exists; read its private IP from the `apim_private_ip` output. (2) set
# apim_private_ip_address to that value, flip both switches true, apply again.
deploy_front_door                = true
deploy_apim_private_link_service = true
apim_private_ip_address          = "10.50.3.10"  # <-- REPLACE with real APIM private IP (see apim_private_ip output)
# front_door_origin_host_name defaults to "<apim_name>.azure-api.net"
# apim_lb_subnet/vnet default to the BYO VNet's PrivateEndpointSubnet
# front_door_waf_mode = "Prevention"

# --- Phase 7: ops / access (firewall usually external for BYO VNet).
deploy_bastion  = false
deploy_jumpvm   = false
deploy_buildvm  = false
deploy_firewall = false
