FROM python:3.9-slim

# Install system dependencies
RUN apt-get update && apt-get install -y gcc libffi-dev python3-dev make

# Install system and Python dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    libffi-dev \
    python3-dev \
    make \
    cryptsetup \
    util-linux

# Set the working directory
WORKDIR /app

# Copy application code
COPY machine_logger.c .
COPY status_page.py .
COPY entrypoint.sh .
COPY templates/index.html ./templates/

# Compile the C application
RUN gcc -o machine_logger machine_logger.c

# Install Python dependencies
RUN pip install flask flask-socketio numpy eventlet

# Make the entrypoint script executable
RUN chmod +x entrypoint.sh

# Set the entrypoint script
ENTRYPOINT ["./entrypoint.sh"]