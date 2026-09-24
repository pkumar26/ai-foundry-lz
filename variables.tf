variable "location" {
  type        = string
  description = "Azure region for all landing zone resources."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group to create for the AI/ML landing zone. Must not already exist."
}

variable "name_prefix" {
  type        = string
  description = "Prefix applied to generated resource names. Keep under 10 lowercase alphanumeric chars."
}

variable "existing_vnet_resource_id" {
  type        = string
  description = "Resource ID of the existing VNet the module will add subnets to (BYO VNet)."
}

variable "firewall_ip_address" {
  type        = string
  description = "IP of the firewall in the BYO VNet used to build subnet route tables. Set null if none."
  default     = null
}

variable "apim_publisher_email" {
  type        = string
  description = "Publisher email for API Management. Only used when deploy_apim is true."
  default     = "DoNotReply@example.com"
}

variable "apim_publisher_name" {
  type        = string
  description = "Publisher name for API Management. Only used when deploy_apim is true."
  default     = "AI Platform"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
  default     = {}
}

# ---------------------------------------------------------------------------
# Feature toggles. All default to false so you can enable resources in phases.
# ---------------------------------------------------------------------------

variable "deploy_log_analytics" {
  type        = bool
  description = "Deploy the Log Analytics workspace (enables diagnostics)."
  default     = true
}

variable "deploy_model" {
  type        = bool
  description = "Deploy a model into the Foundry account (see model_* variables)."
  default     = false
}

variable "model_name" {
  type        = string
  description = "Model name to deploy. Must be available in var.location."
  default     = "gpt-5.5"
}

variable "model_version" {
  type        = string
  description = "Model version to deploy."
  default     = "2026-04-24"
}

variable "model_format" {
  type        = string
  description = "Model format/publisher."
  default     = "OpenAI"
}

variable "model_sku_type" {
  type        = string
  description = "Deployment SKU supported in var.location (e.g. Standard, GlobalStandard, DataZoneStandard)."
  default     = "Standard"
}

variable "model_capacity" {
  type        = number
  description = "Deployment capacity (tokens-per-minute units)."
  default     = 10
}

variable "deploy_genai_key_vault" {
  type        = bool
  description = "Deploy the GenAI Key Vault."
  default     = false
}

variable "deploy_genai_storage" {
  type        = bool
  description = "Deploy the GenAI Storage Account."
  default     = false
}

variable "deploy_genai_cosmosdb" {
  type        = bool
  description = "Deploy the GenAI Cosmos DB account."
  default     = false
}

variable "deploy_genai_app_configuration" {
  type        = bool
  description = "Deploy the GenAI App Configuration store."
  default     = false
}

variable "deploy_genai_container_registry" {
  type        = bool
  description = "Deploy the GenAI Container Registry."
  default     = false
}

variable "deploy_container_app_environment" {
  type        = bool
  description = "Deploy the Container Apps environment for GenAI apps."
  default     = false
}

variable "deploy_ai_search" {
  type        = bool
  description = "Deploy the knowledge-services AI Search."
  default     = false
}

variable "deploy_bing_grounding" {
  type        = bool
  description = "Deploy the Bing Grounding knowledge service."
  default     = false
}

variable "deploy_ai_agent_service" {
  type        = bool
  description = "Enable the Foundry AI Agent service and its BYOR data services."
  default     = false
}

variable "deploy_apim" {
  type        = bool
  description = "Deploy API Management as the AI gateway (slow to create)."
  default     = false
}

variable "deploy_firewall" {
  type        = bool
  description = "Deploy Azure Firewall. Usually external for BYO VNet, so keep false."
  default     = false
}

variable "deploy_bastion" {
  type        = bool
  description = "Deploy Azure Bastion."
  default     = false
}

variable "deploy_jumpvm" {
  type        = bool
  description = "Deploy the Jump VM."
  default     = false
}

variable "deploy_buildvm" {
  type        = bool
  description = "Deploy the Build VM."
  default     = false
}
