provider "azurerm" {
  features {
  }
}

#variables
variable "A-location" {
    description = "Location of the resources"
    #default     = "eastus"
    validation {
    condition = contains(
      ["eastus","eastus2","southcentralus","westus2","westus3","australiaeast","southeastasia","northeurope","swedencentral","uksouth","westeurope","centralus","southafricanorth","centralindia","eastasia","japaneast","koreacentral","canadacentral","francecentral","germanywestcentral","norwayeast","polandcentral","switzerlandnorth","uaenorth","brazilsouth","centraluseuap","eastus2euap","qatarcentral","centralusstage","eastusstage","eastus2stage","northcentralusstage","southcentralusstage","westusstage","westus2stage","asia","asiapacific","australia","brazil","canada","europe","france","germany","global","india","japan","korea","norway","singapore","southafrica","switzerland","uae","uk","unitedstates","unitedstateseuap","eastasiastage","southeastasiastage","brazilus","eastusstg","northcentralus","westus","jioindiawest","southcentralusstg","westcentralus","southafricawest","australiacentral","australiacentral2","australiasoutheast","japanwest","jioindiacentral","koreasouth","southindia","westindia","canadaeast","francesouth","germanynorth","norwaywest","switzerlandwest","ukwest","uaecentral","brazilsoutheast"],
      var.A-location
    )
    error_message = "Err: location is not valid. Needs to be something like eastus2"
  }
}

variable "B-resource_group_name" {
    description = "Name of the resource group to create"
}

variable "C-home_public_ip" {
    description = "Your home public ip address"
}

variable "D-username" {
    description = "Username for Virtual Machines"
    #default     = "azureuser"
}

variable "E-password" {
    description = "Password for Virtual Machines"
    sensitive = true
}

resource "azurerm_resource_group" "RG" {
  location = var.A-location
  name     = var.B-resource_group_name
  provisioner "local-exec" {
    
    command = "az vm image terms accept --urn cisco:cisco-asav:asav-azure-byol:latest"
  }
}

#logic app to self destruct resourcegroup after 24hrs
data "azurerm_subscription" "sub" {
}

resource "azurerm_logic_app_workflow" "workflow1" {
  location = azurerm_resource_group.RG.location
  name     = "labdelete"
  resource_group_name = azurerm_resource_group.RG.name
  identity {
    type = "SystemAssigned"
  }
  depends_on = [
    azurerm_resource_group.RG,
  ]
}
resource "azurerm_role_assignment" "contrib1" {
  scope = azurerm_resource_group.RG.id
  role_definition_name = "Contributor"
  principal_id  = azurerm_logic_app_workflow.workflow1.identity[0].principal_id
  depends_on = [azurerm_logic_app_workflow.workflow1]
}

resource "azurerm_resource_group_template_deployment" "apiconnections" {
  name                = "group-deploy"
  resource_group_name = azurerm_resource_group.RG.name
  deployment_mode     = "Incremental"
  template_content = <<TEMPLATE
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {},
    "variables": {},
    "resources": [
        {
            "type": "Microsoft.Web/connections",
            "apiVersion": "2016-06-01",
            "name": "arm-1",
            "location": "${azurerm_resource_group.RG.location}",
            "kind": "V1",
            "properties": {
                "displayName": "labdeleteconn1",
                "authenticatedUser": {},
                "statuses": [
                    {
                        "status": "Ready"
                    }
                ],
                "connectionState": "Enabled",
                "customParameterValues": {},
                "alternativeParameterValues": {},
                "parameterValueType": "Alternative",
                "createdTime": "2023-05-21T23:07:20.1346918Z",
                "changedTime": "2023-05-21T23:07:20.1346918Z",
                "api": {
                    "name": "arm",
                    "displayName": "Azure Resource Manager",
                    "description": "Azure Resource Manager exposes the APIs to manage all of your Azure resources.",
                    "iconUri": "https://connectoricons-prod.azureedge.net/laborbol/fixes/path-traversal/1.0.1552.2695/arm/icon.png",
                    "brandColor": "#003056",
                    "id": "/subscriptions/${data.azurerm_subscription.sub.subscription_id}/providers/Microsoft.Web/locations/${azurerm_resource_group.RG.location}/managedApis/arm",
                    "type": "Microsoft.Web/locations/managedApis"
                },
                "testLinks": []
            }
        },
        {
            "type": "Microsoft.Logic/workflows",
            "apiVersion": "2017-07-01",
            "name": "labdelete",
            "location": "${azurerm_resource_group.RG.location}",
            "dependsOn": [
                "[resourceId('Microsoft.Web/connections', 'arm-1')]"
            ],
            "identity": {
                "type": "SystemAssigned"
            },
            "properties": {
                "state": "Enabled",
                "definition": {
                    "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
                    "contentVersion": "1.0.0.0",
                    "parameters": {
                        "$connections": {
                            "defaultValue": {},
                            "type": "Object"
                        }
                    },
                    "triggers": {
                        "Recurrence": {
                            "recurrence": {
                                "frequency": "Minute",
                                "interval": 3,
                                "startTime": "${timeadd(timestamp(),"24h")}"
                            },
                            "evaluatedRecurrence": {
                                "frequency": "Minute",
                                "interval": 3,
                                "startTime": "${timeadd(timestamp(),"24h")}"
                            },
                            "type": "Recurrence"
                        }
                    },
                    "actions": {
                        "Delete_a_resource_group": {
                            "runAfter": {},
                            "type": "ApiConnection",
                            "inputs": {
                                "host": {
                                    "connection": {
                                        "name": "@parameters('$connections')['arm']['connectionId']"
                                    }
                                },
                                "method": "delete",
                                "path": "/subscriptions/@{encodeURIComponent('${data.azurerm_subscription.sub.subscription_id}')}/resourcegroups/@{encodeURIComponent('${azurerm_resource_group.RG.name}')}",
                                "queries": {
                                    "x-ms-api-version": "2016-06-01"
                                }
                            }
                        }
                    },
                    "outputs": {}
                },
                "parameters": {
                    "$connections": {
                        "value": {
                            "arm": {
                                "connectionId": "[resourceId('Microsoft.Web/connections', 'arm-1')]",
                                "connectionName": "arm-1",
                                "connectionProperties": {
                                    "authentication": {
                                        "type": "ManagedServiceIdentity"
                                    }
                                },
                                "id": "/subscriptions/${data.azurerm_subscription.sub.subscription_id}/providers/Microsoft.Web/locations/${azurerm_resource_group.RG.location}/managedApis/arm"
                            }
                        }
                    }
                }
            }
        }
    ]
}
TEMPLATE
}

#vnets and subnets
resource "azurerm_virtual_network" "hub-vnet" {
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.RG.location
  name                = "AZ-hub-vnet"
  resource_group_name = azurerm_resource_group.RG.name
  subnet {
    address_prefix     = "10.0.0.0/24"
    name                 = "default"
    security_group = azurerm_network_security_group.hubvnetNSG.id
  }
  subnet {
    address_prefix     = "10.0.1.0/24"
    name                 = "GatewaySubnet" 
  }
  subnet {
    address_prefix     = "10.0.2.0/24"
    name                 = "outside"
    security_group =  azurerm_network_security_group.hubasavsshnsg.id
  }
  subnet {
    address_prefix     = "10.0.3.0/24"
    name                 = "inside" 
    security_group = azurerm_network_security_group.hubasavnsg.id
  }
  subnet {
    address_prefix     = "10.0.4.0/24"
    name                 = "RouteServerSubnet" 
    
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
}
resource "azurerm_virtual_network" "spoke-vnet" {
  address_space       = ["10.250.0.0/16"]
  location            = azurerm_resource_group.RG.location
  name                = "AZ-spoke-vnet"
  resource_group_name = azurerm_resource_group.RG.name
  subnet {
    address_prefix     = "10.250.0.0/24"
    name                 = "default"
    security_group = azurerm_network_security_group.spokevnetNSG.id
  }
  subnet {
    address_prefix     = "10.250.1.0/24"
    name                 = "GatewaySubnet" 
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

resource "azurerm_virtual_network_peering" "hubtospokepeering" {
  name                      = "hub-to-spoke-peering"
  remote_virtual_network_id = azurerm_virtual_network.spoke-vnet.id
  resource_group_name       = azurerm_resource_group.RG.name
  virtual_network_name      = "AZ-hub-vnet"
  allow_forwarded_traffic = true
  allow_gateway_transit = true
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  depends_on = [
    azurerm_virtual_network.hub-vnet,
    azurerm_virtual_network.spoke-vnet,
    azurerm_route_server.RS1
  ]
}
resource "azurerm_virtual_network_peering" "spoketohubpeering" {
  name                      = "spoke-to-hub-peering"
  remote_virtual_network_id = azurerm_virtual_network.hub-vnet.id
  resource_group_name       = azurerm_resource_group.RG.name
  virtual_network_name      = "AZ-spoke-vnet"
  allow_forwarded_traffic = true
  use_remote_gateways = true
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  depends_on = [
    azurerm_virtual_network.spoke-vnet,
    azurerm_virtual_network.hub-vnet,
    azurerm_route_server.RS1
  ]
}
resource "azurerm_virtual_network" "onprem-vnet" {
  address_space       = ["192.168.0.0/16"]
  location            = azurerm_resource_group.RG.location
  name                = "onprem-vnet"
  resource_group_name = azurerm_resource_group.RG.name
  subnet {
    address_prefix     = "192.168.0.0/24"
    name                 = "default"
    security_group = azurerm_network_security_group.onpremvnetNSG.id
  }
  subnet {
    address_prefix     = "192.168.1.0/24"
    name                 = "GatewaySubnet" 
  }
  subnet {
    address_prefix     = "192.168.2.0/24"
    name                 = "outside"
    security_group =  azurerm_network_security_group.asavsshnsg.id
  }
  subnet {
    address_prefix     = "192.168.3.0/24"
    name                 = "inside" 
    security_group = azurerm_network_security_group.asavnsg.id
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

#route tables
resource "azurerm_route_table" "RT" {
  name                          = "RT"
  location                      = azurerm_resource_group.RG.location
  resource_group_name           = azurerm_resource_group.RG.name
  disable_bgp_route_propagation = false

  route {
    name           = "toasav"
    address_prefix = "10.0.0.0/8"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = "192.168.3.4"
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
}
resource "azurerm_subnet_route_table_association" "onpremdefaultsubnet" {
  subnet_id      = azurerm_virtual_network.onprem-vnet.subnet.*.id[0]
  route_table_id = azurerm_route_table.RT.id
  timeouts {
    create = "2h"
    read = "2h"    
    delete = "2h"
  }
}

#NSG's
resource "azurerm_network_security_group" "hubvnetNSG" {
  location            = azurerm_resource_group.RG.location
  name                = "AZ-hub-vnet-default-nsg"
  resource_group_name = azurerm_resource_group.RG.name
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_security_rule" "hubvnetnsgrule1" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "3389"
  direction                   = "Inbound"
  name                        = "AllowCidrBlockRDPInbound"
  network_security_group_name = "AZ-hub-vnet-default-nsg"
  priority                    = 2711
  protocol                    = "Tcp"
  resource_group_name         = azurerm_network_security_group.hubvnetNSG.resource_group_name
  source_address_prefix       = var.C-home_public_ip
  source_port_range           = "*"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}



resource "azurerm_network_security_group" "spokevnetNSG" {
  location            = azurerm_resource_group.RG.location
  name                = "AZ-spoke-vnet-default-nsg"
  resource_group_name = azurerm_resource_group.RG.name
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_security_rule" "spokevnetnsgrule1" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "3389"
  direction                   = "Inbound"
  name                        = "AllowCidrBlockRDPInbound"
  network_security_group_name = "AZ-spoke-vnet-default-nsg"
  priority                    = 2711
  protocol                    = "Tcp"
  resource_group_name         = azurerm_network_security_group.spokevnetNSG.resource_group_name
  source_address_prefix       = var.C-home_public_ip
  source_port_range           = "*"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}


resource "azurerm_network_security_group" "onpremvnetNSG" {
  location            = azurerm_resource_group.RG.location
  name                = "onprem-vnet-default-nsg"
  resource_group_name = azurerm_resource_group.RG.name
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_security_rule" "onpremvnetnsgrule1" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "3389"
  direction                   = "Inbound"
  name                        = "AllowCidrBlockRDPInbound"
  network_security_group_name = "onprem-vnet-default-nsg"
  priority                    = 2711
  protocol                    = "Tcp"
  resource_group_name         = azurerm_network_security_group.onpremvnetNSG.resource_group_name
  source_address_prefix       = var.C-home_public_ip
  source_port_range           = "*"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_security_rule" "onpremvnetnsgrule2" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "22"
  direction                   = "Inbound"
  name                        = "AllowCidrBlockSSHInbound"
  network_security_group_name = "onprem-vnet-default-nsg"
  priority                    = 2712
  protocol                    = "Tcp"
  resource_group_name         = azurerm_network_security_group.onpremvnetNSG.resource_group_name
  source_address_prefix       = var.C-home_public_ip
  source_port_range           = "*"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

resource "azurerm_network_security_group" "asavnsg" {
  location            = azurerm_resource_group.RG.location
  name                = "onprem-asav-default-nsg"
  resource_group_name = azurerm_resource_group.RG.name
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_security_rule" "asavnsgrule1" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "*"
  direction                   = "Inbound"
  name                        = "AllowCidrBlockInbound"
  network_security_group_name = "onprem-asav-default-nsg"
  priority                    = 2711
  protocol                    = "*"
  resource_group_name         = azurerm_network_security_group.asavnsg.resource_group_name
  source_address_prefix       = "192.168.0.0/24"
  source_port_range           = "*"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_security_rule" "asavnsgrule2" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "*"
  direction                   = "Outbound"
  name                        = "AllowCidrBlockOutbound"
  network_security_group_name = "onprem-asav-default-nsg"
  priority                    = 2712
  protocol                    = "*"
  resource_group_name         = azurerm_network_security_group.asavnsg.resource_group_name
  source_address_prefix       = "10.0.0.0/8"
  source_port_range           = "*"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

resource "azurerm_network_security_group" "asavsshnsg" {
  location            = azurerm_resource_group.RG.location
  name                = "onprem-ssh-default-nsg"
  resource_group_name = azurerm_resource_group.RG.name
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_security_rule" "asavsshnsgrule1" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "22"
  direction                   = "Inbound"
  name                        = "AllowCidrBlockSSHInbound"
  network_security_group_name = "onprem-ssh-default-nsg"
  priority                    = 100
  protocol                    = "Tcp"
  resource_group_name         = azurerm_network_security_group.onpremvnetNSG.resource_group_name
  source_address_prefix       = var.C-home_public_ip
  source_port_range           = "*"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

resource "azurerm_network_security_group" "hubasavnsg" {
  location            = azurerm_resource_group.RG.location
  name                = "hub-asav-default-nsg"
  resource_group_name = azurerm_resource_group.RG.name
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_security_rule" "hubasavnsgrule1" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "*"
  direction                   = "Inbound"
  name                        = "AllowCidrBlockInbound"
  network_security_group_name = "hub-asav-default-nsg"
  priority                    = 2711
  protocol                    = "*"
  resource_group_name         = azurerm_network_security_group.hubasavnsg.resource_group_name
  source_address_prefix       = "10.0.0.0/8"
  source_port_range           = "*"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_security_rule" "hubasavnsgrule2" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "*"
  direction                   = "Outbound"
  name                        = "AllowCidrBlockOutbound"
  network_security_group_name = "hub-asav-default-nsg"
  priority                    = 2712
  protocol                    = "*"
  resource_group_name         = azurerm_network_security_group.hubasavnsg.resource_group_name
  source_address_prefix       = "192.168.0.0/24"
  source_port_range           = "*"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

resource "azurerm_network_security_group" "hubasavsshnsg" {
  location            = azurerm_resource_group.RG.location
  name                = "hub-ssh-default-nsg"
  resource_group_name = azurerm_resource_group.RG.name
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_security_rule" "hubasavsshnsgrule1" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "22"
  direction                   = "Inbound"
  name                        = "AllowCidrBlockSSHInbound"
  network_security_group_name = "hub-ssh-default-nsg"
  priority                    = 100
  protocol                    = "Tcp"
  resource_group_name         = azurerm_network_security_group.hubasavsshnsg.resource_group_name
  source_address_prefix       = var.C-home_public_ip
  source_port_range           = "*"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}


#Public IP's
resource "azurerm_public_ip" "hubasav-pip" {
  name                = "hubasav-pip"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  allocation_method = "Static"
  sku = "Standard"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_public_ip" "onpremasav-pip" {
  name                = "onpremasav-pip"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  allocation_method = "Static"
  sku = "Standard"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_public_ip" "hubvm-pip" {
  name                = "hubvm-pip"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  allocation_method = "Dynamic"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_public_ip" "spokevm-pip" {
  name                = "spokevm-pip"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  allocation_method = "Dynamic"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_public_ip" "onpremvm-pip" {
  name                = "onpremvm-pip"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  allocation_method = "Dynamic"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_public_ip" "routeserver-pip" {
  name                = "routeserver-pip"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  allocation_method = "Static"
  sku = "Standard"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

#Azure route server
resource "azurerm_route_server" "RS1" {
  name                             = "routeserver1"
  resource_group_name              = azurerm_resource_group.RG.name
  location                         = azurerm_resource_group.RG.location
  sku                              = "Standard"
  public_ip_address_id             = azurerm_public_ip.routeserver-pip.id
  subnet_id                        = azurerm_virtual_network.hub-vnet.subnet.*.id[4]
  branch_to_branch_traffic_enabled = true
  #provisioner "local-exec" {
  #  command = "az network routeserver peering create --name toasav --peer-ip 10.0.3.4 --peer-asn 65001 --routeserver routeserver1 --resource-group ${azurerm_resource_group.RG.name}"
  #}
}
resource "azurerm_route_server_bgp_connection" "bgpcon1" {
  name            = "ToASAv"
  route_server_id = azurerm_route_server.RS1.id
  peer_asn        = 65001
  peer_ip         = "10.0.3.4"
}



#vNIC's
resource "azurerm_network_interface" "hubvm-nic" {
  location            = azurerm_resource_group.RG.location
  name                = "hubvm-nic"
  resource_group_name = azurerm_resource_group.RG.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.hubvm-pip.id
    subnet_id                     = azurerm_virtual_network.hub-vnet.subnet.*.id[0]
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_interface" "spokevm-nic" {
  location            = azurerm_resource_group.RG.location
  name                = "spokevm-nic"
  resource_group_name = azurerm_resource_group.RG.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.spokevm-pip.id
    subnet_id                     = azurerm_virtual_network.spoke-vnet.subnet.*.id[0]
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_interface" "onpremvm-nic" {
  location            = azurerm_resource_group.RG.location
  name                = "onpremvm-nic"
  resource_group_name = azurerm_resource_group.RG.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.onpremvm-pip.id
    subnet_id                     = azurerm_virtual_network.onprem-vnet.subnet.*.id[0]
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_interface" "asavinside-nic" {
  enable_ip_forwarding = true
  location            = azurerm_resource_group.RG.location
  name                = "asavinside-nic"
  resource_group_name = azurerm_resource_group.RG.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_virtual_network.onprem-vnet.subnet.*.id[3]
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_interface" "asavoutside-nic" {
  enable_ip_forwarding = true
  location            = azurerm_resource_group.RG.location
  name                = "asavoutside-nic"
  resource_group_name = azurerm_resource_group.RG.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.onpremasav-pip.id
    subnet_id                     = azurerm_virtual_network.onprem-vnet.subnet.*.id[2]
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

resource "azurerm_network_interface" "hubasavinside-nic" {
  enable_ip_forwarding = true
  location            = azurerm_resource_group.RG.location
  name                = "hubasavinside-nic"
  resource_group_name = azurerm_resource_group.RG.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_virtual_network.hub-vnet.subnet.*.id[3]
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_interface" "hubasavoutside-nic" {
  enable_ip_forwarding = true
  location            = azurerm_resource_group.RG.location
  name                = "hubasavoutside-nic"
  resource_group_name = azurerm_resource_group.RG.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.hubasav-pip.id
    subnet_id                     = azurerm_virtual_network.hub-vnet.subnet.*.id[2]
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

#VM's
resource "azurerm_windows_virtual_machine" "hubvm" {
  admin_password        = var.E-password
  admin_username        = var.D-username
  location              = azurerm_resource_group.RG.location
  name                  = "hubvm"
  network_interface_ids = [azurerm_network_interface.hubvm-nic.id]
  resource_group_name   = azurerm_resource_group.RG.name
  size                  = "Standard_B2ms"
  identity {
    type = "SystemAssigned"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_virtual_machine_extension" "killhubvmfirewall" {
  auto_upgrade_minor_version = true
  name                       = "killhubvmfirewall"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  virtual_machine_id         = azurerm_windows_virtual_machine.hubvm.id
  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -command \"Set-NetFirewallProfile -Enabled False\""
    }
  SETTINGS
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_windows_virtual_machine" "spokevm" {
  admin_password        = var.E-password
  admin_username        = var.D-username
  location              = azurerm_resource_group.RG.location
  name                  = "spokevm"
  network_interface_ids = [azurerm_network_interface.spokevm-nic.id]
  resource_group_name   = azurerm_resource_group.RG.name
  size                  = "Standard_B2ms"
  identity {
    type = "SystemAssigned"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_virtual_machine_extension" "killspokevmfirewall" {
  auto_upgrade_minor_version = true
  name                       = "killspokevmfirewall"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  virtual_machine_id         = azurerm_windows_virtual_machine.spokevm.id
  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -command \"Set-NetFirewallProfile -Enabled False\""
    }
  SETTINGS
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_windows_virtual_machine" "onpremvm" {
  admin_password        = var.E-password
  admin_username        = var.D-username
  location              = azurerm_resource_group.RG.location
  name                  = "onpremvm"
  network_interface_ids = [azurerm_network_interface.onpremvm-nic.id]
  resource_group_name   = azurerm_resource_group.RG.name
  size                  = "Standard_B2ms"
  identity {
    type = "SystemAssigned"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_virtual_machine_extension" "killonpremvmfirewall" {
  auto_upgrade_minor_version = true
  name                       = "killonpremvmfirewall"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  virtual_machine_id         = azurerm_windows_virtual_machine.onpremvm.id
  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -command \"Set-NetFirewallProfile -Enabled False\""
    }
  SETTINGS
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

resource "azurerm_linux_virtual_machine" "asav" {
  admin_password                  = var.E-password
  admin_username                  = var.D-username
  disable_password_authentication = false
  location                        = azurerm_resource_group.RG.location
  name                            = "ASAv"
  network_interface_ids           = [azurerm_network_interface.asavoutside-nic.id,azurerm_network_interface.asavinside-nic.id]
  resource_group_name             = azurerm_resource_group.RG.name
  size                            = "Standard_D2_v2"
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  plan {
    name      = "asav-azure-byol"
    product   = "cisco-asav"
    publisher = "cisco"
  }
  source_image_reference {
    offer     = "cisco-asav"
    publisher = "cisco"
    sku       = "asav-azure-byol"
    version   = "latest"
  }
  custom_data = base64encode(local.asav_custom_data)
}

resource "azurerm_linux_virtual_machine" "hubasav" {
  admin_password                  = var.E-password
  admin_username                  = var.D-username
  disable_password_authentication = false
  location                        = azurerm_resource_group.RG.location
  name                            = "HubASAv"
  network_interface_ids           = [azurerm_network_interface.hubasavoutside-nic.id,azurerm_network_interface.hubasavinside-nic.id]
  resource_group_name             = azurerm_resource_group.RG.name
  size                            = "Standard_D2_v2"
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  plan {
    name      = "asav-azure-byol"
    product   = "cisco-asav"
    publisher = "cisco"
  }
  source_image_reference {
    offer     = "cisco-asav"
    publisher = "cisco"
    sku       = "asav-azure-byol"
    version   = "latest"
  }
  custom_data = base64encode(local.hubasav_custom_data)
}


# Locals Block for custom data
locals {
asav_custom_data = <<CUSTOM_DATA
int gi0/0
no shut
nameif inside
ip address dhcp

route inside 192.168.0.0 255.255.0.0 192.168.3.1

crypto ikev2 enable management

crypto ikev2 policy 50
 encryption aes-256
 integrity sha
 group 2
 prf sha
 lifetime seconds 86400

crypto ipsec ikev2 ipsec-proposal vpn
 protocol esp encryption aes-256
 protocol esp integrity sha-1
crypto ipsec profile vpn-profile
 set ikev2 ipsec-proposal vpn

interface Tunnel1
 nameif vpntunnel
 ip address 172.16.1.1 255.255.255.252
 tunnel source interface management
 tunnel destination ${azurerm_public_ip.hubasav-pip.ip_address}
 tunnel mode ipsec ipv4
 tunnel protection ipsec profile vpn-profile

group-policy vpn-tunnel internal
group-policy vpn-tunnel attributes
 vpn-tunnel-protocol ikev2

tunnel-group ${azurerm_public_ip.hubasav-pip.ip_address} type ipsec-l2l
tunnel-group ${azurerm_public_ip.hubasav-pip.ip_address} general-attributes
 default-group-policy vpn-tunnel
tunnel-group ${azurerm_public_ip.hubasav-pip.ip_address} ipsec-attributes
 ikev2 remote-authentication pre-shared-key vpn123
 ikev2 local-authentication pre-shared-key vpn123

router bgp 65002
  bgp log-neighbor-changes
  address-family ipv4
  neighbor 172.16.1.2 remote-as 65001
  neighbor 172.16.1.2 ebgp-multihop 255  
  network 192.168.0.0 mask 255.255.0.0
  neighbor 172.16.1.2 activate
  exit

access-list inside permit ip any any
access-group inside in interface inside

CUSTOM_DATA
hubasav_custom_data = <<CUSTOM_DATA
int gi0/0
no shut
nameif inside
ip address dhcp

route inside 10.0.0.0 255.255.0.0 10.0.3.1

crypto ikev2 enable management

crypto ikev2 policy 50
 encryption aes-256
 integrity sha
 group 2
 prf sha
 lifetime seconds 86400

crypto ipsec ikev2 ipsec-proposal vpn
 protocol esp encryption aes-256
 protocol esp integrity sha-1
crypto ipsec profile vpn-profile
 set ikev2 ipsec-proposal vpn

interface Tunnel1
 nameif vpntunnel
 ip address 172.16.1.2 255.255.255.252
 tunnel source interface management
 tunnel destination ${azurerm_public_ip.onpremasav-pip.ip_address}
 tunnel mode ipsec ipv4
 tunnel protection ipsec profile vpn-profile

group-policy vpn-tunnel internal
group-policy vpn-tunnel attributes
 vpn-tunnel-protocol ikev2

tunnel-group ${azurerm_public_ip.onpremasav-pip.ip_address} type ipsec-l2l
tunnel-group ${azurerm_public_ip.onpremasav-pip.ip_address} general-attributes
 default-group-policy vpn-tunnel
tunnel-group ${azurerm_public_ip.onpremasav-pip.ip_address} ipsec-attributes
 ikev2 remote-authentication pre-shared-key vpn123
 ikev2 local-authentication pre-shared-key vpn123

router bgp 65001
 bgp log-neighbor-changes
 address-family ipv4
 neighbor 172.16.1.1 remote-as 65002
 neighbor 172.16.1.1 ebgp-multihop 255 
 neighbor 10.0.4.4 remote-as 65515
 neighbor 10.0.4.4 ebgp-multihop 10
 neighbor 10.0.4.5 remote-as 65515
 neighbor 10.0.4.5 ebgp-multihop 10
 network 10.0.0.0 mask 255.255.0.0
 neighbor 172.16.1.1 activate
 neighbor 10.0.4.5 activate
 neighbor 10.0.4.4 activate
 exit

access-list inside permit ip any any
access-group inside in interface inside

CUSTOM_DATA  
}
