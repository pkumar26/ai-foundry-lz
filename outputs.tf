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
