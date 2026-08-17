variable "subscription_id" {
  description = "Target subscription. Leave empty to use ARM_SUBSCRIPTION_ID or the az CLI default."
  type        = string
  default     = ""
}

variable "prefix" {
  description = "Short prefix for all resource names."
  type        = string
  default     = "azpre"

  validation {
    condition     = can(regex("^[a-z0-9]{3,8}$", var.prefix))
    error_message = "prefix must be 3-8 lowercase alphanumeric characters (it is used in globally unique storage account names)."
  }
}

variable "location" {
  description = "Azure region for the demo resource group and resources."
  type        = string
  default     = "eastus2"
}

variable "required_tag_name" {
  description = "Tag the initiative audits for."
  type        = string
  default     = "CostCenter"
}

variable "required_tag_value" {
  description = "Value stamped on the resource group. Compliant resources carry the same value."
  type        = string
  default     = "FIN-1042"
}

###############################################################################
# Blast-radius controls
#
# Defaults make this stack REPORT-ONLY: it evaluates compliance and reports,
# and it cannot block a deployment or modify a resource. Every switch below is
# off by default and has to be turned on deliberately.
###############################################################################

variable "create_policy_assignment" {
  description = <<-EOT
    Assign the initiative to the demo resource group.

    Set to false for a definitions-only deployment: the custom policies and the
    initiative are created and can be read, reviewed and diffed, but they are
    not attached to any scope at all and evaluate nothing.

    When true, the assignment is scoped to this stack's own resource group and
    nothing else — never a subscription, never a management group.
  EOT
  type        = bool
  default     = true
}

variable "enforce_policies" {
  description = <<-EOT
    Enforcement mode for the assignment.

    false (default) => "DoNotEnforce". Azure evaluates compliance and reports
    everything it would have blocked, but Deny and Modify effects DO NOT fire.
    This is Azure Policy's own report-only switch and it is the correct way to
    trial a guardrail against a live estate.

    true => "Default". Deny actually denies and Modify actually modifies.
  EOT
  type        = bool
  default     = false
}

variable "enable_remediation" {
  description = <<-EOT
    Include the Modify policy that writes a missing tag onto existing resources.

    false (default) => the initiative is audit-only. No Modify policy, no managed
    identity on the assignment, no role assignment, nothing that can change a
    resource. This also drops the permission requirement from Owner/User Access
    Administrator down to Resource Policy Contributor.

    true => adds the Modify policy, gives the assignment a system-assigned
    identity and grants it Tag Contributor on the demo resource group only.
    Modify still does nothing until enforce_policies is also true.
  EOT
  type        = bool
  default     = false
}

variable "audit_effect" {
  description = <<-EOT
    Effect for the audit policies in the initiative. Leave at Audit.

    Setting this to Deny only has teeth when enforce_policies is also true —
    the two switches are deliberately independent so you can stage the change.
  EOT
  type        = string
  default     = "Audit"

  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.audit_effect)
    error_message = "audit_effect must be one of Audit, Deny or Disabled."
  }
}

variable "tags" {
  description = "Tags applied to the resource group and to the compliant sample resource."
  type        = map(string)
  default = {
    Environment = "Demo"
    Workload    = "AzurePrecon"
    Demo        = "01-policy-compliance"
  }
}
