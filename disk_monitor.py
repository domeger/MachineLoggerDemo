import socketio
import time
import numpy as np
import psutil
import os
from prometheus_client import start_http_server, Counter, Gauge, Histogram

# Define Prometheus metrics with explicit latency tracking
write_time = Histogram('disk_write_time_seconds', 'Time spent in disk write operations', buckets=(0.001, 0.01, 0.1, 1, 5, 10))
read_time = Histogram('disk_read_time_seconds', 'Time spent in disk read operations', buckets=(0.001, 0.01, 0.1, 1, 5, 10))
write_bytes = Counter('disk_bytes_written_total', 'Number of bytes written to disk')
read_bytes = Counter('disk_bytes_read_total', 'Number of bytes read from disk')
write_errors = Counter('disk_write_errors_total', 'Number of disk write errors')
read_errors = Counter('disk_read_errors_total', 'Number of disk read errors')

# IO Latency specific metrics
write_latency = Histogram('disk_write_latency_seconds', 'Disk write latency', buckets=(0.001, 0.01, 0.1, 1, 5, 10))
read_latency = Histogram('disk_read_latency_seconds', 'Disk read latency', buckets=(0.001, 0.01, 0.1, 1, 5, 10))

def measure_disk_io():
    test_file = '/tmp/disk_io_test.txt'
    
    try:
        # Write test with precise timing
        write_start = time.perf_counter()
        with open(test_file, 'w') as f:
            f.write('x' * 1024 * 1024)  # Write 1MB of data
        write_duration = time.perf_counter() - write_start
        write_size = 1024 * 1024
        
        # Update write metrics
        write_time.observe(write_duration)
        write_latency.observe(write_duration)
        write_bytes.inc(write_size)
        
        # Read test with precise timing
        read_start = time.perf_counter()
        with open(test_file, 'r') as f:
            f.read()
        read_duration = time.perf_counter() - read_start
        read_size = write_size
        
        # Update read metrics
        read_time.observe(read_duration)
        read_latency.observe(read_duration)
        read_bytes.inc(read_size)
        
        # Prepare metrics for Socket.IO
        metrics = {
            'write_time': write_duration * 1000,  # Convert to ms
            'write_avg': write_duration * 1000,
            'write_95th': write_duration * 1000,
            'write_bytes': write_size,
            'read_time': read_duration * 1000,
            'read_avg': read_duration * 1000,
            'read_95th': read_duration * 1000,
            'read_bytes': read_size
        }
        
        # Emit metrics to Flask app
        sio.emit('metrics', metrics)
        print("Metrics generated:", metrics)
    
    except Exception as e:
        write_errors.inc()
        read_errors.inc()
        print(f"Error measuring disk I/O: {e}")
    finally:
        # Clean up test file
        if os.path.exists(test_file):
            os.remove(test_file)
