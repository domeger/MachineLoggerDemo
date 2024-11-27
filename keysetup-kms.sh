#!/bin/bash

# Variables
DEVICE="/dev/sdX"  # Replace with your device
MAPPER_NAME="luks-volume"
ENCRYPTED_KEY_FILE="/etc/luks/encrypted_key.bin"
AWS_REGION="us-east-1"  # Replace with your AWS region
KMS_KEY_ID="alias/your-kms-key"  # Replace with your KMS key alias or ID

# Retrieve the encrypted data key from a secure location
# Ensure that $ENCRYPTED_KEY_FILE contains the base64-encoded encrypted data key

# Decrypt the data key using AWS KMS
DATA_KEY=$(aws kms decrypt \
  --region "$AWS_REGION" \
  --ciphertext-blob fileb://"$ENCRYPTED_KEY_FILE" \
  --query Plaintext \
  --output text | base64 --decode)

# Check if decryption was successful
if [ -z "$DATA_KEY" ]; then
  echo "Failed to decrypt data key."
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
