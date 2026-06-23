param location string = resourceGroup().location
param vmName string = 'myVM'
param vmSize string = 'Standard_B2s'
param adminUsername string
@secure()
param adminPassword string
param environment string = 'dev'
param imagePublisher string = 'MicrosoftWindowsServer'
param imageOffer string = 'WindowsServer'
param imageSku string = '2022-Datacenter'
param imageVersion string = 'latest'

var uniqueSuffix = uniqueString(resourceGroup().id)
var vnetName = '${vmName}-vnet-${environment}'
var subnetName = '${vmName}-subnet-${environment}'
var nicName = '${vmName}-nic-${environment}'
var nsgName = '${vmName}-nsg-${environment}'
var publicIPName = '${vmName}-pip-${environment}'
var osDiskName = '${vmName}-osdisk'

resource publicIP 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${publicIPName}-${uniqueSuffix}'
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: '${vmName}-${uniqueSuffix}'
    }
  }
  sku: {
    name: 'Basic'
    tier: 'Regional'
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${nsgName}-${uniqueSuffix}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowRDP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: '${vnetName}-${uniqueSuffix}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: vnet
  name: subnetName
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${nicName}-${uniqueSuffix}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        name: '${osDiskName}-${uniqueSuffix}'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}

output vmId string = vm.id
output vmName string = vm.name
output publicIPAddress string = publicIP.properties.ipAddress
output publicIPDNS string = publicIP.properties.dnsSettings.fqdn
