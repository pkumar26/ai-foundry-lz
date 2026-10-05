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

# --- Container Apps: frontend + backend apps (aca.tf) ---
variable "aca_frontend_app_name" {
  type        = string
  description = "Name of the frontend container app."
  default     = "frontend"
}

variable "aca_backend_app_name" {
  type        = string
  description = "Name of the backend container app."
  default     = "backend"
}

variable "aca_placeholder_image" {
  type        = string
  description = "Placeholder container image used until real images are pushed to ACR."
  default     = "mcr.microsoft.com/k8se/quickstart:latest"
}

variable "aca_frontend_target_port" {
  type        = number
  description = "Container port the frontend app listens on."
  default     = 80
}

variable "aca_backend_target_port" {
  type        = number
  description = "Container port the backend app listens on."
  default     = 80
}

variable "aca_cpu" {
  type        = number
  description = "vCPU allocated to each container app."
  default     = 0.5
}

variable "aca_memory" {
  type        = string
  description = "Memory allocated to each container app (must pair with aca_cpu, e.g. 0.5 vCPU -> 1Gi)."
  default     = "1Gi"
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

# --- APIM customization ---
variable "apim_name" {
  type        = string
  description = "API Management service name. Null auto-generates."
  default     = null
}

variable "apim_sku_root" {
  type        = string
  description = "APIM SKU (Developer, Basic, Standard, Premium, BasicV2, StandardV2, PremiumV2)."
  default     = "Premium"
}

variable "apim_sku_capacity" {
  type        = number
  description = "APIM scale units. Premium minimum is 1."
  default     = 1
}

variable "apim_virtual_network_type" {
  type        = string
  description = "APIM VNet integration type (None, External, Internal)."
  default     = "Internal"
}

variable "apim_deploy_sample_apis" {
  type        = bool
  description = "Deploy sample APIs in APIM that route to AI Foundry (validates connectivity)."
  default     = false
}

# --- Front Door (Pattern A: Premium + Private Link to APIM) ---
variable "deploy_front_door" {
  type        = bool
  description = "Deploy Azure Front Door Premium in front of APIM."
  default     = false
}

variable "front_door_profile_name" {
  type        = string
  description = "Front Door profile name. Null auto-generates."
  default     = null
}

variable "front_door_sku" {
  type        = string
  description = "Front Door SKU. Private Link and managed WAF require Premium_AzureFrontDoor."
  default     = "Premium_AzureFrontDoor"
}

variable "front_door_endpoint_name" {
  type        = string
  description = "Front Door endpoint name. Null auto-generates."
  default     = null
}

variable "front_door_origin_host_name" {
  type        = string
  description = "Backend host name Front Door routes to (e.g. the APIM gateway hostname). Required when deploy_front_door is true."
  default     = null
}

variable "front_door_origin_host_header" {
  type        = string
  description = "Host header sent to the origin. Defaults to front_door_origin_host_name."
  default     = null
}

variable "front_door_private_link_target_id" {
  type        = string
  description = "Resource ID of the Private Link target (e.g. a Private Link Service fronting internal APIM). Null = public origin (no Private Link)."
  default     = null
}

variable "front_door_private_link_target_type" {
  type        = string
  description = "Front Door Private Link sub-resource type (e.g. Gateway for APIM, sites for App Service, blob for Storage)."
  default     = "Gateway"
}

variable "front_door_private_link_location" {
  type        = string
  description = "Region of the Private Link target. Defaults to var.location."
  default     = null
}

variable "front_door_route_patterns" {
  type        = list(string)
  description = "URL patterns Front Door routes to the origin."
  default     = ["/*"]
}

variable "front_door_forwarding_protocol" {
  type        = string
  description = "Protocol Front Door uses to the origin (HttpOnly, HttpsOnly, MatchRequest)."
  default     = "HttpsOnly"
}

variable "front_door_health_probe_path" {
  type        = string
  description = "Origin health probe path. APIM default status endpoint is /status-0123456789abcdef."
  default     = "/status-0123456789abcdef"
}

variable "front_door_waf_enabled" {
  type        = bool
  description = "Attach a managed WAF policy to the Front Door endpoint."
  default     = true
}

variable "front_door_waf_mode" {
  type        = string
  description = "WAF mode (Prevention or Detection)."
  default     = "Prevention"
}

# --- Azure SQL (optional): server + database + private endpoint ---
variable "deploy_sql_database" {
  type        = bool
  description = "Deploy an Azure SQL logical server + database with a private endpoint."
  default     = false
}

variable "sql_server_name" {
  type        = string
  description = "Name of the Azure SQL logical server (globally unique, lowercase, 1-63 chars). Null auto-generates."
  default     = null
}

variable "sql_database_name" {
  type        = string
  description = "Name of the Azure SQL database."
  default     = "appdb"
}

variable "sql_server_version" {
  type        = string
  description = "Azure SQL server version. 12.0 is the current v12 server."
  default     = "12.0"
}

variable "sql_database_sku" {
  type        = string
  description = "SKU for the SQL database (e.g. GP_S_Gen5_2, S0, Basic)."
  default     = "GP_S_Gen5_2"
}

variable "sql_administrator_login" {
  type        = string
  description = "SQL administrator login name. A random password is generated and exposed via the sql_administrator_login_password output."
  default     = "sqladmin"
}

variable "sql_public_network_access_enabled" {
  type        = bool
  description = "Allow public network access to the SQL server. Keep false so only the private endpoint can reach it."
  default     = false
}

variable "sql_pe_subnet_resource_id" {
  type        = string
  description = "Subnet resource ID for the SQL private endpoint. Defaults to the BYO VNet's PrivateEndpointSubnet."
  default     = null
}

# --- Function App (optional): Elastic Premium app + private-only storage ---
variable "deploy_function_app" {
  type        = bool
  description = "Deploy a Linux Function App that reaches its storage account over private endpoints."
  default     = false
}

variable "function_app_name" {
  type        = string
  description = "Function App name. Null auto-generates from name_prefix + suffix."
  default     = null
}

variable "function_app_storage_name" {
  type        = string
  description = "Function App storage account name (globally unique, <=24 lowercase alphanumeric). Null auto-generates."
  default     = null
}

variable "function_app_storage_replication_type" {
  type        = string
  description = "Replication type for the Function App storage account (LRS, ZRS, GRS, etc.)."
  default     = "LRS"
}

variable "function_app_subnet_address_prefix" {
  type        = string
  description = "CIDR for the Function App's delegated VNet-integration subnet. Must be free inside the BYO VNet and not overlap the module's subnets."
  default     = "10.50.9.0/24"
}

variable "function_app_pe_subnet_resource_id" {
  type        = string
  description = "Subnet resource ID for the Function App storage private endpoints. Defaults to the BYO VNet's PrivateEndpointSubnet."
  default     = null
}

variable "function_app_service_plan_sku" {
  type        = string
  description = "Function App plan SKU. P1v3/P2v3/P3v3 are Premium v3 (dedicated, support VNet integration + passwordless storage without a content share)."
  default     = "P1v3"
}

variable "function_app_service_plan_name" {
  type        = string
  description = "Function App service plan name. Null derives it from the app name (<function_app_name>-plan)."
  default     = null
}

variable "function_app_worker_count" {
  type        = number
  description = "Number of workers (instances) for the Function App plan."
  default     = 1
}

variable "function_app_zone_balancing_enabled" {
  type        = bool
  description = "Spread the Function App plan across availability zones. Requires worker_count >= number of zones and a zone-capable region/SKU."
  default     = false
}

variable "function_app_node_version" {
  type        = string
  description = "Node.js runtime version for the Function App (e.g. 18, 20)."
  default     = "20"
}
