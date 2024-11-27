#!/bin/bash

# MachineLoggerDemo

# Azure CLI commands
anjuna-azure-cli disk create --docker-uri=machine_logger --disk-size 2G

az account show
export MY_AZURE_SUBSCRIPTION=$(az account show -o json | jq -r .id)

az group create --name myResourceGroup --location eastus

export RANDOM_SUFFIX=$(cat /dev/urandom | LC_ALL=C tr -dc '[:lower:][:digit:]' | head -c 5)
export STORAGE_ACCOUNT_NAME="anjunaquickstart${RANDOM_SUFFIX}"
az storage account create \
            --resource-group myResourceGroup \
            --allow-blob-public-access false \
            --name ${STORAGE_ACCOUNT_NAME}

az storage container create \
            --name mystoragecontainer \
            --account-name ${STORAGE_ACCOUNT_NAME} \
            --resource-group myResourceGroup

az disk create -g myResourceGroup -n MachineLogging --size-gb 1

az sig create --resource-group myResourceGroup --gallery-name myGallery

az sig image-definition create \
       --resource-group myResourceGroup \
       --gallery-name myGallery \
       --gallery-image-definition myFirstDefinition \
       --publisher Anjuna \
       --offer CVMGA \
       --os-type Linux \
       --sku AnjGALinux \
       --os-state specialized \
       --features SecurityType=ConfidentialVMSupported \
       --hyper-v-generation V2 \
       --architecture x64

anjuna-azure-cli disk upload \
  --disk disk.vhd \
  --image-name nginx-disk.vhd \
  --storage-account ${STORAGE_ACCOUNT_NAME} \
  --storage-container mystoragecontainer \
  --resource-group myResourceGroup \
  --image-gallery myGallery \
  --image-definition myFirstDefinition \
  --image-version 0.1.0 \
  --location eastus \
  --subscription-id ${MY_AZURE_SUBSCRIPTION}

# Replace these with your own values as needed
export RESOURCE_GROUP_NAME="myResourceGroup"
export LOCATION="eastus"
export VNET_NAME="myVnet"
export SUBNET_NAME="mySubnet"
export NSG_NAME="myNSG"
export PUBLIC_IP_NAME="myPublicIP"
export NIC_NAME="myNic"

# Create a Virtual Network
az network vnet create --resource-group ${RESOURCE_GROUP_NAME} --location ${LOCATION} --name ${VNET_NAME} --address-prefix 10.0.0.0/16

# Create a Subnet
az network vnet subnet create --resource-group ${RESOURCE_GROUP_NAME} --vnet-name ${VNET_NAME} --name ${SUBNET_NAME} --address-prefixes 10.0.0.0/24

# Create a Network Security Group
az network nsg create --resource-group ${RESOURCE_GROUP_NAME} --name ${NSG_NAME}

# Create a Security Rule allowing TCP traffic over port 80
az network nsg rule create --resource-group ${RESOURCE_GROUP_NAME} --nsg-name ${NSG_NAME} --name Allow-80 --protocol Tcp --direction Inbound --priority 1000 --source-address-prefix '*' --source-port-range '*' --destination-address-prefix '*' --destination-port-range 80 --access Allow

# Associate the Network Security Group with the Subnet
az network vnet subnet update --resource-group ${RESOURCE_GROUP_NAME} --vnet-name ${VNET_NAME} --name ${SUBNET_NAME} --network-security-group ${NSG_NAME}

# Create a Public IP address
az network public-ip create --resource-group ${RESOURCE_GROUP_NAME} --name ${PUBLIC_IP_NAME} --sku Standard --allocation-method Static

# Create a Network Interface with the Public IP address
az network nic create --resource-group ${RESOURCE_GROUP_NAME} --name ${NIC_NAME} --vnet-name ${VNET_NAME} --subnet ${SUBNET_NAME} --network-security-group ${NSG_NAME} --public-ip-address ${PUBLIC_IP_NAME}

export INSTANCE_NAME=anjuna-azure-nginx-instance
anjuna-azure-cli instance create \
  --name ${INSTANCE_NAME} \
  --location eastus \
  --image-gallery myGallery \
  --image-definition myFirstDefinition \
  --image-version 0.1.0 \
  --resource-group myResourceGroup \
  --storage-account ${STORAGE_ACCOUNT_NAME} \
  --attach-data-disks MachineLogging
  --nics myNic

anjuna-azure-cli instance describe \
  --name ${INSTANCE_NAME} \
  --resource-group myResourceGroup