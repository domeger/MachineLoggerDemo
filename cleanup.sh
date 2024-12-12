#!/bin/bash

# Script to clean up, rebuild, and verify Docker image

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Stop and remove any running containers with the image name
log "Stopping and removing existing containers..."
docker ps -a | grep machine-logger | awk '{print $1}' | xargs -r docker rm -f

# Remove the existing image
log "Removing existing image..."
docker rmi machine-logger || true

# Remove any dangling images
log "Removing dangling images..."
docker image prune -f

# Build a new image
log "Building new Docker image..."
docker build -t machine-logger .

# Verify the image was created
if docker images | grep -q machine-logger; then
    log "Image successfully built"
else
    log "ERROR: Image build failed"
    exit 1
fi

# List running containers to verify no conflicts
log "Checking for any conflicting containers..."
docker ps -a | grep machine-logger

# Optional: Show image details
log "Image details:"
docker images | grep machine-logger

# Suggestion to run the container
log "You can now run the container with:"
echo "docker run -p 5000:5000 -p 9100:9100 machine-logger"
