# Dev-only outbound internet for the Jump VM via a NAT Gateway.
#
# Azure retired default outbound internet access for new VMs (Sept 2025), so the
# Jump VM on JumpboxSubnet has no egress unless it is given an explicit path.
#   - Dev:        set deploy_jumpbox_nat_gateway = true (+ use_internet_routing = true).
#                 The NAT Gateway provides SNAT; the module's route table sends
#                 0.0.0.0/0 to the internet.
#   - Production: set deploy_jumpbox_nat_gateway = false and use_internet_routing = false
#                 with a real firewall_ip_address. The module routes 0.0.0.0/0 to the
#                 firewall, which SNATs. No NAT Gateway is created.
#
# Subnet id is built from the BYO VNet id + the module's fixed "JumpboxSubnet" name.

resource "azurerm_public_ip" "jumpbox_nat" {
  count = var.deploy_jumpbox_nat_gateway ? 1 : 0

  name                = "${var.name_prefix}-jumpbox-nat-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.jumpbox_nat_gateway_zone != null ? [var.jumpbox_nat_gateway_zone] : null
  tags                = var.tags

  depends_on = [module.ai_lz]
}

resource "azurerm_nat_gateway" "jumpbox" {
  count = var.deploy_jumpbox_nat_gateway ? 1 : 0

  name                    = "${var.name_prefix}-jumpbox-nat"
  resource_group_name     = var.resource_group_name
  location                = var.location
  sku_name                = "Standard"
  idle_timeout_in_minutes = var.jumpbox_nat_gateway_idle_timeout
  zones                   = var.jumpbox_nat_gateway_zone != null ? [var.jumpbox_nat_gateway_zone] : null
  tags                    = var.tags

  depends_on = [module.ai_lz]
}

resource "azurerm_nat_gateway_public_ip_association" "jumpbox" {
  count = var.deploy_jumpbox_nat_gateway ? 1 : 0

  nat_gateway_id       = azurerm_nat_gateway.jumpbox[0].id
  public_ip_address_id = azurerm_public_ip.jumpbox_nat[0].id
}

resource "azurerm_subnet_nat_gateway_association" "jumpbox" {
  count = var.deploy_jumpbox_nat_gateway ? 1 : 0

  subnet_id      = "${var.existing_vnet_resource_id}/subnets/JumpboxSubnet"
  nat_gateway_id = azurerm_nat_gateway.jumpbox[0].id

  depends_on = [module.ai_lz]
}
