output "resource_group_name" {
  description = "Demo resource group."
  value       = azurerm_resource_group.this.name
}

output "mode" {
  description = "What this deployment can actually do, in one line."
  value = (
    !var.create_policy_assignment ? "DEFINITIONS ONLY — the initiative is attached to no scope and evaluates nothing." :
    !var.enforce_policies ? "REPORT-ONLY — assigned at resource group scope in DoNotEnforce mode. Compliance is evaluated and reported; no effect fires." :
    "ENFORCING — Deny will block deployments and Modify will change resources within ${azurerm_resource_group.this.name}."
  )
}

output "blast_radius" {
  description = "Everything this assignment can reach."
  value       = var.create_policy_assignment ? azurerm_resource_group.this.id : "no assignment created"
}

output "policy_set_definition_id" {
  description = "Full ID of the initiative. Created whether or not it is assigned."
  value       = azurerm_policy_set_definition.guardrails.id
}

output "policy_assignment_id" {
  description = "Full ID of the initiative assignment, if one was created."
  value       = one(azurerm_resource_group_policy_assignment.guardrails[*].id)
}

output "policy_assignment_name" {
  description = "Short name of the initiative assignment, if one was created."
  value       = one(azurerm_resource_group_policy_assignment.guardrails[*].name)
}

output "noncompliant_storage_account" {
  description = "Storage account that is deliberately non-compliant (no tag, public blob access allowed)."
  value       = azurerm_storage_account.noncompliant.name
}

output "compliant_storage_account" {
  description = "Storage account that satisfies the initiative."
  value       = azurerm_storage_account.compliant.name
}

output "trigger_scan_command" {
  description = "Force an on-demand compliance scan instead of waiting for the ~30 minute cycle."
  value       = "az policy state trigger-scan --resource-group ${azurerm_resource_group.this.name}"
}

output "compliance_command" {
  description = "List non-compliant resources in the demo resource group."
  value       = <<-EOT
    az policy state list \
      --resource-group ${azurerm_resource_group.this.name} \
      --filter "complianceState eq 'NonCompliant'" \
      --query "[].{resource:resourceId, policy:policyDefinitionReferenceId}" -o table
  EOT
}

output "would_have_blocked_command" {
  description = "The report-only payoff: what the Deny-capable policies would have blocked had enforcement been on."
  value       = <<-EOT
    az policy state list \
      --resource-group ${azurerm_resource_group.this.name} \
      --filter "complianceState eq 'NonCompliant'" \
      --query "[].{policy:policyDefinitionReferenceId, action:policyDefinitionAction, resource:resourceId}" -o table
  EOT
}

output "remediation_command" {
  description = "Remediation task command. Only meaningful when enable_remediation and enforce_policies are both true."
  value = local.remediation_active && var.enforce_policies ? join(" ", [
    "az policy remediation create",
    "--name remediate-${var.required_tag_name}",
    "--resource-group ${azurerm_resource_group.this.name}",
    # one() rather than [0]: both arms of a conditional can be evaluated, and
    # indexing an empty list would be a hard error when no assignment exists.
    "--policy-assignment ${one(azurerm_resource_group_policy_assignment.guardrails[*].id)}",
    "--definition-reference-id modifyInheritTag",
    "--resource-discovery-mode ReEvaluateCompliance",
  ]) : "remediation is disabled — set enable_remediation=true and enforce_policies=true"
}
