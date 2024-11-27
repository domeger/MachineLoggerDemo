#!/bin/bash

# Variables
VAULT_ADDR="http://127.0.0.1:8200"  # Replace with your Vault server address
VAULT_TOKEN="s.yourvaulttoken"      # Replace with your Vault token
SECRET_PATH="secret/data/luks"      # Replace with the path to your secret in Vault
DEVICE="/dev/sdX"                   # Replace with your LUKS device
MAPPER_NAME="luks-volume"
MOUNT_POINT="/mnt/encrypted"

# Export Vault address and token
export VAULT_ADDR
export VAULT_TOKEN

# Retrieve the LUKS passphrase from Vault
echo "Retrieving LUKS passphrase from Vault..."
LUKS_PASSPHRASE=$(vault kv get -field=passphrase "$SECRET_PATH")

# Check if retrieval was successful
if [ -z "$LUKS_PASSPHRASE" ]; then
  echo "Failed to retrieve LUKS passphrase from Vault."
  exit 1
fi

# Create a temporary key file
KEY_FILE=$(mktemp)
echo -n "$LUKS_PASSPHRASE" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

# Check if the LUKS device is already open
if cryptsetup status "$MAPPER_NAME" >/dev/null 2>&1; then
  echo "LUKS device is already open."
else
  # Open the LUKS device
  echo "Opening LUKS device..."
  cryptsetup luksOpen "$DEVICE" "$MAPPER_NAME" --key-file "$KEY_FILE"
  if [ $? -ne 0 ]; then
    echo "Failed to open LUKS device."
    rm -f "$KEY_FILE"
    exit 1
  fi
fi

# Create mount point if it doesn't exist
if [ ! -d "$MOUNT_POINT" ]; then
  echo "Creating mount point at $MOUNT_POINT..."
  mkdir -p "$MOUNT_POINT"
fi

# Mount the unlocked volume
echo "Mounting the unlocked volume..."
mount "/dev/mapper/$MAPPER_NAME" "$MOUNT_POINT"
if [ $? -ne 0 ]; then
  echo "Failed to mount the unlocked volume."
  cryptsetup luksClose "$MAPPER_NAME"
  rm -f "$KEY_FILE"
  exit 1
fi

# Clean up
rm -f "$KEY_FILE"
echo "LUKS volume unlocked and mounted successfully at $MOUNT_POINT."
