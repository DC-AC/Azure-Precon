variable "subscription_id" {
  description = "Target subscription. Leave empty to use ARM_SUBSCRIPTION_ID or the az CLI default."
  type        = string
  default     = ""
}

variable "prefix" {
  description = "Short prefix for all resource names."
  type        = string
  default     = "azpre"
}

variable "location" {
  description = "Azure region for the hub and both spokes."
  type        = string
  default     = "eastus2"
}

variable "hub_address_space" {
  description = "Hub VNet address space. Must be a /16 — subnets are carved from it with cidrsubnet()."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.hub_address_space, 0)) && split("/", var.hub_address_space)[1] == "16"
    error_message = "hub_address_space must be a valid /16 CIDR block, e.g. 10.0.0.0/16."
  }
}

variable "spoke1_address_space" {
  description = "Spoke 1 VNet address space. Must be a /16 and must not overlap the hub or spoke 2."
  type        = string
  default     = "10.1.0.0/16"

  validation {
    condition     = can(cidrhost(var.spoke1_address_space, 0)) && split("/", var.spoke1_address_space)[1] == "16"
    error_message = "spoke1_address_space must be a valid /16 CIDR block, e.g. 10.1.0.0/16."
  }
}

variable "spoke2_address_space" {
  description = "Spoke 2 VNet address space. Must be a /16 and must not overlap the hub or spoke 1."
  type        = string
  default     = "10.2.0.0/16"

  validation {
    condition     = can(cidrhost(var.spoke2_address_space, 0)) && split("/", var.spoke2_address_space)[1] == "16"
    error_message = "spoke2_address_space must be a valid /16 CIDR block, e.g. 10.2.0.0/16."
  }
}

variable "deploy_test_vms" {
  description = "Deploy one small Linux VM in the hub and each spoke to prove connectivity. Set false for a network-only walkthrough."
  type        = bool
  default     = true
}

variable "vm_size" {
  description = "Size for the connectivity-test VMs. B1s is the cheapest broadly available option."
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Local admin username on the test VMs."
  type        = string
  default     = "azureuser"
}

variable "enable_spoke_to_spoke_peering" {
  description = <<-EOT
    Peer spoke1 directly to spoke2.

    Leave this FALSE for the live demo: the non-transitivity of peering is the
    teaching moment. Flip it to true on stage to fix spoke-to-spoke traffic in
    front of the room.
  EOT
  type        = bool
  default     = false
}

variable "deploy_vpn_gateway" {
  description = <<-EOT
    Deploy a VPN gateway in the hub and turn on gateway transit / use-remote-gateways
    on the peerings.

    WARNING: a VpnGw1 takes 30-45 minutes to provision and costs roughly $0.19/hour.
    Deploy it the day before if you want the gateway-transit part of the slide, or
    leave it false and talk through the peering settings instead.
  EOT
  type        = bool
  default     = false
}

variable "vpn_gateway_sku" {
  description = "VPN gateway SKU. VpnGw1 is the cheapest route-based option."
  type        = string
  default     = "VpnGw1"
}

variable "deploy_bastion" {
  description = <<-EOT
    Deploy Azure Bastion in the hub so you can also cover the
    "Azure Bastion — Kill the Public RDP/SSH Surface" slide from the same stack.

    Costs roughly $0.19/hour plus outbound data. Connectivity tests below use
    `az vm run-command` and do NOT require Bastion.
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
    Demo        = "02-vnet-peering"
    CostCenter  = "FIN-1042"
  }
}
