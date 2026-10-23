# Workspace-based Application Insights connected to the landing zone's Log Analytics
# workspace (module.ai_lz), built from Azure Verified Modules (AzAPI-based).
# Toggle with deploy_app_insights.
#
#   - avm-res-insights-component -> the component, parented to the LZ resource group
#     and linked to the existing Log Analytics workspace (workspace_id)
#
# Authentication: local (instrumentation-key / connection-string) auth is disabled,
# so clients must use Entra ID. The Function App's system-assigned identity is granted
# Monitoring Metrics Publisher on the component when the Function App is deployed.

locals {
  app_insights_name = coalesce(var.app_insights_name, "${var.name_prefix}-appi-${random_string.search_suffix.result}")
}

module "app_insights" {
  count   = var.deploy_app_insights ? 1 : 0
  source  = "Azure/avm-res-insights-component/azurerm"
  version = "0.5.0"

  name                          = local.app_insights_name
  location                      = var.location
  parent_id                     = local.func_resource_group_id
  workspace_id                  = module.ai_lz.log_analytics_workspace_id
  application_type              = "web"
  retention_in_days             = var.app_insights_retention_in_days
  local_authentication_disabled = true
  internet_ingestion_enabled    = true
  internet_query_enabled        = true
  tags                          = var.tags
  enable_telemetry              = false

  depends_on = [module.ai_lz]
}

# Lets the Function App send telemetry with its managed identity (Entra-only ingestion).
resource "azurerm_role_assignment" "function_app_app_insights" {
  count                            = var.deploy_app_insights && var.deploy_function_app ? 1 : 0
  scope                            = module.app_insights[0].resource_id
  role_definition_name             = "Monitoring Metrics Publisher"
  principal_id                     = module.function_app[0].system_assigned_mi_principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}
