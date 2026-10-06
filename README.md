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
| `outputs.tf` | VNet, subnets, APIM, Log Analytics, Front Door, SQL, Function App outputs |
| `aca.tf` | Optional frontend + backend Container Apps on the pattern module's ACA environment |
| `sql.tf` | Optional Azure SQL logical server + database with a private endpoint (AVM) |
| `functionapp.tf` | Optional Linux Function App with private, passwordless storage (AVM) |
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

The module runs APIM in **StandardV2** mode: the gateway keeps a public hostname
(`<apim_name>.azure-api.net`) and integrates outbound into the VNet to reach
private backends. Front Door Premium reaches the gateway over a **managed Private
Link to the `Gateway` sub-resource**, so no internal Load Balancer or Private Link
Service is required. `apim-privatelink.tf` wires this automatically: the origin
hostname and Private Link target default to the module's APIM, or set
`front_door_origin_host_name` / `front_door_private_link_target_id` to override.

Approve the Front Door managed private endpoint on APIM after apply. See
`ALZ-INTEGRATION.md` for a platform-owned / hub-managed origin.

### Function App (optional)

`functionapp.tf` adds a **Linux Function App that reaches its storage account
entirely over private endpoints**, built from Azure Verified Modules
(`avm-res-web-serverfarm` + `avm-res-storage-storageaccount` + `avm-res-web-site`).
Enable with `deploy_function_app = true`.

How it's wired:

- A dedicated **Premium v3 (P1v3)** plan — dedicated, so no content share is needed.
- A dedicated storage account with **public access off** and blob/queue/table
  **private endpoints**; the host authenticates with its **system-assigned managed
  identity** (`storage_uses_managed_identity`, no keys), granted Storage Blob Data
  Owner + Queue/Table Data Contributor.
- A delegated `FunctionAppSubnet` (`Microsoft.Web/serverFarms`) for regional VNet
  integration, with all egress routed through the VNet.
- The storage `privatelink.{blob,queue,table}.core.windows.net` zones are **reused**
  from the landing zone by default (set `function_app_create_dns_zones = true` to
  create + VNet-link them here instead).

Key knobs (all in `terraform.tfvars`, all optional): `function_app_name`,
`function_app_storage_name`, `function_app_subnet_address_prefix` (default
`10.50.9.0/24`), `function_app_service_plan_sku` (default `P1v3`),
`function_app_service_plan_name`, `function_app_worker_count`,
`function_app_zone_balancing_enabled`, `function_app_node_version`,
`function_app_pe_subnet_resource_id`, `function_app_create_dns_zones`,
`function_app_dns_zone_resource_group_name`.

> Keep the plan on a dedicated SKU (`P1v3/P2v3/P3v3`). Elastic Premium
> (`EP*`)/Consumption require a key-based content-share connection string, which
> conflicts with the passwordless, shared-key-disabled storage used here.
>
> The reused DNS zones must be linked to the Function App's VNet so the storage
> private endpoints resolve (the landing zone normally links them for its own
> private endpoints).

### Azure SQL (optional)

`sql.tf` adds an **Azure SQL logical server + database with a private endpoint**
(AVM `avm-res-sql-server`). Enable with `deploy_sql_database = true`. Tune via
`sql_server_name`, `sql_database_name`, `sql_database_sku`, `sql_server_version`,
`sql_administrator_login` (password is generated — read
`terraform output -raw sql_administrator_login_password`), and
`sql_pe_subnet_resource_id` (defaults to the BYO VNet's `PrivateEndpointSubnet`).

### Container Apps (optional)

`aca.tf` adds **frontend + backend Container Apps** on the pattern module's ACA
environment (enabled via `deploy_container_app_environment`). Both use a
system-assigned identity; the backend reaches SQL and AI Search privately. Tune
via the `aca_*` variables (app names, ports, CPU/memory, placeholder image).

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
