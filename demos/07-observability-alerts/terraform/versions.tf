terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      # Demo convenience: let `terraform destroy` actually finish.
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }

  subscription_id = var.subscription_id != "" ? var.subscription_id : null
}
