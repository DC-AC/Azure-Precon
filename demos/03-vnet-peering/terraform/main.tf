###############################################################################
# Demo 03 — VNet Peering (hub-and-spoke)
#
# Slide: "Demonstration — VNet Peering" (Section 4, Networking & Network Security)
#   - Configure peering, VPN gateway, gateway transit; confirm connectivity
#
# Topology:
#
#              (optional)                       (optional)
#            VPN Gateway  ─┐               ┌─ Azure Bastion
#                          │               │
#                    ┌─────┴───────────────┴─────┐
#                    │  vnet-hub   10.0.0.0/16   │
#                    │  GatewaySubnet            │
#                    │  AzureBastionSubnet       │
#                    │  snet-workload  + vm-hub  │
#                    └──────┬──────────────┬─────┘
#            peering (x2)   │              │   peering (x2)
#                    ┌──────┴─────┐  ┌─────┴──────┐
#                    │ vnet-spoke1│  │ vnet-spoke2│
#                    │ 10.1.0.0/16│  │ 10.2.0.0/16│
#                    │  vm-spoke1 │  │  vm-spoke2 │
#                    └──────╥─────┘  └─────╥──────┘
#                           ╚══ NOT peered ═╝
#                        (unless enable_spoke_to_spoke_peering)
#
# The missing spoke-to-spoke link is deliberate. "Peering is non-transitive" is
# an abstract sentence on a slide and an obvious fact once they watch a ping fail.
###############################################################################

resource "random_string" "suffix" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "random_password" "vm_admin" {
  length           = 24
  special          = true
  override_special = "!@#$%^&*()-_"
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
}

locals {
  # Resource group names follow rg-<demo>-<core tech>-<region>. Only globally
  # unique names (storage, Key Vault, SQL, function apps) carry the random suffix.
  region_codes = {
    eastus         = "eus"
    eastus2        = "eus2"
    centralus      = "cus"
    northcentralus = "ncus"
    southcentralus = "scus"
    westus         = "wus"
    westus2        = "wus2"
    westus3        = "wus3"
    canadacentral  = "cac"
    northeurope    = "neu"
    westeurope     = "weu"
    uksouth        = "uks"
  }
  region_code = lookup(local.region_codes, var.location, var.location)

  suffix = "${var.prefix}-${random_string.suffix.result}"
}

# The precon-wide tag standard. See ../../modules/standard-tags.
module "tags" {
  source = "../../modules/standard-tags"

  demo       = "03-vnet-peering"
  extra_tags = var.tags
}

resource "azurerm_resource_group" "this" {
  name     = "rg-demo03-network-${local.region_code}"
  location = var.location
  tags     = module.tags.tags
}

###############################################################################
# Hub
###############################################################################

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.hub_address_space]
  tags                = module.tags.tags
}

resource "azurerm_subnet" "hub_workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.hub_address_space, 8, 1)] # 10.0.1.0/24
}

# Name is fixed by Azure — a gateway will not deploy into anything else.
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.hub_address_space, 11, 2040)] # 10.0.255.0/27
}

# Also a fixed name, minimum /26.
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.hub_address_space, 10, 1016)] # 10.0.254.0/26
}

###############################################################################
# Spokes
###############################################################################

resource "azurerm_virtual_network" "spoke1" {
  name                = "vnet-spoke1-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.spoke1_address_space]
  tags                = module.tags.tags
}

resource "azurerm_subnet" "spoke1_workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.spoke1.name
  address_prefixes     = [cidrsubnet(var.spoke1_address_space, 8, 1)]
}

resource "azurerm_virtual_network" "spoke2" {
  name                = "vnet-spoke2-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.spoke2_address_space]
  tags                = module.tags.tags
}

resource "azurerm_subnet" "spoke2_workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.spoke2.name
  address_prefixes     = [cidrsubnet(var.spoke2_address_space, 8, 1)]
}

###############################################################################
# NSGs — allow intra-private-network SSH and ICMP, deny everything from internet
###############################################################################

resource "azurerm_network_security_group" "workload" {
  name                = "nsg-workload-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = module.tags.tags
  # Service tags instead of hand-maintained CIDR lists — the ASG/service-tag
  # slide, made concrete.
  security_rule {
    name                       = "AllowVnetInboundSsh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowVnetInboundIcmp"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "DenyInternetInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "hub" {
  subnet_id                 = azurerm_subnet.hub_workload.id
  network_security_group_id = azurerm_network_security_group.workload.id
}

resource "azurerm_subnet_network_security_group_association" "spoke1" {
  subnet_id                 = azurerm_subnet.spoke1_workload.id
  network_security_group_id = azurerm_network_security_group.workload.id
}

resource "azurerm_subnet_network_security_group_association" "spoke2" {
  subnet_id                 = azurerm_subnet.spoke2_workload.id
  network_security_group_id = azurerm_network_security_group.workload.id
}

###############################################################################
# VPN gateway (optional — 30-45 minute provision)
###############################################################################

resource "azurerm_public_ip" "vpn" {
  count = var.deploy_vpn_gateway ? 1 : 0

  name                = "pip-vpngw-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = module.tags.tags
}

resource "azurerm_virtual_network_gateway" "vpn" {
  count = var.deploy_vpn_gateway ? 1 : 0

  name                = "vpngw-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  type     = "Vpn"
  vpn_type = "RouteBased"
  sku      = var.vpn_gateway_sku

  # The 1-series SKUs only exist as Generation1; VpnGw2 and up can be either.
  generation = startswith(var.vpn_gateway_sku, "VpnGw1") ? "Generation1" : "Generation2"

  active_active = false
  bgp_enabled   = false

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  tags = module.tags.tags
}

###############################################################################
# Peerings
#
# Non-transitive and reciprocal: every link is two resources, one per direction.
###############################################################################

resource "azurerm_virtual_network_peering" "hub_to_spoke1" {
  name                      = "peer-hub-to-spoke1"
  resource_group_name       = azurerm_resource_group.this.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke1.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  # Hub side offers the gateway; spoke side consumes it.
  allow_gateway_transit = var.deploy_vpn_gateway
  use_remote_gateways   = false

  depends_on = [azurerm_virtual_network_gateway.vpn]
}

resource "azurerm_virtual_network_peering" "spoke1_to_hub" {
  name                      = "peer-spoke1-to-hub"
  resource_group_name       = azurerm_resource_group.this.name
  virtual_network_name      = azurerm_virtual_network.spoke1.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  allow_gateway_transit = false
  use_remote_gateways   = var.deploy_vpn_gateway

  depends_on = [
    azurerm_virtual_network_gateway.vpn,
    azurerm_virtual_network_peering.hub_to_spoke1,
  ]
}

resource "azurerm_virtual_network_peering" "hub_to_spoke2" {
  name                      = "peer-hub-to-spoke2"
  resource_group_name       = azurerm_resource_group.this.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke2.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  allow_gateway_transit = var.deploy_vpn_gateway
  use_remote_gateways   = false

  depends_on = [azurerm_virtual_network_gateway.vpn]
}

resource "azurerm_virtual_network_peering" "spoke2_to_hub" {
  name                      = "peer-spoke2-to-hub"
  resource_group_name       = azurerm_resource_group.this.name
  virtual_network_name      = azurerm_virtual_network.spoke2.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  allow_gateway_transit = false
  use_remote_gateways   = var.deploy_vpn_gateway

  depends_on = [
    azurerm_virtual_network_gateway.vpn,
    azurerm_virtual_network_peering.hub_to_spoke2,
  ]
}

# The live fix for the non-transitivity demo. Off by default.
resource "azurerm_virtual_network_peering" "spoke1_to_spoke2" {
  count = var.enable_spoke_to_spoke_peering ? 1 : 0

  name                      = "peer-spoke1-to-spoke2"
  resource_group_name       = azurerm_resource_group.this.name
  virtual_network_name      = azurerm_virtual_network.spoke1.name
  remote_virtual_network_id = azurerm_virtual_network.spoke2.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "spoke2_to_spoke1" {
  count = var.enable_spoke_to_spoke_peering ? 1 : 0

  name                      = "peer-spoke2-to-spoke1"
  resource_group_name       = azurerm_resource_group.this.name
  virtual_network_name      = azurerm_virtual_network.spoke2.name
  remote_virtual_network_id = azurerm_virtual_network.spoke1.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

###############################################################################
# Azure Bastion (optional)
###############################################################################

resource "azurerm_public_ip" "bastion" {
  count = var.deploy_bastion ? 1 : 0

  name                = "pip-bastion-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = module.tags.tags
}

resource "azurerm_bastion_host" "this" {
  count = var.deploy_bastion ? 1 : 0

  name                = "bas-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Basic"

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }

  tags = module.tags.tags
}

###############################################################################
# Connectivity-test VMs — no public IPs anywhere
###############################################################################

locals {
  test_vms = var.deploy_test_vms ? {
    hub    = azurerm_subnet.hub_workload.id
    spoke1 = azurerm_subnet.spoke1_workload.id
    spoke2 = azurerm_subnet.spoke2_workload.id
  } : {}
}

resource "azurerm_network_interface" "test" {
  for_each = local.test_vms

  name                = "nic-${each.key}-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = module.tags.tags
  ip_configuration {
    name                          = "internal"
    subnet_id                     = each.value
    private_ip_address_allocation = "Dynamic"
    # Deliberately no public_ip_address_id. Section 5's checklist says
    # "no public IP by default" — this is what that looks like.
  }
}

resource "azurerm_linux_virtual_machine" "test" {
  for_each = local.test_vms

  name                  = "vm-${each.key}-${var.prefix}"
  location              = azurerm_resource_group.this.location
  resource_group_name   = azurerm_resource_group.this.name
  size                  = var.vm_size
  admin_username        = var.admin_username
  tags                  = module.tags.tags
  network_interface_ids = [azurerm_network_interface.test[each.key].id]

  # Password auth so Bastion login works live without key distribution.
  # Real workloads: SSH keys or Entra ID login extension only.
  admin_password                  = random_password.vm_admin.result
  disable_password_authentication = false

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  boot_diagnostics {} # managed boot diagnostics, no storage account needed

  depends_on = [
    azurerm_subnet_network_security_group_association.hub,
    azurerm_subnet_network_security_group_association.spoke1,
    azurerm_subnet_network_security_group_association.spoke2,
  ]
}
