#!/bin/bash

# Variables
DEVICE="/dev/sdX"  # Replace with your LUKS device
MAPPER_NAME="luks-volume"
MOUNT_POINT="/mnt/encrypted"
PKCS11_MODULE="/path/to/your/pkcs11/module.so"  # Replace with the path to your HSM's PKCS#11 module
TOKEN_LABEL="YourTokenLabel"  # Replace with your HSM's token label
OBJECT_LABEL="YourObjectLabel"  # Replace with the label of the private key object

# Check if the PKCS#11 module exists
if [ ! -f "$PKCS11_MODULE" ]; then
  echo "PKCS#11 module not found at $PKCS11_MODULE."
  exit 1
fi

# Check if the LUKS device is already open
if cryptsetup status "$MAPPER_NAME" >/dev/null 2>&1; then
  echo "LUKS device is already open."
else
  # Open the LUKS device using the HSM
  echo "Opening LUKS device using HSM..."
  cryptsetup luksOpen "$DEVICE" "$MAPPER_NAME" \
    --key-slot 1 \
    --key-file <(pkcs11-tool --module "$PKCS11_MODULE" --login --token-label "$TOKEN_LABEL" --read-object --type privkey --id "$OBJECT_LABEL")
  if [ $? -ne 0 ]; then
    echo "Failed to open LUKS device."
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
  exit 1
fi

echo "LUKS volume unlocked and mounted successfully at $MOUNT_POINT."
