output "resource_group_name" {
  description = "Demo resource group."
  value       = azurerm_resource_group.this.name
}

output "key_vault_name" {
  description = "Key Vault name."
  value       = azurerm_key_vault.this.name
}

output "certificate_name" {
  description = "Name of the auto-rotating certificate."
  value       = azurerm_key_vault_certificate.app.name
}

output "certificate_version" {
  description = "Version created by Terraform. Watch this change when you rotate."
  value       = azurerm_key_vault_certificate.app.version
}

output "certificate_thumbprint" {
  description = "Thumbprint of the current version — the fastest before/after proof on stage."
  value       = azurerm_key_vault_certificate.app.thumbprint
}

output "app_identity_client_id" {
  description = "Client ID of the consumer managed identity. No secret is issued with it — that is the point."
  value       = azurerm_user_assigned_identity.app.client_id
}

output "show_rotation_policy_command" {
  description = "Show the lifetime action that drives auto-renewal."
  value       = "az keyvault certificate show --vault-name ${azurerm_key_vault.this.name} -n ${azurerm_key_vault_certificate.app.name} --query policy.lifetimeActions"
}

output "list_versions_command" {
  description = "List certificate versions — one row per rotation."
  value       = "az keyvault certificate list-versions --vault-name ${azurerm_key_vault.this.name} -n ${azurerm_key_vault_certificate.app.name} --query '[].{version:id, created:attributes.created, expires:attributes.expires}' -o table"
}

output "rotate_now_command" {
  description = "Force a rotation on demand: re-issue under the existing policy, which is exactly what auto-renew does on schedule."
  value       = <<-EOT
    az keyvault certificate create \
      --vault-name ${azurerm_key_vault.this.name} \
      --name ${azurerm_key_vault_certificate.app.name} \
      --policy "$(az keyvault certificate show --vault-name ${azurerm_key_vault.this.name} -n ${azurerm_key_vault_certificate.app.name} --query policy -o json)"
  EOT
}

output "peek_events_command" {
  description = "Peek the rotation events that Event Grid delivered to the storage queue."
  value = var.enable_event_grid ? join(" ", [
    "az storage message peek --queue-name", azurerm_storage_queue.cert_events[0].name,
    "--account-name", azurerm_storage_account.events[0].name,
    "--auth-mode login --num-messages 10 -o json",
  ]) : "enable_event_grid is false"
}

output "event_queue_name" {
  description = "Storage queue receiving Key Vault certificate lifecycle events."
  value       = var.enable_event_grid ? azurerm_storage_queue.cert_events[0].name : null
}

output "event_storage_account" {
  description = "Storage account holding the event queue."
  value       = var.enable_event_grid ? azurerm_storage_account.events[0].name : null
}
