# Integrating with an Azure (platform) Landing Zone

This configuration deploys in **standalone** mode by default
(`flag_platform_landing_zone = false`): it owns its own private DNS zones,
NSGs, and (optionally) firewall/bastion, and routes egress itself.

To integrate with an enterprise **platform landing zone** (hub-and-spoke or
vWAN), you delegate connectivity, DNS, and logging to the platform. Because this
config uses a **bring-your-own VNet**, most of that wiring happens *outside* the
module — the module explicitly assumes it.

## What changes at the module level

### 1. The master flag

```hcl
flag_platform_landing_zone = true   # currently false
```

This single switch changes several behaviors below.

### 2. Firewall, Bastion, and routing become the hub's job

When `flag_platform_landing_zone = true`:

- `AzureFirewallSubnet` and `AzureBastionSubnet` are **no longer created** — the
  hub provides those. The `deploy_firewall` / `deploy_bastion` toggles become
  no-ops.
- The module creates **no route tables** (regardless of `use_internet_routing`).
  Egress is steered by UDRs/firewall in the hub.
- `use_internet_routing` and `firewall_ip_address` stop mattering.

### 3. Private DNS — use the platform's centralized zones

Standalone creates its own `privatelink.*` zones. In an ALZ those live centrally
in the connectivity subscription. Two common patterns:

**a) Azure Policy (DINE/Modify) manages DNS records** (typical enterprise ALZ):

```hcl
private_dns_zones = {
  azure_policy_pe_zone_linking_enabled = true
}
```

Also set `private_endpoints_manage_dns_zone_group = false` on the resource
`*_definition` blocks so the module doesn't fight the policy.

**b) Point at the existing zones directly:**

```hcl
private_dns_zones = {
  existing_zones_resource_group_resource_id =
    "/subscriptions/<connectivity-sub>/resourceGroups/rg-privatedns"
}
```

### 4. Central Log Analytics

Instead of deploying its own workspace, point diagnostics at the platform's LAW:

```hcl
law_definition = {
  resource_id = "/subscriptions/<mgmt-sub>/resourceGroups/rg-monitoring/providers/Microsoft.OperationalInsights/workspaces/central-law"
}
```

## What happens outside the module (platform team)

Because you bring your own VNet, the module does **not** create peering — VNet /
vWAN peering config "is not used for BYO VNet configurations, as that is assumed
to be handled outside the module." The platform team handles:

- **Spoke↔hub peering** (or vWAN hub connection) for your VNet
- **UDRs** forcing egress through the hub firewall
- **Private DNS zone links / DINE policies** for private endpoint resolution
- **Firewall rules** allowing Foundry/APIM/etc. traffic

## Migration checklist (BYO VNet → ALZ)

| Change | Where |
|---|---|
| `flag_platform_landing_zone = true` | `main.tf` |
| Point DNS at central zones (policy or existing RG) | `main.tf` → `private_dns_zones` |
| Set `private_endpoints_manage_dns_zone_group = false` if policy-managed DNS | resource `*_definition` blocks |
| Point at central Log Analytics | `main.tf` → `law_definition.resource_id` |
| Drop reliance on `deploy_firewall` / `deploy_bastion` (hub provides) | toggles |
| Peering + UDRs + DNS links + firewall rules | **platform team, outside this config** |

## Front Door with a hub VNet

Azure Front Door is a **global** service — it is never deployed *into* a VNet.
With APIM in **StandardV2** mode it reaches the public gateway hostname through a
**managed private endpoint** attached to APIM's `Gateway` sub-resource, so no
internal Load Balancer or Private Link Service is involved. Point it at a
platform-owned origin with the override variables:

| Scenario | Configuration |
|---|---|
| Front Door targets the module's APIM (default) | Origin + Private Link target auto-derive from the deployed APIM |
| Platform team owns the Front Door / origin | Set `front_door_private_link_target_id` (+ `front_door_private_link_target_type`, `front_door_private_link_location`) and `front_door_origin_host_name` to their target |

In every case the **Front Door -> origin private endpoint connection must be
approved** on the target side (the platform team approves it when they own the
origin). Pair this with `flag_platform_landing_zone = true` so DNS and routing are
hub-managed.

## Practical note

The switch is not seamless on an *existing* deployment: removing the
firewall/bastion subnets and route tables means Terraform will plan to **destroy**
those resources. The cleanest path is to decide platform-LZ vs standalone before
the first apply, or plan for a controlled re-apply during the cutover.
