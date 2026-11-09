variable "demo" {
  description = "The demo's folder name, e.g. 01-azure-sql-private — tells whoever finds the resource which stack owns it."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{2}-[a-z0-9-]+$", var.demo))
    error_message = "demo must be the demo's folder name, e.g. 01-azure-sql-private."
  }
}

variable "workload" {
  description = "Groups every stack's spend under one name in Cost Management."
  type        = string
  default     = "AzurePrecon"
}

variable "environment" {
  description = "Lifecycle stage. Policies, budgets and cleanup jobs key off it."
  type        = string
  default     = "Demo"

  validation {
    condition     = contains(["Demo", "Dev", "Test", "Prod"], var.environment)
    error_message = "environment must be one of Demo, Dev, Test or Prod."
  }
}

variable "cost_center" {
  description = "Chargeback code. Demo 02's initiative audits for this tag."
  type        = string
  default     = "FIN-1042"
}

variable "owner" {
  description = "Who to ask before changing or deleting the resource. A team, not a person — people leave."
  type        = string
  default     = "Platform Team"
}

variable "extra_tags" {
  description = "Stack-specific tags added alongside the standard set. They can't redefine a standard tag."
  type        = map(string)
  default     = {}

  validation {
    condition     = length(setintersection(keys(var.extra_tags), ["Workload", "Environment", "Demo", "CostCenter", "Owner", "ManagedBy"])) == 0
    error_message = "extra_tags can't redefine a standard tag. Change the standard in modules/standard-tags instead."
  }
}
