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
  bastion_definition  = { deploy = var.deploy_bastion }
  jumpvm_definition   = { deploy = var.deploy_jumpvm }
  buildvm_definition  = { deploy = var.deploy_buildvm }

  # AI gateway. publisher_* are required by the type even when deploy = false.
  apim_definition = {
    deploy          = var.deploy_apim
    publisher_email = var.apim_publisher_email
    publisher_name  = var.apim_publisher_name
  }

  # GenAI application services.
  container_app_environment_definition = { deploy = var.deploy_container_app_environment }
  genai_key_vault_definition           = { deploy = var.deploy_genai_key_vault }
  genai_storage_account_definition     = { deploy = var.deploy_genai_storage }
  genai_cosmosdb_definition            = { deploy = var.deploy_genai_cosmosdb }
  genai_app_configuration_definition   = { deploy = var.deploy_genai_app_configuration }
  genai_container_registry_definition  = { deploy = var.deploy_genai_container_registry }

  # Knowledge services.
  ks_ai_search_definition      = { deploy = var.deploy_ai_search }
  ks_bing_grounding_definition = { deploy = var.deploy_bing_grounding }

  # AI Foundry account + project (always created). Model, agent service, and the
  # agent's BYOR data services are toggled.
  ai_foundry_definition = {
    create_byor = var.deploy_ai_agent_service

    ai_foundry = {
      create_ai_agent_service = var.deploy_ai_agent_service
    }

    ai_model_deployments = var.deploy_model ? {
      main = {
        name = var.model_name
        model = {
          format  = var.model_format
          name    = var.model_name
          version = var.model_version
        }
        scale = {
          type     = var.model_sku_type
          capacity = var.model_capacity
        }
      }
    } : {}

    ai_projects = {
      proj1 = {
        name                       = "team-alpha"
        display_name               = "Team Alpha"
        description                = "First Foundry project."
        create_project_connections = var.deploy_ai_agent_service
      }
    }
  }
}
