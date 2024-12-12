#!/bin/bash
# MachineLoggerDemo

# Set error handling
set -e

# Set common variables
export ENVIRONMENT="prod"
export PROJECT="machinelogger"
export BASE_RG_NAME="rg-${PROJECT}-${ENVIRONMENT}"
export LOCATION="eastus"

# Azure CLI commands
# First verify Azure CLI is logged in
az account show

# Set subscription ID
export MY_AZURE_SUBSCRIPTION=$(az account show -o json | jq -r .id)

# Create base resource group
az group create --name ${BASE_RG_NAME} --location ${LOCATION}

# Generate random suffix for storage account name
export RANDOM_SUFFIX=$(cat /dev/urandom | LC_ALL=C tr -dc '[:lower:][:digit:]' | head -c 5)
export STORAGE_ACCOUNT_NAME="st${PROJECT}${ENVIRONMENT}${RANDOM_SUFFIX}"

# Create storage account
az storage account create \
    --resource-group ${BASE_RG_NAME} \
    --allow-blob-public-access false \
    --name ${STORAGE_ACCOUNT_NAME}

# Create storage container
az storage container create \
    --name container-${PROJECT} \
    --account-name ${STORAGE_ACCOUNT_NAME} \
    --resource-group ${BASE_RG_NAME}

# Create data disk
az disk create -g ${BASE_RG_NAME} -n disk-${PROJECT}-logging --size-gb 1

# Create shared image gallery
az sig create \
    --resource-group ${BASE_RG_NAME} \
    --gallery-name sig-${PROJECT}

# Create image definition
az sig image-definition create \
    --resource-group ${BASE_RG_NAME} \
    --gallery-name sig-${PROJECT} \
    --gallery-image-definition def-${PROJECT} \
    --publisher Anjuna \
    --offer CVMGA \
    --os-type Linux \
    --sku AnjGALinux \
    --os-state specialized \
    --features SecurityType=ConfidentialVMSupported \
    --hyper-v-generation V2 \
    --architecture x64

# Upload disk to gallery
anjuna-azure-cli disk upload \
    --disk disk.vhd \
    --image-name ${PROJECT}-disk.vhd \
    --storage-account ${STORAGE_ACCOUNT_NAME} \
    --storage-container container-${PROJECT} \
    --resource-group ${BASE_RG_NAME} \
    --image-gallery sig-${PROJECT} \
    --image-definition def-${PROJECT} \
    --image-version 0.1.0 \
    --location ${LOCATION} \
    --subscription-id ${MY_AZURE_SUBSCRIPTION}

# Network configuration
export VNET_NAME="vnet-${PROJECT}-${ENVIRONMENT}"
export SUBNET_NAME="snet-${PROJECT}-${ENVIRONMENT}"
export NSG_NAME="nsg-${PROJECT}-${ENVIRONMENT}"
export PUBLIC_IP_NAME="pip-${PROJECT}-${ENVIRONMENT}"
export NIC_NAME="nic-${PROJECT}-${ENVIRONMENT}"

# Create a Virtual Network
az network vnet create \
    --resource-group ${BASE_RG_NAME} \
    --location ${LOCATION} \
    --name ${VNET_NAME} \
    --address-prefix 10.0.0.0/16

# Create a Subnet
az network vnet subnet create \
    --resource-group ${BASE_RG_NAME} \
    --vnet-name ${VNET_NAME} \
    --name ${SUBNET_NAME} \
    --address-prefixes 10.0.0.0/24

# Create a Network Security Group
az network nsg create \
    --resource-group ${BASE_RG_NAME} \
    --name ${NSG_NAME}

# Create a Security Rule allowing TCP traffic over port 80
az network nsg rule create \
    --resource-group ${BASE_RG_NAME} \
    --nsg-name ${NSG_NAME} \
    --name Allow-HTTP \
    --protocol Tcp \
    --direction Inbound \
    --priority 1000 \
    --source-address-prefix '*' \
    --source-port-range '*' \
    --destination-address-prefix '*' \
    --destination-port-range 80 \
    --access Allow

# Associate the Network Security Group with the Subnet
az network vnet subnet update \
    --resource-group ${BASE_RG_NAME} \
    --vnet-name ${VNET_NAME} \
    --name ${SUBNET_NAME} \
    --network-security-group ${NSG_NAME}

# Create a Public IP address
az network public-ip create \
    --resource-group ${BASE_RG_NAME} \
    --name ${PUBLIC_IP_NAME} \
    --sku Standard \
    --allocation-method Static

# Create a Network Interface with the Public IP address
az network nic create \
    --resource-group ${BASE_RG_NAME} \
    --name ${NIC_NAME} \
    --vnet-name ${VNET_NAME} \
    --subnet ${SUBNET_NAME} \
    --network-security-group ${NSG_NAME} \
    --public-ip-address ${PUBLIC_IP_NAME}

# Create the VM instance
export VM_NAME="vm-${PROJECT}-${ENVIRONMENT}"

anjuna-azure-cli instance create \
    --name ${VM_NAME} \
    --location ${LOCATION} \
    --image-gallery sig-${PROJECT} \
    --image-definition def-${PROJECT} \
    --image-version 0.1.0 \
    --resource-group ${BASE_RG_NAME} \
    --storage-account ${STORAGE_ACCOUNT_NAME} \
    --attach-data-disks disk-${PROJECT}-logging \
    --nics ${NIC_NAME}

# Describe the created instance
anjuna-azure-cli instance describe \
    --name ${VM_NAME} \
    --resource-group ${BASE_RG_NAME}