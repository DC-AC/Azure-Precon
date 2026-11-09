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
  }
}

provider "azurerm" {
  features {
    resource_group {
      # Application Insights creates a "Failure Anomalies" alert rule in the
      # resource group behind Terraform's back. Without this, destroy fails on a
      # resource group that only this stack uses.
      prevent_deletion_if_contains_resources = false
    }
  }

  subscription_id = var.subscription_id != "" ? var.subscription_id : null
}
