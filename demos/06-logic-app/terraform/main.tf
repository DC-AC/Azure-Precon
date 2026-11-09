###############################################################################
# Demo 06 — Logic App Workflow
#
# Slide: "Demonstration — Logic App Workflow" (Section 7, Automation & Serverless)
#   - Create a logic app, add a trigger, run it
#
# Workflow shape:
#
#   [ HTTP request trigger ]        POST an order payload
#              │
#   [ Build_order_record ]          Compose - normalise + stamp the run id
#              │
#   [ Route_by_amount ]             If amount > approval_threshold
#         ├── true  ──> Respond 202 "escalated"
#         └── false ──> Respond 200 "auto-approved"
#
# Deliberately connector-free so it runs end-to-end from `curl` with nothing to
# authorise. The "hundreds of connectors" beat is done live in the designer,
# against the storage queue this stack pre-authorises for the managed identity.
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
  name     = "rg-demo06-logicapp-${local.region_code}"
  location = var.location
  tags     = var.tags
}

###############################################################################
# The workflow
###############################################################################

resource "azurerm_logic_app_workflow" "orders" {
  name                = "logic-orders-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  # So connectors added later in the designer can authenticate as this workflow
  # rather than with a stored key.
  identity {
    type = "SystemAssigned"
  }
}

###############################################################################
# Trigger
###############################################################################

resource "azurerm_logic_app_trigger_http_request" "order_received" {
  name         = "Order_received"
  logic_app_id = azurerm_logic_app_workflow.orders.id
  method       = "POST"

  # The schema is what gives the designer typed tokens for @triggerBody().
  # Without it every downstream reference is a hand-typed string.
  schema = jsonencode({
    type = "object"
    properties = {
      orderId  = { type = "string" }
      customer = { type = "string" }
      amount   = { type = "number" }
    }
    required = ["orderId", "amount"]
  })
}

###############################################################################
# Actions
#
# These all mutate the same workflow definition, so they are chained with
# depends_on. Without it Terraform updates the workflow in parallel and the
# writes clobber each other.
###############################################################################

resource "azurerm_logic_app_action_custom" "build_order_record" {
  name         = "Build_order_record"
  logic_app_id = azurerm_logic_app_workflow.orders.id

  body = jsonencode({
    type = "Compose"
    inputs = {
      orderId     = "@triggerBody()?['orderId']"
      customer    = "@triggerBody()?['customer']"
      amount      = "@triggerBody()?['amount']"
      receivedUtc = "@{utcNow()}"
      workflowRun = "@{workflow().run.name}"
    }
    runAfter = {}
  })

  depends_on = [azurerm_logic_app_trigger_http_request.order_received]
}

resource "azurerm_logic_app_action_custom" "route_by_amount" {
  name         = "Route_by_amount"
  logic_app_id = azurerm_logic_app_workflow.orders.id

  body = jsonencode({
    type = "If"

    # The business rule. One line, in version control, reviewable in a PR.
    expression = {
      greater = ["@triggerBody()?['amount']", var.approval_threshold]
    }

    actions = {
      Respond_escalated = {
        type = "Response"
        kind = "Http"
        inputs = {
          statusCode = 202
          headers    = { "Content-Type" = "application/json" }
          body = {
            status = "escalated"
            reason = "Amount exceeds the auto-approve threshold of ${var.approval_threshold}"
            order  = "@outputs('Build_order_record')"
          }
        }
        runAfter = {}
      }
    }

    else = {
      actions = {
        Respond_approved = {
          type = "Response"
          kind = "Http"
          inputs = {
            statusCode = 200
            headers    = { "Content-Type" = "application/json" }
            body = {
              status = "auto-approved"
              order  = "@outputs('Build_order_record')"
            }
          }
          runAfter = {}
        }
      }
    }

    runAfter = {
      Build_order_record = ["Succeeded"]
    }
  })

  depends_on = [azurerm_logic_app_action_custom.build_order_record]
}

###############################################################################
# Optional connector target — a queue the workflow identity may already write to
###############################################################################

resource "azurerm_storage_account" "this" {
  count = var.enable_queue_target ? 1 : 0

  name                     = replace("stla${var.prefix}${random_string.suffix.result}", "-", "")
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  min_tls_version          = "TLS1_2"

  allow_nested_items_to_be_public = false

  tags = var.tags
}

resource "azurerm_storage_queue" "escalations" {
  count = var.enable_queue_target ? 1 : 0

  name               = "escalations"
  storage_account_id = azurerm_storage_account.this[0].id
}

# Pre-authorising the identity means the connector you add live in the designer
# can pick "Managed identity" and just work — no key, no connection string.
resource "azurerm_role_assignment" "logic_app_queue_sender" {
  count = var.enable_queue_target ? 1 : 0

  scope                = azurerm_storage_account.this[0].id
  role_definition_name = "Storage Queue Data Message Sender"
  principal_id         = azurerm_logic_app_workflow.orders.identity[0].principal_id
}
