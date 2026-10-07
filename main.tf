# Random suffix to keep the globally-unique AI Search name from colliding.
resource "random_string" "search_suffix" {
  length  = 4
  lower   = true
  numeric = true
  special = false
  upper   = false
}

module "ai_lz" {
  source  = "Azure/avm-ptn-aiml-landing-zone/azurerm"
  version = "0.5.2"

  location            = var.location
  resource_group_name = var.resource_group_name
  name_prefix         = var.name_prefix
  tags                = var.tags

  # Standalone deployment (no platform landing zone hub).
  flag_platform_landing_zone = false

  # Route subnet egress directly to the internet. Set to false if the BYO VNet's
  # firewall (firewall_ip_address below) should handle 0.0.0.0/0 egress instead.
  use_internet_routing = true

  # Bring your own existing VNet. The module creates its required subnets inside
  # this VNet, so the deployer needs permission to add subnets to it.
  vnet_definition = {
    existing_byo_vnet = {
      byo = {
        vnet_resource_id    = var.existing_vnet_resource_id
        firewall_ip_address = var.firewall_ip_address
      }
    }

    # Explicit subnet CIDRs (fake). All must sit inside the BYO VNet's address
    # space and must not overlap any existing subnets. Example layout in a /20
    # (10.50.0.0/20). Replace with ranges that are free in your VNet.
    subnets = {
      PrivateEndpointSubnet         = { address_prefix = "10.50.0.0/24" }
      AIFoundrySubnet               = { address_prefix = "10.50.1.0/24" }
      ContainerAppEnvironmentSubnet = { address_prefix = "10.50.2.0/24" }
      APIMSubnet                    = { address_prefix = "10.50.3.0/24" }
      AppGatewaySubnet              = { address_prefix = "10.50.4.0/24" }
      JumpboxSubnet                 = { address_prefix = "10.50.5.0/24" }
      DevOpsBuildSubnet             = { address_prefix = "10.50.6.0/24" }
      AzureFirewallSubnet           = { address_prefix = "10.50.7.0/26" }
      AzureBastionSubnet            = { address_prefix = "10.50.7.64/26" }
    }
  }

  # ---------------------------------------------------------------------------
  # Toggle switches. Flip these in terraform.tfvars to add resources in phases.
  # ---------------------------------------------------------------------------

  law_definition = { deploy = var.deploy_log_analytics }

  # Ops / access (firewall is external for BYO VNet, so default off).
  firewall_definition = { deploy = var.deploy_firewall }
  bastion_definition = {
    deploy = var.deploy_bastion
    name   = var.bastion_name
    sku    = var.bastion_sku
    zones  = var.bastion_zones
  }
  jumpvm_definition = {
    deploy = var.deploy_jumpvm
    name   = var.jumpvm_name
    sku    = var.jumpvm_sku
  }
  buildvm_definition = { deploy = var.deploy_buildvm }

  # App Gateway stays off. The object must be non-null (its default is null) or
  # the WAF-policy submodule fails on a null .deploy. Empty maps satisfy the
  # required fields while deploy = false keeps the gateway from being created.
  app_gateway_definition = {
    deploy                = false
    backend_address_pools = {}
    backend_http_settings = {}
    frontend_ports        = {}
    http_listeners        = {}
    request_routing_rules = {}
  }

  # AI gateway. publisher_* are required by the type even when deploy = false.
  apim_definition = {
    deploy               = var.deploy_apim
    publisher_email      = var.apim_publisher_email
    publisher_name       = var.apim_publisher_name
    name                 = var.apim_name
    sku_root             = var.apim_sku_root
    sku_capacity         = var.apim_sku_capacity
    virtual_network_type = var.apim_virtual_network_type
    deploy_sample_apis   = var.apim_deploy_sample_apis

    # StandardV2 keeps a public gateway (required for Front Door Private Link and
    # the only option allowed at APIM creation time).
    public_network_access_enabled = true

    # System-assigned identity lets APIM authenticate to the Foundry backend.
    managed_identities = {
      system_assigned = true
    }
  }

  # GenAI application services.
  container_app_environment_definition = {
    deploy                         = var.deploy_container_app_environment
    name                           = var.aca_name
    zone_redundancy_enabled        = var.aca_zone_redundancy_enabled
    internal_load_balancer_enabled = var.aca_internal_load_balancer_enabled
  }
  # The GenAI Key Vault is private (PE only) by default. Writing the Jump VM
  # admin password secret from a Terraform CLI outside the VNet needs the vault
  # firewall to allow the deployer's public IP; otherwise the secret write 403s
  # (ForbiddenByConnection). Set deployer_ip_address to open it to just that IP.
  genai_key_vault_definition = {
    deploy                        = var.deploy_genai_key_vault
    public_network_access_enabled = var.genai_key_vault_public_network_access_enabled || var.deployer_ip_address != null
    network_acls = var.deployer_ip_address != null ? {
      bypass         = "AzureServices"
      default_action = "Deny"
      ip_rules       = [var.deployer_ip_address]
    } : null
  }
  genai_storage_account_definition = {
    deploy                        = var.deploy_genai_storage
    name                          = var.storage_name
    account_tier                  = var.storage_account_tier
    account_replication_type      = var.storage_account_replication_type
    access_tier                   = var.storage_access_tier
    shared_access_key_enabled     = var.storage_shared_access_key_enabled
    public_network_access_enabled = var.storage_public_network_access_enabled
  }
  genai_cosmosdb_definition          = { deploy = var.deploy_genai_cosmosdb }
  genai_app_configuration_definition = { deploy = var.deploy_genai_app_configuration }
  genai_container_registry_definition = {
    deploy                        = var.deploy_genai_container_registry
    name                          = var.acr_name
    sku                           = var.acr_sku
    zone_redundancy_enabled       = var.acr_zone_redundancy_enabled
    public_network_access_enabled = var.acr_public_network_access_enabled
  }

  # Knowledge services.
  ks_ai_search_definition = {
    deploy          = var.deploy_ai_search
    name            = coalesce(var.search_service_name, "${var.name_prefix}-search-${random_string.search_suffix.result}")
    sku             = var.search_sku
    replica_count   = var.search_replica_count
    partition_count = var.search_partition_count
  }
  ks_bing_grounding_definition = { deploy = var.deploy_bing_grounding }

  # AI Foundry account + project (always created). Model, agent service, and the
  # agent's BYOR data services are toggled.
  ai_foundry_definition = {
    create_byor = var.deploy_ai_agent_service

    ai_foundry = {
      create_ai_agent_service = var.deploy_ai_agent_service
    }

    ai_model_deployments = {
      for dep_name, m in var.model_deployments : dep_name => {
        name = dep_name
        model = {
          format  = m.format
          name    = m.model_name
          version = m.model_version
        }
        scale = {
          type     = m.sku_type
          capacity = m.capacity
        }
      }
    }

    ai_projects = {
      for k, p in var.ai_projects : k => {
        name                       = p.name
        display_name               = p.display_name
        description                = p.description
        create_project_connections = var.deploy_ai_agent_service
      }
    }
  }
}
