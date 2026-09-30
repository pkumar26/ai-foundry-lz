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

output "apim_private_ip" {
  description = "Private IP of the internal APIM gateway. Copy into apim_private_ip_address after APIM deploys."
  value       = try(module.ai_lz.apim.private_ip_addresses[0], null)
}
