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
  description = <<-EOT
    Azure region.

    Flex Consumption is not available everywhere. Check before you change this:
      az functionapp list-flexconsumption-locations -o table
  EOT
  type        = string
  default     = "eastus2"
}

variable "runtime_name" {
  description = "Function runtime. The sample code in ../src is Python."
  type        = string
  default     = "python"
}

variable "runtime_version" {
  description = "Runtime version. Check availability with: az functionapp list-flexconsumption-runtimes --location <region> -o table"
  type        = string
  default     = "3.11"
}

variable "instance_memory_in_mb" {
  description = "Per-instance memory for Flex Consumption. 2048 is the default; 512/4096 also valid."
  type        = number
  default     = 2048
}

variable "maximum_instance_count" {
  description = "Scale ceiling. The Performance Efficiency pillar in one number — set it deliberately."
  type        = number
  default     = 40
}

variable "always_ready_instance_count" {
  description = <<-EOT
    Pre-warmed instances that never scale to zero. 0 = pure pay-per-execution
    with cold starts; >0 removes cold start and costs money 24x7.
    Setting this to 1 on stage is a very cheap way to make the cost/latency
    trade-off concrete.
  EOT
  type        = number
  default     = 0
}

variable "disable_storage_shared_key" {
  description = <<-EOT
    Set the storage account to Entra-ID-only (no account keys), matching the
    "Securing Storage — Move Past Keys and SAS" slide.

    Default false: the identity-based path here is fully wired, but if you deploy
    with an older tool that still expects a connection string it will fail hard
    on stage. Flip to true in pre-flight, confirm your deploy works, then leave it on.
  EOT
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    Environment = "Demo"
    Workload    = "AzurePrecon"
    Demo        = "04-function-app"
    CostCenter  = "FIN-1042"
  }
}
