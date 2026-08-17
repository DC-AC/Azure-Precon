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

variable "certificate_name" {
  description = "Name of the auto-rotating certificate."
  type        = string
  default     = "app-tls-cert"
}

variable "certificate_subject" {
  description = "X.509 subject for the self-signed certificate."
  type        = string
  default     = "CN=demo.precon.local"
}

variable "certificate_dns_names" {
  description = "Subject alternative names on the certificate."
  type        = list(string)
  default     = ["demo.precon.local", "www.demo.precon.local"]
}

variable "certificate_validity_months" {
  description = <<-EOT
    Certificate lifetime. Kept short (3 months) so the auto-renew trigger is a
    believable near-term event rather than a year away.
  EOT
  type        = number
  default     = 3
}

variable "auto_renew_lifetime_percentage" {
  description = <<-EOT
    Percentage of the certificate lifetime at which Key Vault auto-renews.
    80 is the common default: a 90-day certificate renews itself at day 72,
    leaving an 18-day safety margin.
  EOT
  type        = number
  default     = 80

  validation {
    condition     = var.auto_renew_lifetime_percentage > 0 && var.auto_renew_lifetime_percentage < 100
    error_message = "auto_renew_lifetime_percentage must be between 1 and 99."
  }
}

variable "enable_purge_protection" {
  description = <<-EOT
    Purge protection is the production-correct setting and the deck recommends it.

    It is FALSE here because it cannot be disabled once enabled, and a protected
    vault survives `terraform destroy` for the full retention window — which turns
    a demo teardown into a 7-day wait. Turn it on for anything real.
  EOT
  type        = bool
  default     = false
}

variable "enable_event_grid" {
  description = <<-EOT
    Wire Key Vault lifecycle events to a storage queue so you can show a rotation
    event actually firing during the demo. Costs fractions of a cent.
  EOT
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    Environment = "Demo"
    Workload    = "AzurePrecon"
    Demo        = "03-keyvault-cert-rotation"
    CostCenter  = "FIN-1042"
  }
}
