output "resource_group_name" {
  description = "Demo resource group."
  value       = azurerm_resource_group.this.name
}

output "vm_private_ips" {
  description = "Private IP of each test VM, keyed by role."
  value       = { for k, nic in azurerm_network_interface.test : k => nic.private_ip_address }
}

output "vm_names" {
  description = "Name of each test VM, keyed by role."
  value       = { for k, vm in azurerm_linux_virtual_machine.test : k => vm.name }
}

output "vm_admin_username" {
  description = "Local admin username on the test VMs (for a Bastion login)."
  value       = var.admin_username
}

output "vm_admin_password" {
  description = "Local admin password on the test VMs. Demo-only convenience; use keys or Entra ID login for real workloads."
  value       = random_password.vm_admin.result
  sensitive   = true
}

output "test_hub_to_spoke1" {
  description = "Should SUCCEED — hub and spoke1 are directly peered."
  value = var.deploy_test_vms ? join(" ", [
    "az vm run-command invoke -g", azurerm_resource_group.this.name,
    "-n", azurerm_linux_virtual_machine.test["hub"].name,
    "--command-id RunShellScript --scripts",
    "'ping -c 3 -W 2 ${azurerm_network_interface.test["spoke1"].private_ip_address}'",
    "--query 'value[0].message' -o tsv",
  ]) : "deploy_test_vms is false"
}

output "test_spoke1_to_spoke2" {
  description = "Should FAIL until enable_spoke_to_spoke_peering = true — peering is non-transitive."
  value = var.deploy_test_vms ? join(" ", [
    "az vm run-command invoke -g", azurerm_resource_group.this.name,
    "-n", azurerm_linux_virtual_machine.test["spoke1"].name,
    "--command-id RunShellScript --scripts",
    "'ping -c 3 -W 2 ${azurerm_network_interface.test["spoke2"].private_ip_address}'",
    "--query 'value[0].message' -o tsv",
  ]) : "deploy_test_vms is false"
}

output "effective_routes_command" {
  description = "Show the routes Azure programmed on spoke1's NIC — peered ranges appear as VNetPeering."
  value = var.deploy_test_vms ? join(" ", [
    "az network nic show-effective-route-table -g", azurerm_resource_group.this.name,
    "-n", azurerm_network_interface.test["spoke1"].name, "-o table",
  ]) : "deploy_test_vms is false"
}

output "bastion_name" {
  description = "Bastion host name, if deployed."
  value       = var.deploy_bastion ? azurerm_bastion_host.this[0].name : null
}

output "vpn_gateway_public_ip" {
  description = "Public IP of the hub VPN gateway, if deployed — the on-prem side of a site-to-site tunnel targets this."
  value       = var.deploy_vpn_gateway ? azurerm_public_ip.vpn[0].ip_address : null
}

output "gateway_transit_enabled" {
  description = "Whether the peerings are carrying gateway transit."
  value       = var.deploy_vpn_gateway
}
