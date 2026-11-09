###############################################################################
# Demo 05 — Create a Function App
#
# Slide: "Demonstration — Create a Function App" (Section 7, Automation & Serverless)
#   - Create and verify a function app
#
# Built on the Flex Consumption plan (FC1) — the current recommendation, and the
# hosting option named on the "Azure Functions — Event-Driven Compute" slide.
#
# Every credential in this stack is a role assignment, not a secret:
#
#   user-assigned identity ──> Storage Blob Data Owner ──> deployment container
#          (created first, so the platform can read the package at create time)
#
#   system-assigned identity ──> Blob/Queue/Table Data Contributor
#          (what the function runtime uses for AzureWebJobsStorage)
#
# There is no storage connection string anywhere in this file. That is the point.
###############################################################################

resource "random_string" "suffix" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
}

locals {
  # Resource group names follow rg-<demo>-<core tech>-<region>. Only globally
  # unique names (storage, Key Vault, SQL, function apps) carry the random suffix.
  region_codes = {
    eastus         = "eus"
    eastus2        = "eus2"
    centralus      = "cus"
    northcentralus = "ncus"
    southcentralus = "scus"
    westus         = "wus"
    westus2        = "wus2"
    westus3        = "wus3"
    canadacentral  = "cac"
    northeurope    = "neu"
    westeurope     = "weu"
    uksouth        = "uks"
  }
  region_code = lookup(local.region_codes, var.location, var.location)

  suffix = "${var.prefix}-${random_string.suffix.result}"
}

resource "azurerm_resource_group" "this" {
  name     = "rg-demo05-functions-${local.region_code}"
  location = var.location
  tags     = var.tags
}

###############################################################################
# Observability — workspace-based Application Insights
###############################################################################

resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_application_insights" "this" {
  name                = "appi-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  workspace_id        = azurerm_log_analytics_workspace.this.id
  application_type    = "web"
  tags                = var.tags
}

###############################################################################
# Storage — deployment package container and runtime state
###############################################################################

resource "azurerm_storage_account" "this" {
  name                     = replace("stfn${var.prefix}${random_string.suffix.result}", "-", "")
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  min_tls_version          = "TLS1_2"

  allow_nested_items_to_be_public = false

  # "Disable shared-key access where possible" — see the storage security slide.
  shared_access_key_enabled = !var.disable_storage_shared_key

  tags = var.tags
}

resource "azurerm_storage_container" "deployments" {
  name                  = "app-package"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

###############################################################################
# Identity
#
# Two identities on purpose — this is the system-assigned vs user-assigned slide
# turned into a real design decision:
#
#   user-assigned  : granted BEFORE the app exists, so the platform can read the
#                    deployment container on the very first create. A
#                    system-assigned identity does not exist yet at that point.
#   system-assigned: the app's own identity for its outbound calls. Dies with
#                    the app, which is what you want for app-scoped access.
###############################################################################

resource "azurerm_user_assigned_identity" "deploy" {
  name                = "id-funcdeploy-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_role_assignment" "deploy_blob_owner" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_user_assigned_identity.deploy.principal_id
}

###############################################################################
# Function App — Flex Consumption
###############################################################################

resource "azurerm_service_plan" "this" {
  name                = "asp-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  os_type             = "Linux"
  sku_name            = "FC1" # Flex Consumption
  tags                = var.tags
}

resource "azurerm_function_app_flex_consumption" "this" {
  name                = "func-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  service_plan_id     = azurerm_service_plan.this.id

  # Deployment package storage — reached with a managed identity, not a key.
  storage_container_type            = "blobContainer"
  storage_container_endpoint        = "${azurerm_storage_account.this.primary_blob_endpoint}${azurerm_storage_container.deployments.name}"
  storage_authentication_type       = "UserAssignedIdentity"
  storage_user_assigned_identity_id = azurerm_user_assigned_identity.deploy.id

  runtime_name    = var.runtime_name
  runtime_version = var.runtime_version

  # Performance Efficiency, as two explicit numbers rather than a default nobody read.
  instance_memory_in_mb  = var.instance_memory_in_mb
  maximum_instance_count = var.maximum_instance_count

  https_only = true

  identity {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.deploy.id]
  }

  site_config {
    application_insights_connection_string = azurerm_application_insights.this.connection_string
  }

  app_settings = {
    # Identity-based AzureWebJobsStorage: the account name, not a connection
    # string. The runtime resolves it with the system-assigned identity.
    "AzureWebJobsStorage__accountName" = azurerm_storage_account.this.name

    # Workaround for azurerm 4.81 (hashicorp/terraform-provider-azurerm#33211):
    # the provider injects an AzureWebJobsStorage connection string with an
    # empty key, and the host reads that before __accountName. An explicit
    # empty value wins. Side effect: every plan shows this line as a change
    # until the provider fix ships.
    "AzureWebJobsStorage" = ""
  }

  dynamic "always_ready" {
    for_each = var.always_ready_instance_count > 0 ? [1] : []
    content {
      name           = "http"
      instance_count = var.always_ready_instance_count
    }
  }

  tags = var.tags

  depends_on = [azurerm_role_assignment.deploy_blob_owner]
}

###############################################################################
# The runtime's own access to storage (host locks, timers, queue triggers)
###############################################################################

resource "azurerm_role_assignment" "func_blob" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_function_app_flex_consumption.this.identity[0].principal_id
}

resource "azurerm_role_assignment" "func_queue" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_function_app_flex_consumption.this.identity[0].principal_id
}

resource "azurerm_role_assignment" "func_table" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azurerm_function_app_flex_consumption.this.identity[0].principal_id
}
