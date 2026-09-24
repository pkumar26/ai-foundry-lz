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

# ===========================================================================
# Phased rollout switches. Start with everything false (Phase 1), run apply,
# then flip ONE group to true and re-apply. Recommended order below.
# ===========================================================================

# --- Phase 1: baseline (networking + subnets + Log Analytics + Foundry core).
# Nothing extra to enable. Just apply with the switches below all false.
deploy_log_analytics = true

# --- Phase 2: deploy a model into Foundry (must be available in var.location).
deploy_model   = false
model_name     = "gpt-5.5"
model_version  = "2026-04-24"
model_sku_type = "Standard"

# --- Phase 3: GenAI data services.
deploy_genai_key_vault          = false
deploy_genai_storage            = false
deploy_genai_cosmosdb           = false
deploy_genai_app_configuration  = false
deploy_genai_container_registry = false
deploy_container_app_environment = false

# --- Phase 4: knowledge services.
deploy_ai_search      = false
deploy_bing_grounding = false

# --- Phase 5: Foundry AI Agent service (also creates its BYOR data services).
deploy_ai_agent_service = false

# --- Phase 6: AI gateway (APIM is slow to create, ~30-45 min).
deploy_apim = false

# --- Phase 7: ops / access (firewall usually external for BYO VNet).
deploy_bastion  = false
deploy_jumpvm   = false
deploy_buildvm  = false
deploy_firewall = false
