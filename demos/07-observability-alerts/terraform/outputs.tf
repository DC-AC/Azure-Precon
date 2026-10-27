output "resource_group_name" {
  description = "Demo resource group."
  value       = azurerm_resource_group.this.name
}

output "key_vault_name" {
  description = "The vault being watched. Nobody has a data-plane role on it."
  value       = azurerm_key_vault.this.name
}

output "log_analytics_workspace_name" {
  description = "Workspace receiving the vault's audit logs."
  value       = azurerm_log_analytics_workspace.this.name
}

output "log_analytics_workspace_id" {
  description = "Workspace (customer) ID — what `az monitor log-analytics query -w` wants."
  value       = azurerm_log_analytics_workspace.this.workspace_id
}

output "diagnostics_mode" {
  description = "How the vault's diagnostic setting gets created."
  value       = var.diagnostics_via_policy ? "POLICY — DeployIfNotExists assignment 'precon-kv-diagnostics' on this resource group; the setting is named setByPolicy-LogAnalytics" : "TERRAFORM — created directly as setByTerraform-LogAnalytics (fallback path)"
}

output "alert_routing" {
  description = "Who the action group will tell."
  value = (var.alert_email == "" && var.alert_sms_number == "") ? "NOBODY — set alert_email and/or alert_sms_number, then re-apply" : join(", ", compact([
    var.alert_email != "" ? "email ${var.alert_email}" : "",
    var.alert_sms_number != "" ? "SMS +${var.alert_sms_country_code} ${var.alert_sms_number}" : "",
  ]))
}

output "check_diagnostic_setting_command" {
  description = "Confirm the vault has its diagnostic setting — and who named it."
  value       = "az monitor diagnostic-settings list --resource ${azurerm_key_vault.this.id} --query \"[].{name:name, workspace:workspaceId}\" -o table"
}

output "remediation_status_command" {
  description = "Policy path only: has the remediation task finished?"
  value       = var.diagnostics_via_policy ? "az policy remediation show -n precon-kv-diagnostics -g ${azurerm_resource_group.this.name} --query \"{state:provisioningState, deployments:deploymentStatus}\" -o json" : "n/a — diagnostics_via_policy = false"
}

output "generate_denied_requests_command" {
  description = "Fifteen secret reads you aren't allowed to make. Each one is a 403."
  value       = "for i in $(seq 1 15); do az keyvault secret list --vault-name ${azurerm_key_vault.this.name} -o none 2>/dev/null; done; echo 'done - 15 denied requests'"
}

output "query_command" {
  description = "The log alert's query, from the terminal. Logs take a few minutes to arrive."
  value       = "az monitor log-analytics query -w ${azurerm_log_analytics_workspace.this.workspace_id} --analytics-query \"AzureDiagnostics | where ResourceProvider == 'MICROSOFT.KEYVAULT' and ResultSignature == 'Forbidden' | summarize Denied = count() by CallerIPAddress, OperationName\" -o table"
}
