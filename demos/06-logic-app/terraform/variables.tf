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

variable "approval_threshold" {
  description = <<-EOT
    Order amount above which the workflow escalates instead of auto-approving.
    The whole point of putting this in a variable is that changing a business
    rule should be a reviewable one-line diff, not a click in a designer.
  EOT
  type        = number
  default     = 5000
}

variable "enable_queue_target" {
  description = <<-EOT
    Deploy a storage account + queue and grant the Logic App's managed identity
    'Storage Queue Data Message Sender'.

    Needed only if you plan to add an Azure Queues connector live in the designer
    — with this in place the connector authenticates with the managed identity
    and needs no key.
  EOT
  type        = bool
  default     = true
}

variable "tags" {
  description = "Extra tags for this stack, added to the standard set from modules/standard-tags."
  type        = map(string)
  default     = {}
}
