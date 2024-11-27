#!/bin/bash

# Variables
DEVICE="/dev/sdX"  # Replace with your device
MAPPER_NAME="luks-volume"
VAULT_ADDR="http://127.0.0.1:8200"  # Replace with your Vault address
VAULT_TOKEN="s.yourvaulttoken"  # Replace with your Vault token
SECRET_PATH="secret/data/luks"  # Replace with your secret path in Vault

# Export Vault address and token
export VAULT_ADDR
export VAULT_TOKEN

# Retrieve the data key from Vault
DATA_KEY=$(vault kv get -field=key "$SECRET_PATH")

# Check if retrieval was successful
if [ -z "$DATA_KEY" ]; then
  echo "Failed to retrieve data key from Vault."
  exit 1
fi

# Create a temporary key file
KEY_FILE=$(mktemp)
echo -n "$DATA_KEY" > "$KEY_FILE"

# Unlock the LUKS volume
cryptsetup luksOpen "$DEVICE" "$MAPPER_NAME" --key-file "$KEY_FILE"

# Check if the volume was unlocked successfully
if [ $? -ne 0 ]; then
  echo "Failed to unlock LUKS volume."
  rm -f "$KEY_FILE"
  exit 1
fi

# Mount the unlocked volume
mount "/dev/mapper/$MAPPER_NAME" /mnt

# Clean up
rm -f "$KEY_FILE"
echo "LUKS volume unlocked and mounted successfully."
