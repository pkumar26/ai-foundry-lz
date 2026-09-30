# Internal Load Balancer + Private Link Service fronting the internal APIM, so
# Front Door Premium can reach it privately (Pattern A). Enable with
# deploy_apim_private_link_service (requires deploy_apim and deploy_front_door).
#
# The Load Balancer uses the AVM. Azure has no production AVM for Private Link
# Service yet, so azurerm_private_link_service is used directly.

locals {
  # Prefer the module-created PLS; otherwise fall back to a caller-supplied target.
  front_door_private_link_target_id = var.deploy_apim_private_link_service ? try(azurerm_private_link_service.apim[0].id, null) : var.front_door_private_link_target_id
  # A Private Link Service origin uses no sub-resource type.
  front_door_private_link_target_type = var.deploy_apim_private_link_service ? null : var.front_door_private_link_target_type

  # LB/PLS placement defaults to the BYO VNet and its PrivateEndpointSubnet.
  apim_lb_vnet_resource_id   = coalesce(var.apim_lb_vnet_resource_id, var.existing_vnet_resource_id)
  apim_lb_subnet_resource_id = coalesce(var.apim_lb_subnet_resource_id, "${var.existing_vnet_resource_id}/subnets/PrivateEndpointSubnet")

  # Front Door origin host defaults to the APIM gateway hostname derived from apim_name.
  front_door_origin_host_name = var.front_door_origin_host_name != null ? var.front_door_origin_host_name : (var.apim_name != null ? "${var.apim_name}.azure-api.net" : null)
}

module "apim_lb" {
  count   = var.deploy_apim_private_link_service ? 1 : 0
  source  = "Azure/avm-res-network-loadbalancer/azurerm"
  version = "0.5.0"

  name                = "${var.name_prefix}-apim-ilb"
  location            = var.location
  resource_group_name = var.resource_group_name
  enable_telemetry    = false

  frontend_ip_configurations = {
    feip = {
      name                                   = "apim-frontend"
      frontend_private_ip_address_allocation = "Dynamic"
      frontend_private_ip_subnet_resource_id = local.apim_lb_subnet_resource_id
    }
  }

  backend_address_pools = {
    bepool = {
      name = "apim-backend"
    }
  }

  backend_address_pool_addresses = {
    apim = {
      name                             = "apim-ip"
      backend_address_pool_object_name = "apim-backend"
      ip_address                       = var.apim_private_ip_address
      virtual_network_resource_id      = local.apim_lb_vnet_resource_id
    }
  }

  lb_probes = {
    https = {
      name         = "apim-https"
      protocol     = "Https"
      port         = 443
      request_path = var.front_door_health_probe_path
    }
  }

  lb_rules = {
    https = {
      name                              = "apim-https"
      frontend_ip_configuration_name    = "apim-frontend"
      backend_address_pool_object_names = ["apim-backend"]
      protocol                          = "Tcp"
      frontend_port                     = 443
      backend_port                      = 443
      probe_object_name                 = "apim-https"
    }
  }

  depends_on = [module.ai_lz]
}

resource "azurerm_private_link_service" "apim" {
  count = var.deploy_apim_private_link_service ? 1 : 0

  name                = "${var.name_prefix}-apim-pls"
  location            = var.location
  resource_group_name = var.resource_group_name

  load_balancer_frontend_ip_configuration_ids = [
    module.apim_lb[0].azurerm_lb.frontend_ip_configuration[0].id
  ]

  nat_ip_configuration {
    name      = "primary"
    subnet_id = local.apim_lb_subnet_resource_id
    primary   = true
  }

  tags = var.tags
}
