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
  description = <<-EOT
    Size for the connectivity-test VMs. B2ats_v2 is the cheapest current-generation
    burstable size. The original B-series (B1s and friends) is announced for
    retirement in November 2028 and is already capacity-restricted in some regions.
  EOT
  type        = string
  default     = "Standard_B2ats_v2"
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

    WARNING: a VpnGw1AZ takes 30-45 minutes to provision and costs roughly $0.19/hour.
    Deploy it the day before if you want the gateway-transit part of the slide, or
    leave it false and talk through the peering settings instead.
  EOT
  type        = bool
  default     = false
}

variable "vpn_gateway_sku" {
  description = <<-EOT
    VPN gateway SKU. VpnGw1AZ is the cheapest route-based option.

    Must be an AZ SKU. Azure stopped creating the non-AZ VpnGw1-5 SKUs on
    1 November 2025 and retired them on 30 September 2026 — the public IP in
    main.tf is already zone-redundant to match.
  EOT
  type        = string
  default     = "VpnGw1AZ"

  validation {
    condition     = can(regex("^VpnGw[1-5]AZ$", var.vpn_gateway_sku))
    error_message = "Use an AZ SKU (VpnGw1AZ-VpnGw5AZ). Non-AZ VPN gateway SKUs can no longer be created."
  }
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
  description = "Extra tags for this stack, added to the standard set from modules/standard-tags."
  type        = map(string)
  default     = {}
}
