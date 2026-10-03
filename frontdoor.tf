# Azure Front Door (Premium) via the AVM CDN profile module — global edge + WAF in
# front of APIM through a managed Private Link. Toggle with deploy_front_door.
#
# APIM runs as StandardV2 with a public gateway + outbound VNet integration, so
# Front Door targets the APIM "Gateway" group directly (see apim-privatelink.tf).
# The target defaults to the module's APIM; override via front_door_private_link_
# target_id. The managed private endpoint must be approved on APIM after apply.

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

  front_door_endpoints = {
    ep = {
      name = coalesce(var.front_door_endpoint_name, "${var.name_prefix}-afd-ep")
    }
  }

  front_door_origin_groups = {
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
  }

  front_door_origins = {
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
  }

  front_door_routes = {
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
  }

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
          endpoint_keys     = ["ep"]
          patterns_to_match = ["/*"]
        }
      }
    }
  } : {}

  depends_on = [module.ai_lz]
}
