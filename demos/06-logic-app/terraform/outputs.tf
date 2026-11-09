output "resource_group_name" {
  description = "Demo resource group."
  value       = azurerm_resource_group.this.name
}

output "logic_app_name" {
  description = "Logic App workflow name."
  value       = azurerm_logic_app_workflow.orders.name
}

output "logic_app_principal_id" {
  description = "Object ID of the workflow's system-assigned identity — what connectors authenticate as."
  value       = azurerm_logic_app_workflow.orders.identity[0].principal_id
}

output "approval_threshold" {
  description = "Current auto-approve ceiling."
  value       = var.approval_threshold
}

output "trigger_callback_url" {
  description = "POST here to fire the workflow. Contains a SAS signature — treat it as a credential."
  value       = azurerm_logic_app_trigger_http_request.order_received.callback_url
  sensitive   = true
}

output "curl_auto_approved" {
  description = "Fires the workflow below the threshold — expect HTTP 200 auto-approved."
  value       = <<-EOT
    curl -sS -i -X POST "$(terraform output -raw trigger_callback_url)" \
      -H 'Content-Type: application/json' \
      -d '{"orderId":"SO-1001","customer":"Contoso","amount":250}'
  EOT
}

output "curl_escalated" {
  description = "Fires the workflow above the threshold — expect HTTP 202 escalated."
  value       = <<-EOT
    curl -sS -i -X POST "$(terraform output -raw trigger_callback_url)" \
      -H 'Content-Type: application/json' \
      -d '{"orderId":"SO-1002","customer":"Fabrikam","amount":42000}'
  EOT
}

output "run_history_command" {
  description = "List recent workflow runs and their status. Uses az rest so no CLI extension is needed."
  value       = <<-EOT
    az rest --method get \
      --url "https://management.azure.com${azurerm_logic_app_workflow.orders.id}/runs?api-version=2019-05-01" \
      --query "value[].{run:name, status:properties.status, started:properties.startTime}" -o table
  EOT
}

output "queue_storage_account" {
  description = "Storage account backing the optional connector target."
  value       = var.enable_queue_target ? azurerm_storage_account.this[0].name : null
}

output "queue_name" {
  description = "Queue the workflow identity is pre-authorised to write to."
  value       = var.enable_queue_target ? azurerm_storage_queue.escalations[0].name : null
}
