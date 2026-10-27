output "resource_group_name" {
  description = "Demo resource group."
  value       = azurerm_resource_group.this.name
}

output "sql_server_name" {
  description = "Logical server name."
  value       = azurerm_mssql_server.this.name
}

output "sql_server_fqdn" {
  description = "Server FQDN. Resolves to a public address from your laptop and to the private endpoint from inside the VNet."
  value       = azurerm_mssql_server.this.fully_qualified_domain_name
}

output "database_name" {
  description = "The AdventureWorksLT sample database."
  value       = azurerm_mssql_database.this.name
}

output "public_network_access" {
  description = "Where the live switch is right now."
  value = var.public_network_access_enabled ? (
    var.client_ip_address != "" ? "ENABLED — firewall allows ${var.client_ip_address} only. Flip with: terraform apply -var 'public_network_access_enabled=false'" : "ENABLED — but no client_ip_address set, so no firewall rule and your laptop can't connect"
  ) : "DISABLED — private endpoint only. Your laptop is refused; the function is not."
}

output "private_endpoint_ip" {
  description = "The server's private address inside the VNet."
  value       = azurerm_private_endpoint.sql.private_service_connection[0].private_ip_address
}

output "function_app_name" {
  description = "Function app name — also the name of its managed identity, which is what CREATE USER refers to."
  value       = azurerm_function_app_flex_consumption.this.name
}

output "function_app_url" {
  description = "Base URL of the function app."
  value       = "https://${azurerm_function_app_flex_consumption.this.default_hostname}"
}

output "sql_connection_string_setting" {
  description = "The SqlConnectionString app setting. Read it on stage — there's no secret in it."
  value       = local.sql_connection_string
}

output "deploy_command" {
  description = "Publish the sample functions from ../src using the Azure Functions Core Tools."
  value       = "cd ../src && func azure functionapp publish ${azurerm_function_app_flex_consumption.this.name}"
}

output "function_key_command" {
  description = "Fetch the default host key needed to call the HTTP-triggered functions."
  value       = "az functionapp keys list -g ${azurerm_resource_group.this.name} -n ${azurerm_function_app_flex_consumption.this.name} --query functionKeys.default -o tsv"
}

output "connect_command" {
  description = "Connect from your laptop as yourself, with Entra ID (go-sqlcmd)."
  value       = "sqlcmd -S ${azurerm_mssql_server.this.fully_qualified_domain_name} -d ${azurerm_mssql_database.this.name} --authentication-method ActiveDirectoryDefault -Q \"SELECT SUSER_SNAME() AS login_name, CONNECTIONPROPERTY('client_net_address') AS client_address\""
}

output "grant_command" {
  description = "Create a database user for the function's managed identity. Run from ../terraform as the Entra admin, while public access is on."
  value       = "sqlcmd -S ${azurerm_mssql_server.this.fully_qualified_domain_name} -d ${azurerm_mssql_database.this.name} --authentication-method ActiveDirectoryDefault -v FunctionIdentity=${azurerm_function_app_flex_consumption.this.name} -i ../sql/grant-function-access.sql"
}

output "restore_command" {
  description = "Point-in-time restore to ten minutes ago, as a new database, timed. macOS date syntax; on Linux use: date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S"
  value       = "time az sql db restore -g ${azurerm_resource_group.this.name} -s ${azurerm_mssql_server.this.name} -n ${azurerm_mssql_database.this.name} --dest-name ${azurerm_mssql_database.this.name}-restored --time \"$(date -u -v-10M +%Y-%m-%dT%H:%M:%S)\""
}
