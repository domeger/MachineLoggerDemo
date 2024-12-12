import socketio
from flask import Flask, render_template
from flask_socketio import SocketIO
import time
import json
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST, Counter, Gauge, Histogram
from prometheus_client import start_http_server
import numpy as np
import threading
import socket

app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*")  # Allow all origins

# Define Prometheus metrics
write_time = Histogram('disk_write_time_seconds', 'Time spent in disk write operations', buckets=(1, 5, 10, 30, 60, 120, 300))
read_time = Histogram('disk_read_time_seconds', 'Time spent in disk read operations', buckets=(1, 5, 10, 30, 60, 120, 300))
write_bytes = Counter('disk_bytes_written_total', 'Number of bytes written to disk')
read_bytes = Counter('disk_bytes_read_total', 'Number of bytes read from disk')
write_errors = Counter('disk_write_errors_total', 'Number of disk write errors')
read_errors = Counter('disk_read_errors_total', 'Number of disk read errors')

# Add gauge for current values
current_write_time = Gauge('current_write_time_seconds', 'Current write operation time')
current_read_time = Gauge('current_read_time_seconds', 'Current read operation time')

def find_free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(('', 0))
        s.listen(1)
        port = s.getsockname()[1]
    return port

def start_metrics_server(port):
    try:
        print(f"Starting Prometheus metrics server on port {port}")
        start_http_server(port, addr='0.0.0.0')
    except Exception as e:
        print(f"Error starting metrics server: {e}")

@app.route('/metrics')
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/')
def index():
    return render_template('index.html')

def update_metrics(metrics_data):
    # Update histograms
    write_time.observe(metrics_data['write_time'] / 1000.0)  # Convert ms to seconds
    read_time.observe(metrics_data['read_time'] / 1000.0)
    
    # Update counters
    write_bytes.inc(metrics_data.get('write_bytes', 0))
    read_bytes.inc(metrics_data.get('read_bytes', 0))
    
    # Update current gauges
    current_write_time.set(metrics_data['write_time'] / 1000.0)
    current_read_time.set(metrics_data['read_time'] / 1000.0)

@socketio.on('connect')
def handle_connect():
    print("Client connected!")
    app.logger.info("Client connected. Starting performance monitoring.")

@socketio.on('metrics')
def handle_metrics(data):
    print("Received metrics:", data)
    
    metrics_data = {
        'write_time': data['write_time'],
        'write_avg': np.float64(data['write_avg']),
        'write_95th': np.float64(data['write_95th']),
        'read_time': data['read_time'],
        'read_avg': np.float64(data['read_avg']),
        'read_95th': np.float64(data['read_95th'])
    }
    
    print("Processed metrics:", metrics_data)
    
    app.logger.info(f"Emitting metrics: {metrics_data}")
    update_metrics(metrics_data)
    socketio.emit('metrics_update', metrics_data)

def main():
    # Start Prometheus metrics server
    metrics_port = find_free_port()
    metrics_thread = threading.Thread(
        target=start_metrics_server, 
        args=(metrics_port,), 
        daemon=True
    )
    metrics_thread.start()
    
    # Start Flask app with SocketIO
    print(f"Starting Flask app on 0.0.0.0:5000")
    socketio.run(app, host='0.0.0.0', port=5000, debug=True)

if __name__ == '__main__':
    main()
