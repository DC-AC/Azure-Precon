###############################################################################
# Demo 07 — Observability & Cost Guardrails
#
# Slide: "Demonstration — Observability & Cost Guardrails"
#        (Section 8, Operations: Observability & Cost)
#   - Diagnostic settings deployed by policy, not by hand
#   - Generate denied requests, find them in KQL, and get the alert on your phone
#   - A budget routed to the same action group
#
#   policy assignment (DeployIfNotExists, this RG only)
#        │  "every Key Vault in here sends audit logs to the workspace"
#        ▼
#   kv-obs-<suffix> ── diagnostic setting (created by policy) ──▶ log-<suffix>
#        │                                                            │
#        │ platform metric: ServiceApiResult, StatusCode=403          │ AzureDiagnostics
#        ▼                                                            ▼
#   metric alert (~1 min, "something is being denied")     log alert (~5-10 min,
#        │                                                  "who, and from where")
#        └──────────────────────┬───────────────────────────────────┘
#                               ▼
#                    action group: email + SMS  ◀── budget: actual & forecast
#
# Nobody in this stack has a data-plane role on the vault — including you. Every
# secret read you make is a 403. That's the signal, and it's a free lesson in
# control plane vs data plane.
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

  # Built-in: "Enable logging by category group for Key vaults
  # (microsoft.keyvault/vaults) to Log Analytics". Microsoft maintains it;
  # you assign it.
  kv_diagnostics_policy_id = "/providers/Microsoft.Authorization/policyDefinitions/6b359d8f-f88d-4052-aa7c-32015963ecc1"


  # Key Vault audit events, 403s only. Key Vault writes to the AzureDiagnostics
  # table here because neither path below asks for resource-specific tables.
  # column_ifexists() keeps the query valid before the first event has landed.
  forbidden_kql = <<-KQL
    AzureDiagnostics
    | where ResourceProvider == "MICROSOFT.KEYVAULT" and Category == "AuditEvent"
    | where toint(column_ifexists("httpStatusCode_d", 0)) == 403 or ResultSignature == "Forbidden"
    | extend Caller = coalesce(
        tostring(column_ifexists("identity_claim_upn_s", "")),
        tostring(column_ifexists("identity_claim_http_schemas_xmlsoap_org_ws_2005_05_identity_claims_upn_s", "")),
        tostring(column_ifexists("identity_claim_oid_g", "")),
        tostring(column_ifexists("identity_claim_http_schemas_microsoft_com_identity_claims_objectidentifier_g", "")),
        "unknown")
  KQL
}

resource "azurerm_resource_group" "this" {
  name     = "rg-demo07-monitor-${local.region_code}"
  location = var.location
  tags     = var.tags
}

###############################################################################
# Log Analytics — one workspace, the destination for everything
###############################################################################

resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# Saved queries, so nobody types KQL live. Workspace → Logs → Queries → "Precon".
resource "azurerm_log_analytics_saved_search" "forbidden_by_caller" {
  name                       = "precon-kv-forbidden-by-caller"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  category                   = "Precon"
  display_name               = "Key Vault — denied requests by caller"
  query                      = "${local.forbidden_kql}| summarize Denied = count() by Caller, CallerIPAddress, OperationName, bin(TimeGenerated, 1m)\n| order by TimeGenerated desc"
}

resource "azurerm_log_analytics_saved_search" "kv_operations" {
  name                       = "precon-kv-operations"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  category                   = "Precon"
  display_name               = "Key Vault — every operation and its result"
  query                      = <<-KQL
    AzureDiagnostics
    | where ResourceProvider == "MICROSOFT.KEYVAULT" and Category == "AuditEvent"
    | summarize Requests = count() by OperationName, ResultSignature
    | order by Requests desc
  KQL
}

resource "azurerm_log_analytics_saved_search" "diagnostic_coverage" {
  name                       = "precon-diagnostic-coverage"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  category                   = "Precon"
  display_name               = "Which resources are actually sending logs"
  query                      = <<-KQL
    AzureDiagnostics
    | summarize LastRecord = max(TimeGenerated), Records = count() by ResourceProvider, Resource, Category
    | order by LastRecord desc
  KQL
}

###############################################################################
# Diagnostics by policy — the default path
#
# Assigned at this resource group only, so the only thing it can ever do is add
# a diagnostic setting to a Key Vault in this resource group. DeployIfNotExists
# needs enforcement on and an identity to deploy with.
###############################################################################

resource "azurerm_resource_group_policy_assignment" "kv_diagnostics" {
  count = var.diagnostics_via_policy ? 1 : 0

  name                 = "precon-kv-diagnostics"
  display_name         = "[Precon] Key Vault audit logs to the demo workspace"
  description          = "DeployIfNotExists, scoped to one demo resource group: every Key Vault created here gets a diagnostic setting at birth."
  resource_group_id    = azurerm_resource_group.this.id
  policy_definition_id = local.kv_diagnostics_policy_id
  location             = var.location

  identity {
    type = "SystemAssigned"
  }

  parameters = jsonencode({
    logAnalytics  = { value = azurerm_log_analytics_workspace.this.id }
    categoryGroup = { value = "audit" }
  })
}

resource "azurerm_role_assignment" "policy_log_analytics" {
  count = var.diagnostics_via_policy ? 1 : 0

  # The role the policy definition itself asks for in roleDefinitionIds —
  # enough to write a diagnostic setting that points at the workspace.
  scope                = azurerm_resource_group.this.id
  role_definition_name = "Log Analytics Contributor"
  principal_id         = azurerm_resource_group_policy_assignment.kv_diagnostics[0].identity[0].principal_id
}

# Entra role assignments are eventually consistent. Give the policy identity a
# minute before the vault exists, so the at-birth deployment has its rights.
resource "time_sleep" "policy_rbac_propagation" {
  count = var.diagnostics_via_policy ? 1 : 0

  create_duration = "60s"
  depends_on      = [azurerm_role_assignment.policy_log_analytics]
}

###############################################################################
# The thing being watched
###############################################################################

resource "azurerm_key_vault" "this" {
  name                = "kv-obs-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # RBAC with no data-plane role assignments at all. Subscription Owner can
  # manage this vault and still can't read a single secret from it.
  rbac_authorization_enabled = true

  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  # Your laptop has to reach it to generate the denied requests.
  public_network_access_enabled = true

  tags = var.tags

  # Created after the assignment (and its rights) exist, so policy wires it up
  # at birth rather than waiting for a remediation task.
  depends_on = [time_sleep.policy_rbac_propagation]
}

# Belt and braces: a brand-new assignment can take a while to become effective,
# so also remediate explicitly. Same diagnostic setting either way.
resource "azurerm_resource_group_policy_remediation" "kv_diagnostics" {
  count = var.diagnostics_via_policy ? 1 : 0

  name                    = "precon-kv-diagnostics"
  resource_group_id       = azurerm_resource_group.this.id
  policy_assignment_id    = azurerm_resource_group_policy_assignment.kv_diagnostics[0].id
  resource_discovery_mode = "ReEvaluateCompliance"

  depends_on = [azurerm_key_vault.this]
}

# Fallback path (diagnostics_via_policy = false): the same setting, by hand.
# Same table, same queries — and every team has to remember to do it.
resource "azurerm_monitor_diagnostic_setting" "kv" {
  count = var.diagnostics_via_policy ? 0 : 1

  name                       = "setByTerraform-LogAnalytics"
  target_resource_id         = azurerm_key_vault.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category_group = "audit"
  }
}

###############################################################################
# Where alerts go
###############################################################################

resource "azurerm_monitor_action_group" "this" {
  name                = "ag-precon-${local.suffix}"
  resource_group_name = azurerm_resource_group.this.name
  short_name          = "precon"
  tags                = var.tags

  dynamic "email_receiver" {
    for_each = var.alert_email != "" ? [var.alert_email] : []
    content {
      name                    = "presenter-email"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }

  dynamic "sms_receiver" {
    for_each = var.alert_sms_number != "" ? [var.alert_sms_number] : []
    content {
      name         = "presenter-sms"
      country_code = var.alert_sms_country_code
      phone_number = sms_receiver.value
    }
  }
}

###############################################################################
# Alerts — one fast, one rich
###############################################################################

# Fast: platform metrics need no diagnostic setting and land in about a minute.
resource "azurerm_monitor_metric_alert" "kv_forbidden" {
  name                = "alert-kv-forbidden-${local.suffix}"
  resource_group_name = azurerm_resource_group.this.name
  scopes              = [azurerm_key_vault.this.id]
  description         = "Key Vault is denying requests (HTTP 403). Authenticated, but not authorized."
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"
  auto_mitigate       = true
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.KeyVault/vaults"
    metric_name      = "ServiceApiResult"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = var.forbidden_request_threshold

    # 403 only. Every Key Vault client's first request is an unauthenticated
    # 401 challenge by design — alert on 4xx and you page someone per login.
    dimension {
      name     = "StatusCode"
      operator = "Include"
      values   = ["403"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }
}

# Rich: the resource log says who and from where, one alert per caller. Slower,
# because the log has to be exported, ingested and then queried.
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "kv_forbidden_by_caller" {
  name                = "alert-kv-forbidden-callers-${local.suffix}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  display_name        = "[Precon] Key Vault denied requests — who and from where"
  description         = "One alert per caller and source IP with more than ${var.forbidden_request_threshold} denied Key Vault requests."
  scopes              = [azurerm_log_analytics_workspace.this.id]
  severity            = 2

  evaluation_frequency = "PT5M"
  window_duration      = "PT15M"

  # AzureDiagnostics doesn't exist in a new workspace until the first record
  # arrives, so the query can't be validated at create time.
  skip_query_validation = true

  criteria {
    query                   = "${local.forbidden_kql}| summarize Denied = count() by Caller, CallerIPAddress"
    time_aggregation_method = "Total"
    metric_measure_column   = "Denied"
    operator                = "GreaterThan"
    threshold               = var.forbidden_request_threshold

    dimension {
      name     = "Caller"
      operator = "Include"
      values   = ["*"]
    }

    dimension {
      name     = "CallerIPAddress"
      operator = "Include"
      values   = ["*"]
    }

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.this.id]
  }

  tags = var.tags
}

###############################################################################
# Cost — a budget is an alert too
###############################################################################

# Budgets must start on the first of a month. time_static pins "now" at create
# time so the start date doesn't drift on every plan.
resource "time_static" "budget_start" {}

resource "azurerm_consumption_budget_resource_group" "this" {
  count = var.create_budget ? 1 : 0

  name              = "budget-${local.suffix}"
  resource_group_id = azurerm_resource_group.this.id
  amount            = var.monthly_budget_amount
  time_grain        = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00'Z'", time_static.budget_start.rfc3339)
  }

  # Same action group as the ops alerts. Cost is an operational signal.
  notification {
    enabled        = true
    threshold      = 50
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_groups = [azurerm_monitor_action_group.this.id]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    contact_groups = [azurerm_monitor_action_group.this.id]
  }
}
