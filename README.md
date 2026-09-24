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
| `outputs.tf` | VNet, subnets, APIM, Log Analytics outputs |

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
| 2 – Model | `deploy_model` | model deployment (see `model_*` vars) |
| 3 – GenAI data | `deploy_genai_*`, `deploy_container_app_environment` | Key Vault, Storage, Cosmos, App Config, ACR, Container Apps env |
| 4 – Knowledge | `deploy_ai_search`, `deploy_bing_grounding` | AI Search, Bing Grounding |
| 5 – Agent | `deploy_ai_agent_service` | Foundry Agent service + its BYOR data services + project connections |
| 6 – Gateway | `deploy_apim` | API Management (slow, ~30–45 min) |
| 7 – Ops | `deploy_bastion`, `deploy_jumpvm`, `deploy_buildvm`, `deploy_firewall` | Bastion, Jump VM, Build VM, Firewall |

The Foundry account + one project always deploy (Phase 1) — there is no switch to
omit them. Firewall stays off by default because for a BYO VNet the firewall is
normally external.

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
