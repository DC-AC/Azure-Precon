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

variable "public_network_access_enabled" {
  description = <<-EOT
    The live switch. Leave true for pre-flight and the first beat (connect from
    your laptop), then flip it on stage:

      terraform apply -var 'public_network_access_enabled=false'

    The function keeps working through the private endpoint; your laptop doesn't.
  EOT
  type        = bool
  default     = true
}

variable "client_ip_address" {
  description = <<-EOT
    Your laptop's public IPv4 address, for the one firewall rule on the server.
    Conference Wi-Fi changes this — set it at the venue:

      terraform apply -var "client_ip_address=$(curl -s https://api.ipify.org)"

    Empty = no firewall rule, and the laptop beat won't connect.
  EOT
  type        = string
  default     = ""

  validation {
    condition     = var.client_ip_address == "" || can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", var.client_ip_address))
    error_message = "client_ip_address must be empty or a single IPv4 address."
  }
}

variable "entra_admin_object_id" {
  description = "Object ID of the server's Entra admin. Empty = whoever runs terraform apply. In production, use an Entra group."
  type        = string
  default     = ""
}

variable "entra_admin_login_name" {
  description = "Display name recorded for the Entra admin. SQL keys on the object ID; this is the label you see in the portal."
  type        = string
  default     = "precon-entra-admin"
}

variable "auto_pause_delay_in_minutes" {
  description = "Serverless auto-pause delay. The first query after a pause takes 30-60 seconds while the database resumes."
  type        = number
  default     = 60

  validation {
    condition     = var.auto_pause_delay_in_minutes == -1 || var.auto_pause_delay_in_minutes >= 15
    error_message = "auto_pause_delay_in_minutes must be -1 (never pause) or at least 15."
  }
}

variable "backup_storage_redundancy" {
  description = "Backup storage redundancy for the database: Local, Zone, Geo or GeoZone. Only Geo and GeoZone allow geo-restore."
  type        = string
  default     = "Local"

  validation {
    condition     = contains(["Local", "Zone", "Geo", "GeoZone"], var.backup_storage_redundancy)
    error_message = "backup_storage_redundancy must be one of Local, Zone, Geo, GeoZone."
  }
}

variable "vnet_address_space" {
  description = "VNet address space. Must be a /16 — subnets are carved from it with cidrsubnet()."
  type        = string
  default     = "10.60.0.0/16"

  validation {
    condition     = can(cidrhost(var.vnet_address_space, 0)) && split("/", var.vnet_address_space)[1] == "16"
    error_message = "vnet_address_space must be a valid /16 CIDR."
  }
}

variable "runtime_version" {
  description = "Python version for the function. Check availability with: az functionapp list-flexconsumption-runtimes --location <region> --runtime python -o table"
  type        = string
  default     = "3.11"
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    Environment = "Demo"
    Workload    = "AzurePrecon"
    Demo        = "01-azure-sql-private"
    CostCenter  = "FIN-1042"
  }
}
