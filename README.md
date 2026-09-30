# AI/ML Landing Zone — phased Terraform deployment

A thin root configuration that calls the Azure Verified Module
[`Azure/avm-ptn-aiml-landing-zone`](https://registry.terraform.io/modules/Azure/avm-ptn-aiml-landing-zone/azurerm/latest)
to stand up an Azure AI Foundry landing zone into an **existing (bring-your-own) VNet**.

Components are enabled **one phase at a time** by flipping `true`/`false` switches
in `terraform.tfvars`, so you can build the environment incrementally and keep the
blast radius small.

> This deploys the current resource-based Azure AI Foundry (Foundry account +
> projects on `Microsoft.CognitiveServices`), **not** the deprecated AML-workspace hub.

## Files

| File | Purpose |
|---|---|
| `providers.tf` | Terraform + provider versions, `azurerm` feature flags, commented remote backend |
| `variables.tf` | Input variable declarations (including the phase toggles) |
| `main.tf` | The module call: BYO VNet wiring, subnet overrides, toggle-driven components |
| `terraform.tfvars` | Your values + the phased rollout switches |
| `outputs.tf` | VNet, subnets, APIM, Log Analytics, Front Door outputs |
| `frontdoor.tf` | Optional Azure Front Door Premium + WAF via the CDN AVM (Pattern A) |
| `apim-privatelink.tf` | Optional internal LB (AVM) + Private Link Service fronting internal APIM |
| `ALZ-INTEGRATION.md` | How to move from standalone to a platform (Azure) landing zone |

## Prerequisites

- Terraform `>= 1.9, < 2.0`
- Azure CLI, logged in: `az login`
- An **existing VNet** with free, non-overlapping address space for the subnets
  (see "Address space" below)
- Permissions on the target subscription: Owner, or Contributor + User Access
  Administrator (the module creates RBAC role assignments and adds subnets to your VNet)

## Configure

Edit `terraform.tfvars`:

| Setting | What to put |
|---|---|
| `location` | Azure region, e.g. `eastus2` |
| `resource_group_name` | RG to create — must **not** already exist |
| `name_prefix` | < 10 lowercase alphanumeric chars |
| `existing_vnet_resource_id` | Full resource ID of your existing VNet |
| `firewall_ip_address` | Hub firewall IP, or set to `null` if you route egress directly |
| `tags` | Any tags to apply to all resources |

Subnet CIDRs are set in `main.tf` under `vnet_definition.subnets`. Replace the
example `10.50.x.x` ranges with ranges that are free inside your VNet. Keep the
subnet **names** as-is (`AzureFirewallSubnet` / `AzureBastionSubnet` are required
literal names). Set a subnet to `{ enabled = false }` to skip it.

### Address space

Subnet sizes scale with the VNet prefix. A `/20` is recommended for a full
deployment; `/23` is the practical minimum. See the table in `main.tf` for the
example `/20` layout.

## Phased rollout

Start with everything `false` (Phase 1), `apply`, then flip ONE group to `true`
and re-apply. Terraform only adds the newly enabled resources.

| Phase | Toggle(s) in `terraform.tfvars` | Adds |
|---|---|---|
| 1 – Baseline | *(none; `deploy_log_analytics` already true)* | Subnets, NSGs, private DNS, Log Analytics, Foundry account + project |
| 2 – Models | `model_deployments` (map) | one model deployment per map entry |
| 3 – GenAI data | `deploy_genai_*`, `deploy_container_app_environment` | Key Vault, Storage, Cosmos, App Config, ACR, Container Apps env |
| 4 – Knowledge | `deploy_ai_search`, `deploy_bing_grounding` | AI Search, Bing Grounding |
| 5 – Agent | `deploy_ai_agent_service` | Foundry Agent service + its BYOR data services + project connections |
| 6 – Gateway | `deploy_apim` | API Management (slow, ~30–45 min) |
| 7 – Ops | `deploy_bastion`, `deploy_jumpvm`, `deploy_buildvm`, `deploy_firewall` | Bastion, Jump VM, Build VM, Firewall |

The Foundry account always deploys (Phase 1). At least one project is recommended
but you can set `ai_projects = {}` for an account-only deployment. Firewall stays
off by default because for a BYO VNet the firewall is normally external.

## Customization

Beyond the on/off toggles, these resources are tunable from `terraform.tfvars`.
All have sensible defaults, so you only set what you want to change.

### Models (Phase 2)

`model_deployments` is a **map** — one entry per model. The map key is the
deployment name. Empty map (`{}`) = no models.

```hcl
model_deployments = {
  "gpt-5.5" = {
    model_name    = "gpt-5.5"
    model_version = "2026-04-24"
    sku_type      = "GlobalStandard"   # must be a SKU the model offers in var.location
    capacity      = 10
  }
}
```

`format` (`OpenAI`), `sku_type` (`GlobalStandard`), and `capacity` (`10`) are
optional per entry. Verify SKU availability with
`az cognitiveservices model list --location <region>`.

### Foundry projects (Phase 1)

`ai_projects` is a map — add an entry per project (key is an arbitrary id):

```hcl
ai_projects = {
  proj1 = { name = "team-alpha", display_name = "Team Alpha", description = "..." }
}
```

### AI Search (Phase 4)

Auto-generates a globally-unique name. Override via `search_service_name`,
`search_sku`, `search_replica_count`, `search_partition_count`.

### GenAI services (Phase 3)

| Service | Variables |
|---|---|
| ACR | `acr_name`, `acr_sku`, `acr_zone_redundancy_enabled`, `acr_public_network_access_enabled` |
| Container Apps env | `aca_name`, `aca_zone_redundancy_enabled`, `aca_internal_load_balancer_enabled` |
| Storage | `storage_name`, `storage_account_tier`, `storage_account_replication_type`, `storage_access_tier`, `storage_shared_access_key_enabled`, `storage_public_network_access_enabled` |

Key Vault, Cosmos DB, and App Configuration currently expose only their `deploy`
toggle; add fields to their `*_definition` block in `main.tf` (or ask to have them
parameterized) to customize further.

### App Gateway

Kept off with empty required maps (its variable defaults to `null`, which breaks
the WAF-policy submodule). Enabling it needs a full listener/backend/routing
configuration — not a simple toggle.

### APIM (Phase 6)

Tune via `apim_name`, `apim_sku_root` (default `Premium`), `apim_sku_capacity`
(default `1`), `apim_virtual_network_type` (default `Internal`).

### Front Door (Phase 6b, optional)

`frontdoor.tf` adds **Azure Front Door Premium + WAF** in front of APIM via
Private Link (global edge, WAF, caching). Enable with `deploy_front_door = true`
(requires `deploy_apim = true`).

Because the module runs APIM in **Internal VNet mode**, Front Door Private Link
cannot target it directly. Set `deploy_apim_private_link_service = true` to have
`apim-privatelink.tf` build an internal Load Balancer (via the AVM
`avm-res-network-loadbalancer`) plus a Private Link Service in front of APIM;
Front Door then Private-Links to that PLS automatically. The LB/PLS subnet + VNet
and the origin hostname are **derived automatically** (BYO VNet's
`PrivateEndpointSubnet` and `<apim_name>.azure-api.net`), so you normally only
supply `apim_private_ip_address`. Override `apim_lb_subnet_resource_id` /
`apim_lb_vnet_resource_id` to place the LB/PLS elsewhere (e.g. a hub VNet), or set
`front_door_private_link_target_id` yourself to use a platform-owned PLS.

**Two-step apply** (APIM's private IP only exists after APIM is created):

1. Apply Phase 6 with `deploy_front_door` and `deploy_apim_private_link_service`
   set to `false`, then read `terraform output apim_private_ip`.
2. Set `apim_private_ip_address` to that value, flip both switches `true`, apply
   again.

Approve the Front Door private endpoint connection on the PLS after apply. See
`ALZ-INTEGRATION.md` for putting the PLS/LB in a hub VNet.

## Run

```powershell
cd ai-foundry-lz
az login
az account set --subscription "<your-subscription-id>"

terraform init
terraform plan
terraform apply
```

Then flip the next phase's toggle in `terraform.tfvars` and run `terraform apply`
again. Repeat.

## Remote state (optional but recommended)

Local state (`terraform.tfstate` in this folder) is fine for a solo test. For
team use, CI/CD, or durability, use an Azure Storage backend.

Create the state storage once:

```powershell
$rg  = "rg-tfstate"
$sa  = "sttfstate$(Get-Random -Maximum 99999)"   # must be globally unique, lowercase
$loc = "eastus2"

az group create --name $rg --location $loc
az storage account create --name $sa --resource-group $rg --location $loc --sku Standard_LRS --encryption-services blob
az storage container create --name tfstate --account-name $sa --auth-mode login
Write-Host "Storage account: $sa"
```

Then uncomment and fill the `backend "azurerm"` block in `providers.tf` with the
`resource_group_name`, `storage_account_name`, `container_name = "tfstate"`, and a
`key`, and run `terraform init` (it will offer to migrate local state).

## Tear down

```powershell
terraform destroy
```

The `azurerm` provider `features` block in `providers.tf` sets
`cognitive_account.purge_soft_delete_on_destroy = true` so the Foundry account is
purged on destroy (helps re-deploys in the same tenant).

## Azure landing zone integration

This config runs **standalone** by default. To integrate with an enterprise
platform (hub-and-spoke or vWAN) landing zone — centralized DNS, hub firewall,
shared Log Analytics — see [ALZ-INTEGRATION.md](ALZ-INTEGRATION.md).
