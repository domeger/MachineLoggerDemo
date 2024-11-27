#!/bin/bash

# Variables
DEVICE="/dev/sdX"  # Replace with your LUKS device
MAPPER_NAME="luks-volume"
MOUNT_POINT="/mnt/encrypted"
ENCRYPTED_PASSPHRASE_FILE="/path/to/encrypted_passphrase.b64"  # Replace with the path to your encrypted passphrase file

# Check if the encrypted passphrase file exists
if [ ! -f "$ENCRYPTED_PASSPHRASE_FILE" ]; then
  echo "Encrypted passphrase file not found at $ENCRYPTED_PASSPHRASE_FILE."
  exit 1
fi

# Decrypt the passphrase using AWS KMS
echo "Decrypting LUKS passphrase using AWS KMS..."
LUKS_PASSPHRASE=$(aws kms decrypt --ciphertext-blob fileb://<(base64 --decode < "$ENCRYPTED_PASSPHRASE_FILE") --output text --query Plaintext | base64 --decode)

# Check if decryption was successful
if [ -z "$LUKS_PASSPHRASE" ]; then
  echo "Failed to decrypt LUKS passphrase."
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
