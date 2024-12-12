#!/bin/bash

# Function to log messages with timestamps
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Start OpenTelemetry collector in the background
log_message "Starting OpenTelemetry collector..."
otelcol --config /etc/otelcol/config.yaml &

# Start the disk monitoring script in the background
log_message "Starting disk monitoring..."
python3 disk_monitor.py &

# LUKS Setup
# Ensure the directory for the encrypted file exists
if [ ! -d "/mnt/encrypted" ]; then
    log_message "Creating /mnt/encrypted directory..."
    mkdir -p /mnt/encrypted
fi

# Mount tmpfs for LUKS
log_message "Setting up encrypted tmpfs..."
mount -t tmpfs tmpfs /mnt/encrypted || { log_message "Failed to mount tmpfs"; exit 1; }

# Create a file for the encrypted image if it doesn't already exist
if [ ! -f "/mnt/encrypted/encrypted.img" ]; then
    log_message "Creating encrypted.img..."
    dd if=/dev/zero of=/mnt/encrypted/encrypted.img bs=1M count=90 || { log_message "Failed to create encrypted.img"; exit 1; }
fi

# Check if /mnt/encrypted/encrypted.img is already associated with a loop device
EXISTING_LOOP=$(losetup -j /mnt/encrypted/encrypted.img | cut -d ':' -f 1)
if [ -n "$EXISTING_LOOP" ]; then
    log_message "Releasing existing loop device: $EXISTING_LOOP"
    losetup -d "$EXISTING_LOOP" || { log_message "Failed to release loop device"; exit 1; }
fi

# Dynamically allocate a loop device
LOOP_DEVICE=$(losetup -f)
log_message "Attempting to set up loop device: $LOOP_DEVICE"
losetup "$LOOP_DEVICE" /mnt/encrypted/encrypted.img || { log_message "Failed to set up loop device"; exit 1; }

# Save the passphrase to a temporary key file
echo "$LUKS_PASSPHRASE" > /tmp/luks-keyfile

# Check if the LUKS device is already open and clean it up
if cryptsetup status luks-device >/dev/null 2>&1; then
    log_message "Closing existing LUKS device mapping..."
    cryptsetup luksClose luks-device || {
        log_message "Failed to close existing LUKS device. Retrying..."
        sleep 2
        cryptsetup luksClose luks-device || { log_message "Retry failed. Exiting."; exit 1; }
    }
fi

# Set up LUKS encryption
if ! cryptsetup isLuks "$LOOP_DEVICE"; then
    log_message "Formatting $LOOP_DEVICE with LUKS..."
    cryptsetup luksFormat "$LOOP_DEVICE" --key-file=/tmp/luks-keyfile -q || { log_message "Failed to format LUKS"; exit 1; }
fi

log_message "Opening LUKS device..."
cryptsetup luksOpen "$LOOP_DEVICE" luks-device --key-file=/tmp/luks-keyfile || { log_message "Failed to open LUKS device"; exit 1; }
rm -f /tmp/luks-keyfile

# Create and mount the encrypted file system
if ! mountpoint -q /mnt/encrypted; then
    log_message "Formatting and mounting LUKS device..."
    mkfs.ext4 /dev/mapper/luks-device || { log_message "Failed to format ext4"; exit 1; }
    mount /dev/mapper/luks-device /mnt/encrypted || { log_message "Failed to mount encrypted file system"; exit 1; }
fi

# Run the C application in the background
log_message "Starting the machine logger..."
./machine_logger &

# Start the Flask application
log_message "Starting the Flask app..."
exec python3 status_page.py