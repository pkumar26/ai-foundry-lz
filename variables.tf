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

variable "ai_projects" {
  type = map(object({
    name         = string
    display_name = string
    description  = string
  }))
  description = "AI Foundry projects to create. Map key is an arbitrary identifier."
  default = {
    proj1 = {
      name         = "team-alpha"
      display_name = "Team Alpha"
      description  = "First Foundry project."
    }
  }
}

# ---------------------------------------------------------------------------
# Feature toggles. All default to false so you can enable resources in phases.
# ---------------------------------------------------------------------------

variable "deploy_log_analytics" {
  type        = bool
  description = "Deploy the Log Analytics workspace (enables diagnostics)."
  default     = true
}

variable "model_deployments" {
  type = map(object({
    model_name    = string
    model_version = string
    format        = optional(string, "OpenAI")
    sku_type      = optional(string, "GlobalStandard")
    capacity      = optional(number, 10)
  }))
  description = "Models to deploy into Foundry. Map key is the deployment name. Empty = none."
  default     = {}
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

variable "search_service_name" {
  type        = string
  description = "AI Search service name (globally unique). Null auto-generates a unique name."
  default     = null
}

variable "search_sku" {
  type        = string
  description = "AI Search SKU (e.g. basic, standard, standard2, standard3)."
  default     = "standard"
}

variable "search_replica_count" {
  type        = number
  description = "AI Search replica count."
  default     = 2
}

variable "search_partition_count" {
  type        = number
  description = "AI Search partition count."
  default     = 1
}

# --- Container Registry (ACR) ---
variable "acr_name" {
  type        = string
  description = "Container Registry name. Null auto-generates."
  default     = null
}

variable "acr_sku" {
  type        = string
  description = "Container Registry SKU (Basic, Standard, Premium)."
  default     = "Premium"
}

variable "acr_zone_redundancy_enabled" {
  type        = bool
  description = "Enable zone redundancy on the Container Registry (Premium only)."
  default     = true
}

variable "acr_public_network_access_enabled" {
  type        = bool
  description = "Allow public network access to the Container Registry."
  default     = false
}

# --- Container Apps environment (ACA) ---
variable "aca_name" {
  type        = string
  description = "Container Apps environment name. Null auto-generates."
  default     = null
}

variable "aca_zone_redundancy_enabled" {
  type        = bool
  description = "Enable zone redundancy on the Container Apps environment."
  default     = true
}

variable "aca_internal_load_balancer_enabled" {
  type        = bool
  description = "Use an internal load balancer for the Container Apps environment."
  default     = true
}

# --- Storage account ---
variable "storage_name" {
  type        = string
  description = "Storage account name (globally unique, <=24 lowercase alphanumeric). Null auto-generates."
  default     = null
}

variable "storage_account_tier" {
  type        = string
  description = "Storage account performance tier (Standard, Premium)."
  default     = "Standard"
}

variable "storage_account_replication_type" {
  type        = string
  description = "Storage replication type (LRS, ZRS, GRS, GZRS, etc.)."
  default     = "GRS"
}

variable "storage_access_tier" {
  type        = string
  description = "Storage access tier (Hot, Cool)."
  default     = "Hot"
}

variable "storage_shared_access_key_enabled" {
  type        = bool
  description = "Allow shared-key (account key) access to the storage account."
  default     = true
}

variable "storage_public_network_access_enabled" {
  type        = bool
  description = "Allow public network access to the storage account."
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
