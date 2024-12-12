FROM python:3.9-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    libffi-dev \
    python3-dev \
    make \
    cryptsetup \
    util-linux \
    procps \
    curl \
    wget \
    ca-certificates

# Add these lines to your existing Dockerfile
RUN apt-get update && apt-get install -y \
    net-tools \
    procps \
    lsof


# Set the working directory
WORKDIR /app

# Download and install OpenTelemetry Collector
RUN wget https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.91.0/otelcol_0.91.0_linux_amd64.tar.gz \
    && tar -xzf otelcol_0.91.0_linux_amd64.tar.gz \
    && mv otelcol /usr/local/bin/ \
    && chmod +x /usr/local/bin/otelcol \
    && rm otelcol_0.91.0_linux_amd64.tar.gz

# Copy all application files
COPY machine_logger.c .
COPY status_page.py .
COPY disk_monitor.py .
COPY entrypoint.sh .
COPY templates/ ./templates/
COPY otelcol-config.yaml /etc/otelcol/config.yaml

# Make sure the entrypoint script is executable
RUN chmod +x entrypoint.sh

# Compile the C application
RUN gcc -o machine_logger machine_logger.c

# Install Python dependencies
# Install Python dependencies
RUN pip install --no-cache-dir \
    flask \
    flask-socketio \
    numpy \
    eventlet \
    opentelemetry-api \
    opentelemetry-sdk \
    opentelemetry-exporter-prometheus \
    opentelemetry-instrumentation \
    psutil \
    prometheus-client \
    requests \
    && python3 -c "import requests; print('Requests installed successfully:', requests.__version__)"


# Create necessary directories
RUN mkdir -p /mnt/encrypted

EXPOSE 5000 4317 4318 8889

ENTRYPOINT ["./entrypoint.sh"]
