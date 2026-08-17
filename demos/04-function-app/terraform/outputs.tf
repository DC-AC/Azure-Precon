output "resource_group_name" {
  description = "Demo resource group."
  value       = azurerm_resource_group.this.name
}

output "function_app_name" {
  description = "Function app name."
  value       = azurerm_function_app_flex_consumption.this.name
}

output "function_app_hostname" {
  description = "Default hostname of the function app."
  value       = azurerm_function_app_flex_consumption.this.default_hostname
}

output "function_app_url" {
  description = "Base URL of the function app."
  value       = "https://${azurerm_function_app_flex_consumption.this.default_hostname}"
}

output "storage_account_name" {
  description = "Storage account used for the deployment package and runtime state."
  value       = azurerm_storage_account.this.name
}

output "application_insights_name" {
  description = "Application Insights instance for live metrics and traces."
  value       = azurerm_application_insights.this.name
}

output "system_assigned_principal_id" {
  description = "Object ID of the function app's system-assigned identity — the thing that holds RBAC instead of a key."
  value       = azurerm_function_app_flex_consumption.this.identity[0].principal_id
}

output "deploy_command" {
  description = "Publish the sample function from ../src using the Azure Functions Core Tools."
  value       = "cd ../src && func azure functionapp publish ${azurerm_function_app_flex_consumption.this.name}"
}

output "list_functions_command" {
  description = "Confirm the deployed functions are registered with the host."
  value       = "az functionapp function list -g ${azurerm_resource_group.this.name} -n ${azurerm_function_app_flex_consumption.this.name} -o table"
}

output "function_key_command" {
  description = "Fetch the default host key needed to call the HTTP-triggered function."
  value       = "az functionapp keys list -g ${azurerm_resource_group.this.name} -n ${azurerm_function_app_flex_consumption.this.name} --query functionKeys.default -o tsv"
}

output "scale_settings" {
  description = "The Performance Efficiency knobs, as configured."
  value = {
    instance_memory_in_mb       = var.instance_memory_in_mb
    maximum_instance_count      = var.maximum_instance_count
    always_ready_instance_count = var.always_ready_instance_count
  }
}
