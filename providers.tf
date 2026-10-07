terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.81.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
    modtm = {
      source  = "azure/modtm"
      version = "~> 0.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }

  # Recommended: use a remote backend for state. Fill in and uncomment.
  # backend "azurerm" {
  #   resource_group_name  = "rg-tfstate"
  #   storage_account_name = "sttfstatefake001"
  #   container_name       = "tfstate"
  #   key                  = "ai-foundry-lz.tfstate"
  # }
}

# Feature flags mirror the module's examples so deployments succeed in
# policy-restricted tenants (soft-delete purge, AAD storage auth, etc.).
provider "azurerm" {
  storage_use_azuread = true

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine {
      delete_os_disk_on_deletion = true
    }
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
    # APIM is soft-deleted on destroy and its name reserved ~48h. Purge on
    # destroy + recover on create so a VNet-type replace can reuse the name.
    api_management {
      purge_soft_delete_on_destroy = true
      recover_soft_deleted         = true
    }
  }
}
