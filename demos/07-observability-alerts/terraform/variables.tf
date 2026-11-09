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
    error_message = "prefix must be 3-8 lowercase alphanumeric characters."
  }
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "eastus2"
}

variable "alert_email" {
  description = <<-EOT
    Where alerts and budget notifications are emailed. Set this — without it
    (and without an SMS number) the action group has nobody to tell.
  EOT
  type        = string
  default     = ""

  validation {
    condition     = var.alert_email == "" || can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must be empty or a valid email address."
  }
}

variable "alert_sms_number" {
  description = "Mobile number for SMS alerts, digits only, no country code. Empty = email only."
  type        = string
  default     = ""

  validation {
    condition     = var.alert_sms_number == "" || can(regex("^[0-9]{6,15}$", var.alert_sms_number))
    error_message = "alert_sms_number must be empty or digits only."
  }
}

variable "alert_sms_country_code" {
  description = "Country code for alert_sms_number, digits only (1 = US/Canada)."
  type        = string
  default     = "1"
}

variable "forbidden_request_threshold" {
  description = "Denied (403) Key Vault requests in the window before either alert fires."
  type        = number
  default     = 5
}

variable "diagnostics_via_policy" {
  description = <<-EOT
    true  = a DeployIfNotExists policy assignment wires the vault's diagnostic
            setting (the point of the demo).
    false = Terraform creates the same diagnostic setting directly. The stage
            fallback if the policy remediation hasn't finished in time.
  EOT
  type        = bool
  default     = true
}

variable "create_budget" {
  description = "Create the resource-group budget. Some subscription types (e.g. some CSP and sponsorship offers) don't support budgets — set false there."
  type        = bool
  default     = true
}

variable "monthly_budget_amount" {
  description = "Monthly budget for the demo resource group, in the billing currency."
  type        = number
  default     = 10
}

variable "tags" {
  description = "Extra tags for this stack, added to the standard set from modules/standard-tags."
  type        = map(string)
  default     = {}
}
