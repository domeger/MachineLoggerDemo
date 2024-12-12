FROM python:3.9-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    libffi-dev \
    python3-dev \
    make \
    cryptsetup \
    util-linux \
    curl \
    wget \
    lsb-release \
    gnupg2 \
    apt-transport-https \
    python3-psutil \
    coreutils \
    jq \
    procps

# Install OpenTelemetry Collector
ENV OTEL_VERSION=0.93.0
RUN curl -L -o otelcol.deb https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_VERSION}/otelcol_${OTEL_VERSION}_amd64.deb \
    && dpkg -i otelcol.deb \
    && rm otelcol.deb

# Set the working directory
WORKDIR /app

# Copy application files
COPY machine_logger.c .
COPY status_page.py .
COPY disk_monitor.py .
COPY entrypoint.sh .
COPY templates/index.html ./templates/
COPY otel-collector-config.yaml /etc/otelcol/config.yaml

# Compile the C application
RUN gcc -o machine_logger machine_logger.c

# Install Python dependencies
RUN pip install --no-cache-dir \
    flask \
    flask-socketio \
    numpy \
    eventlet \
    opentelemetry-api \
    opentelemetry-sdk \
    opentelemetry-instrumentation \
    opentelemetry-exporter-otlp \
    psutil \
    prometheus-client

# Create necessary directories
RUN mkdir -p /mnt/encrypted

# Make the entrypoint script executable
RUN chmod +x entrypoint.sh

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV OTEL_RESOURCE_ATTRIBUTES=service.name=machine-logger
ENV OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
ENV OTEL_METRICS_EXPORTER=otlp

# Expose necessary ports
# - 5000: Flask application
# - 4317: OTLP gRPC
# - 4318: OTLP HTTP
# - 8889: Prometheus metrics
EXPOSE 5000 4317 4318 8889

# Need privileged mode for LUKS operations
# Use this container with: docker run --privileged
VOLUME ["/mnt/encrypted"]

ENTRYPOINT ["./entrypoint.sh"]