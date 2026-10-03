# Front Door origin wiring for APIM StandardV2.
#
# StandardV2 APIM keeps a PUBLIC gateway (`<apim>.azure-api.net`) and integrates
# OUTBOUND into the VNet (APIMSubnet is auto-delegated to Microsoft.Web/serverFarms
# by the pattern module) to reach private backends. Front Door Premium reaches the
# gateway over a managed Private Link to the "Gateway" group, so no Load Balancer
# or Private Link Service is required. The managed private endpoint FD creates must
# be approved on APIM after apply.

locals {
  # Private Link target: explicit override, else the APIM deployed by the module.
  front_door_private_link_target_id   = var.front_door_private_link_target_id != null ? var.front_door_private_link_target_id : (var.deploy_apim ? try(module.ai_lz.apim.resource_id, null) : null)
  front_door_private_link_target_type = var.front_door_private_link_target_type

  # Plan-time-known switch gating the origin's private_link block. The target id
  # itself may only be known after apply (fine for an attribute value, but it must
  # not control the origins map's shape).
  front_door_use_private_link = var.front_door_private_link_target_id != null || var.deploy_apim

  # Front Door origin host defaults to the APIM public gateway hostname.
  front_door_origin_host_name = var.front_door_origin_host_name != null ? var.front_door_origin_host_name : (var.apim_name != null ? "${var.apim_name}.azure-api.net" : null)
}
