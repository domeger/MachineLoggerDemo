from opentelemetry import metrics
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.resources import Resource
import psutil
import time
import subprocess
import json

# Configure the OpenTelemetry meter
resource = Resource.create({
    "service.name": "disk-monitor",
    "service.version": "1.0",
    "deployment.environment": "production"
})

reader = PeriodicExportingMetricReader(
    OTLPMetricExporter(endpoint="http://localhost:4317")
)
provider = MeterProvider(resource=resource, metric_readers=[reader])
metrics.set_meter_provider(provider)
meter = metrics.get_meter("disk.metrics")

# Create instruments for standard disk metrics
disk_io_read = meter.create_counter(
    name="disk.read.bytes",
    description="Number of bytes read from disk",
    unit="bytes"
)

disk_io_write = meter.create_counter(
    name="disk.write.bytes",
    description="Number of bytes written to disk",
    unit="bytes"
)

disk_usage = meter.create_gauge(
    name="disk.usage",
    description="Disk usage percentage",
    unit="percent"
)

# Create LUKS-specific metrics
luks_status = meter.create_gauge(
    name="luks.device.status",
    description="LUKS device status (1=active, 0=inactive)",
    unit="1"
)

luks_io_operations = meter.create_counter(
    name="luks.io.operations",
    description="Number of I/O operations on LUKS device",
    unit="1"
)

def get_luks_status():
    try:
        result = subprocess.run(['cryptsetup', 'status', 'luks-device'], 
                              capture_output=True, text=True)
        return 1 if result.returncode == 0 else 0
    except Exception:
        return 0

def get_luks_device_stats():
    try:
        with open('/proc/diskstats', 'r') as f:
            for line in f:
                if 'dm-' in line and 'luks-device' in line:
                    fields = line.strip().split()
                    return {
                        'reads': int(fields[3]),
                        'writes': int(fields[7])
                    }
    except Exception:
        return {'reads': 0, 'writes': 0}

def collect_metrics():
    # Get disk I/O statistics
    disk_io = psutil.disk_io_counters(perdisk=True)
    
    # Get disk usage statistics
    disk_partitions = psutil.disk_partitions()
    
    # Standard disk metrics
    for disk_name, stats in disk_io.items():
        disk_io_read.add(
            stats.read_bytes,
            {"device": disk_name}
        )
        disk_io_write.add(
            stats.write_bytes,
            {"device": disk_name}
        )
    
    # Disk usage metrics
    for partition in disk_partitions:
        try:
            usage = psutil.disk_usage(partition.mountpoint)
            disk_usage.set(
                usage.percent,
                {
                    "device": partition.device,
                    "mountpoint": partition.mountpoint,
                    "filesystem": partition.fstype
                }
            )
        except PermissionError:
            continue
    
    # LUKS-specific metrics
    luks_status.set(get_luks_status())
    
    luks_stats = get_luks_device_stats()
    luks_io_operations.add(
        luks_stats['reads'] + luks_stats['writes'],
        {"type": "total"}
    )

def main():
    while True:
        try:
            collect_metrics()
        except Exception as e:
            print(f"Error collecting metrics: {e}")
        time.sleep(15)  # Collect every 15 seconds

if __name__ == "__main__":
    main()