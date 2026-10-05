output "virtual_network" {
  description = "The VNet used by the AI landing zone."
  value       = module.ai_lz.virtual_network
}

output "subnets" {
  description = "Subnets deployed into the BYO VNet."
  value       = module.ai_lz.subnets
}

output "apim" {
  description = "Details of the deployed API Management instance."
  value       = module.ai_lz.apim
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace used for monitoring."
  value       = module.ai_lz.log_analytics_workspace_id
}

output "front_door_endpoints" {
  description = "Front Door endpoint details (null when not deployed)."
  value       = try(module.front_door[0].frontdoor_endpoints, null)
}

output "apim_resource_id" {
  description = "APIM resource ID. Use it to approve Front Door's managed private endpoint connection after apply."
  value       = try(module.ai_lz.apim.resource_id, null)
}

output "sql_server_fqdn" {
  description = "Fully-qualified domain name of the Azure SQL server (null when not deployed)."
  value       = try(module.sql_server[0].resource.fully_qualified_domain_name, null)
}

output "sql_administrator_login_password" {
  description = "Generated SQL administrator password (null when not deployed)."
  value       = try(module.sql_server[0].generated_administrator_login_password, null)
  sensitive   = true
}

output "aca_frontend_fqdn" {
  description = "Internal ingress FQDN of the frontend container app (null when not deployed)."
  value       = try(azurerm_container_app.frontend[0].ingress[0].fqdn, null)
}

output "aca_backend_fqdn" {
  description = "Internal ingress FQDN of the backend container app (null when not deployed)."
  value       = try(azurerm_container_app.backend[0].ingress[0].fqdn, null)
}

output "aca_backend_principal_id" {
  description = "System-assigned identity principal ID of the backend app (grant it SQL/Search access)."
  value       = try(azurerm_container_app.backend[0].identity[0].principal_id, null)
}

output "function_app_default_hostname" {
  description = "Default hostname of the Function App (null when not deployed)."
  value       = try(module.function_app[0].resource_uri, null)
}

output "function_app_principal_id" {
  description = "System-assigned identity principal ID of the Function App (null when not deployed)."
  value       = try(module.function_app[0].system_assigned_mi_principal_id, null)
}

output "function_app_storage_name" {
  description = "Name of the Function App's private storage account (null when not deployed)."
  value       = try(module.function_storage[0].name, null)
}
