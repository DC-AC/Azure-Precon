###############################################################################
# Demo 06 — Azure SQL, Locked Down
#
# Slide: "Demonstration — Azure SQL, Locked Down" (Section 2, Azure SQL, Fabric & Data Platform)
#   - Entra-only authentication: no SQL password exists anywhere
#   - Turn off public access live; the app keeps working through its private endpoint
#   - Point-in-time restore, timed — that's your RTO, measured
#
# Topology:
#
#     your laptop ──── public endpoint ────┐   (only while public_network_access_enabled
#                      (firewall: one IP)  │    = true — flipping it is the demo)
#                                          ▼
#   ┌──────── vnet-sql  10.60.0.0/16 ────────────┐      ┌────────────────────────┐
#   │                                            │      │ sql-<suffix>           │
#   │  snet-func (delegated)    snet-pe          │      │   Entra-only auth      │
#   │    func-sql ──────────▶  pe-sql ───────────┼─────▶│   sqldb-adventureworks │
#   │    (managed identity)    (private IP)      │ Link │   serverless, PITR     │
#   └────────────────────────────────────────────┘      └────────────────────────┘
#         privatelink.database.windows.net  (private DNS zone, linked)
#
# There is no administrator_login_password in this file. Not a variable, not a
# random_password, not a Key Vault secret. The server accepts no SQL logins at all.
###############################################################################

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
}

locals {
  suffix = "${var.prefix}-${random_string.suffix.result}"

  # Defaults to whoever runs terraform apply. In production this is an Entra
  # *group*, so admin rights follow group membership (and PIM), not a person.
  entra_admin_object_id = var.entra_admin_object_id != "" ? var.entra_admin_object_id : data.azurerm_client_config.current.object_id

  # A server with public access disabled can't hold firewall rules, so the
  # laptop rule follows the switch.
  create_client_firewall_rule = var.public_network_access_enabled && var.client_ip_address != ""

  # A connection string with no secret in it. Read it out on stage: a server,
  # a database, and "use my managed identity". Entra ID does the rest.
  sql_connection_string = "Server=tcp:${azurerm_mssql_server.this.fully_qualified_domain_name},1433;Database=${azurerm_mssql_database.this.name};Authentication=Active Directory Managed Identity;Encrypt=True;"
}

resource "azurerm_resource_group" "this" {
  name     = "rg-sql-${local.suffix}"
  location = var.location
  tags     = var.tags
}

###############################################################################
# Network
###############################################################################

resource "azurerm_virtual_network" "this" {
  name                = "vnet-sql-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.vnet_address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "func" {
  name                 = "snet-func"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [cidrsubnet(var.vnet_address_space, 8, 1)] # 10.60.1.0/24

  # Flex Consumption VNet integration runs on Container Apps infrastructure.
  delegation {
    name = "flex-consumption"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }

  # New VNets are private by default since March 2026. The function still
  # reaches its storage account and Application Insights over public endpoints,
  # so egress stays on here — explicitly, where a reviewer can see it. The
  # production answer is a NAT gateway, or private endpoints for those too.
  default_outbound_access_enabled = true
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-pe"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [cidrsubnet(var.vnet_address_space, 8, 2)] # 10.60.2.0/24

  # Nothing in this subnet needs the internet. This is the new platform default.
  default_outbound_access_enabled = false
}

# Without this zone the function would resolve the server's public address and
# never touch the private endpoint. DNS is half of Private Link.
resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
  name                  = "link-vnet-sql"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.this.id
  registration_enabled  = false
  tags                  = var.tags
}

###############################################################################
# Azure SQL — Entra-only, serverless
###############################################################################

resource "azurerm_mssql_server" "this" {
  name                = "sql-${local.suffix}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  version             = "12.0"
  minimum_tls_version = "1.2"

  # The live switch. true for pre-flight and the first beat; false on stage.
  public_network_access_enabled = var.public_network_access_enabled

  azuread_administrator {
    login_username = var.entra_admin_login_name
    object_id      = local.entra_admin_object_id
    tenant_id      = data.azurerm_client_config.current.tenant_id

    # SQL authentication is off at the server. There's no administrator_login
    # above because there would be nothing for it to log in to.
    azuread_authentication_only = true
  }

  tags = var.tags
}

resource "azurerm_mssql_firewall_rule" "client" {
  count = local.create_client_firewall_rule ? 1 : 0

  name             = "presenter-laptop"
  server_id        = azurerm_mssql_server.this.id
  start_ip_address = var.client_ip_address
  end_ip_address   = var.client_ip_address
}

resource "azurerm_mssql_database" "this" {
  name      = "sqldb-adventureworks"
  server_id = azurerm_mssql_server.this.id

  # Serverless General Purpose: per-second billing while active, and it pauses
  # itself after an hour idle — the serverless-vs-provisioned slide, running.
  sku_name                    = "GP_S_Gen5_1"
  min_capacity                = 0.5
  auto_pause_delay_in_minutes = var.auto_pause_delay_in_minutes
  max_size_gb                 = 32
  zone_redundant              = false

  # Something real to query.
  sample_name = "AdventureWorksLT"

  # Backup storage redundancy. Local is cheapest and fine for a demo — and it
  # means geo-restore is off the table. That's the last bullet on the BCDR
  # slide, so say it out loud.
  storage_account_type = var.backup_storage_redundancy

  short_term_retention_policy {
    retention_days = 7
  }

  tags = var.tags
}

resource "azurerm_private_endpoint" "sql" {
  name                = "pe-sql-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-sql"
    private_connection_resource_id = azurerm_mssql_server.this.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql.id]
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.sql]
}

###############################################################################
# The consumer — a Flex Consumption function inside the VNet
#
# Same identity pattern as demo 04: a user-assigned identity reads the
# deployment package, the system-assigned identity does everything else —
# including signing in to SQL.
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

resource "azurerm_storage_account" "func" {
  name                     = replace("stsql${var.prefix}${random_string.suffix.result}", "-", "")
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  min_tls_version          = "TLS1_2"

  allow_nested_items_to_be_public = false

  tags = var.tags
}

resource "azurerm_storage_container" "deployments" {
  name                  = "app-package"
  storage_account_id    = azurerm_storage_account.func.id
  container_access_type = "private"
}

resource "azurerm_user_assigned_identity" "deploy" {
  name                = "id-funcdeploy-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_role_assignment" "deploy_blob_owner" {
  scope                = azurerm_storage_account.func.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_user_assigned_identity.deploy.principal_id
}

resource "azurerm_service_plan" "this" {
  name                = "asp-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  os_type             = "Linux"
  sku_name            = "FC1" # Flex Consumption
  tags                = var.tags
}

resource "azurerm_function_app_flex_consumption" "this" {
  name                = "func-sql-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  service_plan_id     = azurerm_service_plan.this.id

  storage_container_type            = "blobContainer"
  storage_container_endpoint        = "${azurerm_storage_account.func.primary_blob_endpoint}${azurerm_storage_container.deployments.name}"
  storage_authentication_type       = "UserAssignedIdentity"
  storage_user_assigned_identity_id = azurerm_user_assigned_identity.deploy.id

  runtime_name    = "python"
  runtime_version = var.runtime_version

  instance_memory_in_mb  = 2048
  maximum_instance_count = 10

  # All outbound traffic leaves through the VNet, so the SQL hostname resolves
  # through the private DNS zone to the private endpoint.
  virtual_network_subnet_id = azurerm_subnet.func.id

  https_only = true

  identity {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.deploy.id]
  }

  site_config {
    application_insights_connection_string = azurerm_application_insights.this.connection_string
  }

  app_settings = {
    "AzureWebJobsStorage__accountName" = azurerm_storage_account.func.name

    "SqlConnectionString" = local.sql_connection_string
  }

  tags = var.tags

  depends_on = [azurerm_role_assignment.deploy_blob_owner]
}

resource "azurerm_role_assignment" "func_blob" {
  scope                = azurerm_storage_account.func.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_function_app_flex_consumption.this.identity[0].principal_id
}

resource "azurerm_role_assignment" "func_queue" {
  scope                = azurerm_storage_account.func.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_function_app_flex_consumption.this.identity[0].principal_id
}

resource "azurerm_role_assignment" "func_table" {
  scope                = azurerm_storage_account.func.id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azurerm_function_app_flex_consumption.this.identity[0].principal_id
}

# Note what is NOT here: no role assignment on the SQL server. Entra ID proves
# who the function is; what it may do inside the database is a database
# permission, granted in T-SQL — see ../sql/grant-function-access.sql.
