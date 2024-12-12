#!/bin/bash

# Function to log messages with timestamps
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Ensure network configuration
log_message "Configuring network..."
ip addr  # Show network interfaces
echo "127.0.0.1 localhost" >> /etc/hosts

# Start OpenTelemetry collector in the background
log_message "Starting OpenTelemetry collector..."
otelcol --config /etc/otelcol/config.yaml &
OTEL_PID=$!
log_message "OpenTelemetry collector started with PID $OTEL_PID"

# Start the disk monitoring script in the background
log_message "Starting disk monitoring..."
python3 disk_monitor.py &
DISK_MONITOR_PID=$!
log_message "Disk monitor started with PID $DISK_MONITOR_PID"

# LUKS Setup
# Ensure the directory for the encrypted file exists
if [ ! -d "/mnt/encrypted" ]; then
    log_message "Creating /mnt/encrypted directory..."
    mkdir -p /mnt/encrypted
fi

# Mount tmpfs for LUKS
log_message "Setting up encrypted tmpfs..."
mount -t tmpfs tmpfs /mnt/encrypted || { 
    log_message "Failed to mount tmpfs"; 
    exit 1; 
}

# Create a file for the encrypted image if it doesn't already exist
if [ ! -f "/mnt/encrypted/encrypted.img" ]; then
    log_message "Creating encrypted.img..."
    dd if=/dev/zero of=/mnt/encrypted/encrypted.img bs=1M count=90 || { 
        log_message "Failed to create encrypted.img"; 
        exit 1; 
    }
fi

# Attempt to find a free loop device with multiple methods
find_loop_device() {
    # Method 1: Standard losetup
    LOOP_DEVICE=$(losetup -f)
    if [ -n "$LOOP_DEVICE" ] && [ -e "$LOOP_DEVICE" ]; then
        echo "$LOOP_DEVICE"
        return 0
    fi

    # Method 2: Manually check loop devices
    for i in {0..255}; do
        POTENTIAL_DEVICE="/dev/loop$i"
        if [ ! -b "$POTENTIAL_DEVICE" ]; then
            log_message "Creating block device $POTENTIAL_DEVICE"
            mknod "$POTENTIAL_DEVICE" b 7 "$i"
        fi
        if ! losetup "$POTENTIAL_DEVICE" >/dev/null 2>&1; then
            echo "$POTENTIAL_DEVICE"
            return 0
        fi
    done

    log_message "No free loop devices found"
    return 1
}

# Find and set up loop device
LOOP_DEVICE=$(find_loop_device)
if [ -z "$LOOP_DEVICE" ]; then
    log_message "Critical: Cannot find a free loop device"
    exit 1
fi

log_message "Attempting to set up loop device: $LOOP_DEVICE"
losetup "$LOOP_DEVICE" /mnt/encrypted/encrypted.img || { 
    log_message "Failed to set up loop device: $LOOP_DEVICE"; 
    exit 1; 
}
log_message "Loop device $LOOP_DEVICE successfully set up"

# Save the passphrase to a temporary key file
echo "$LUKS_PASSPHRASE" > /tmp/luks-keyfile
chmod 600 /tmp/luks-keyfile

# Check if the LUKS device is already open and clean it up
if cryptsetup status luks-device >/dev/null 2>&1; then
    log_message "Closing existing LUKS device mapping..."
    cryptsetup luksClose luks-device || {
        log_message "Failed to close existing LUKS device. Retrying..."
        sleep 2
        cryptsetup luksClose luks-device || { 
            log_message "Retry failed. Exiting."; 
            exit 1; 
        }
    }
fi

# Set up LUKS encryption
if ! cryptsetup isLuks "$LOOP_DEVICE"; then
    log_message "Formatting $LOOP_DEVICE with LUKS..."
    cryptsetup luksFormat "$LOOP_DEVICE" --key-file=/tmp/luks-keyfile -q || { 
        log_message "Failed to format LUKS"; 
        exit 1; 
    }
fi

log_message "Opening LUKS device..."
cryptsetup luksOpen "$LOOP_DEVICE" luks-device --key-file=/tmp/luks-keyfile || { 
    log_message "Failed to open LUKS device"; 
    exit 1; 
}
rm -f /tmp/luks-keyfile

# Create and mount the encrypted file system
if ! mountpoint -q /mnt/encrypted; then
    log_message "Formatting and mounting LUKS device..."
    mkfs.ext4 /dev/mapper/luks-device || { 
        log_message "Failed to format ext4"; 
        exit 1; 
    }
    mount /dev/mapper/luks-device /mnt/encrypted || { 
        log_message "Failed to mount encrypted file system"; 
        exit 1; 
    }
fi

# Run the C application in the background
log_message "Starting the machine logger..."
./machine_logger &
MACHINE_LOGGER_PID=$!
log_message "Machine logger started with PID $MACHINE_LOGGER_PID"

# Start the Flask application
log_message "Starting the Flask app..."
exec python3 status_page.py
