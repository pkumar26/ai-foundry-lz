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
