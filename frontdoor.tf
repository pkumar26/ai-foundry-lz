# Azure Front Door (Premium) via the AVM CDN profile module — global edge + WAF in
# front of APIM through a managed Private Link. Toggle with deploy_front_door.
#
# APIM runs as StandardV2 with a public gateway + outbound VNet integration, so
# Front Door targets the APIM "Gateway" group directly (see apim-privatelink.tf).
# The target defaults to the module's APIM; override via front_door_private_link_
# target_id. The managed private endpoint must be approved on APIM after apply.
#
# When the Container Apps environment is also deployed, the frontend app is
# published through a second Front Door endpoint via a managed Private Link to the
# ACA environment (internal LB). Its managed private endpoint must also be
# approved (on the Container Apps environment) after apply.

locals {
  # Add the ACA frontend to Front Door only when both are deployed.
  aca_fd_enabled       = var.deploy_front_door && var.deploy_container_app_environment
  aca_fd_frontend_fqdn = try(azurerm_container_app.frontend[0].ingress[0].fqdn, null)
  aca_fd_env_id        = local.aca_env_id
}

module "front_door" {
  count   = var.deploy_front_door ? 1 : 0
  source  = "Azure/avm-res-cdn-profile/azurerm"
  version = "0.1.9"

  name                = coalesce(var.front_door_profile_name, "${var.name_prefix}-afd")
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.front_door_sku
  tags                = var.tags
  enable_telemetry    = false

  front_door_endpoints = merge(
    {
      ep = {
        name = coalesce(var.front_door_endpoint_name, "${var.name_prefix}-afd-ep")
      }
    },
    local.aca_fd_enabled ? {
      fe = {
        name = "${var.name_prefix}-afd-fe-ep"
      }
    } : {}
  )

  front_door_origin_groups = merge(
    {
      og = {
        name = "og-apim"
        load_balancing = {
          lb = {}
        }
        health_probe = {
          hp = {
            interval_in_seconds = 100
            path                = var.front_door_health_probe_path
            protocol            = "Https"
            request_type        = "GET"
          }
        }
      }
    },
    local.aca_fd_enabled ? {
      og_fe = {
        name = "og-frontend"
        load_balancing = {
          lb = {}
        }
        health_probe = {
          hp = {
            interval_in_seconds = 100
            path                = "/"
            protocol            = "Https"
            request_type        = "GET"
          }
        }
      }
    } : {}
  )

  front_door_origins = merge(
    {
      apim = {
        name                           = "origin-apim"
        origin_group_key               = "og"
        host_name                      = local.front_door_origin_host_name
        origin_host_header             = coalesce(var.front_door_origin_host_header, local.front_door_origin_host_name)
        certificate_name_check_enabled = true
        # Private Link to the APIM "Gateway" group. Gated on a plan-time-known switch
        # so the origins map shape doesn't depend on an apply-time target id.
        private_link = local.front_door_use_private_link ? {
          pl = {
            request_message        = "Front Door Private Link for AI landing zone"
            target_type            = local.front_door_private_link_target_type
            location               = coalesce(var.front_door_private_link_location, var.location)
            private_link_target_id = local.front_door_private_link_target_id
          }
        } : null
      }
    },
    local.aca_fd_enabled ? {
      frontend = {
        name                           = "origin-frontend"
        origin_group_key               = "og_fe"
        host_name                      = local.aca_fd_frontend_fqdn
        origin_host_header             = local.aca_fd_frontend_fqdn
        certificate_name_check_enabled = true
        # Managed Private Link to the ACA environment (internal LB). Approve the
        # resulting private endpoint on the Container Apps environment after apply.
        private_link = {
          pl = {
            request_message        = "Front Door Private Link for ACA frontend"
            target_type            = "managedEnvironments"
            location               = var.location
            private_link_target_id = local.aca_fd_env_id
          }
        }
      }
    } : {}
  )

  front_door_routes = merge(
    {
      route = {
        name                   = "route-apim"
        endpoint_key           = "ep"
        origin_group_key       = "og"
        origin_keys            = ["apim"]
        patterns_to_match      = var.front_door_route_patterns
        supported_protocols    = ["Http", "Https"]
        forwarding_protocol    = var.front_door_forwarding_protocol
        https_redirect_enabled = true
        link_to_default_domain = true
      }
    },
    local.aca_fd_enabled ? {
      route_fe = {
        name                   = "route-frontend"
        endpoint_key           = "fe"
        origin_group_key       = "og_fe"
        origin_keys            = ["frontend"]
        patterns_to_match      = ["/*"]
        supported_protocols    = ["Http", "Https"]
        forwarding_protocol    = "HttpsOnly"
        https_redirect_enabled = true
        link_to_default_domain = true
      }
    } : {}
  )

  front_door_firewall_policies = var.front_door_waf_enabled ? {
    waf = {
      name                = replace("${var.name_prefix}afdwaf", "-", "")
      resource_group_name = var.resource_group_name
      sku_name            = var.front_door_sku
      mode                = var.front_door_waf_mode
      managed_rules = {
        drs = {
          type    = "Microsoft_DefaultRuleSet"
          version = "2.1"
          action  = "Block"
        }
        bot = {
          type    = "Microsoft_BotManagerRuleSet"
          version = "1.0"
          action  = "Block"
        }
      }
    }
  } : {}

  front_door_security_policies = var.front_door_waf_enabled ? {
    secpol = {
      name = "afd-secpol"
      firewall = {
        front_door_firewall_policy_key = "waf"
        association = {
          endpoint_keys     = local.aca_fd_enabled ? ["ep", "fe"] : ["ep"]
          patterns_to_match = ["/*"]
        }
      }
    }
  } : {}
}
