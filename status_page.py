from flask import Flask, render_template
from flask_socketio import SocketIO
from threading import Event
import time
import numpy as np

app = Flask(__name__)
socketio = SocketIO(app, async_mode="eventlet")

# Shared variables for metrics
write_times = []
read_times = []
stop_event = Event()

def simulate_metrics():
    """
    Simulate reading and writing operations and update metrics.
    """
    global write_times, read_times

    while not stop_event.is_set():
        # Simulate write
        start_time = time.time()
        time.sleep(0.001)  # Simulate write delay
        write_time = (time.time() - start_time) * 1000
        write_times.append(write_time)
        if len(write_times) > 1000:
            write_times.pop(0)

        # Simulate read
        start_time = time.time()
        time.sleep(0.002)  # Simulate read delay
        read_time = (time.time() - start_time) * 1000
        read_times.append(read_time)
        if len(read_times) > 1000:
            read_times.pop(0)

        # Calculate metrics
        metrics = {
            "write_time": f"{write_time:.2f} ms",
            "write_avg": f"{np.mean(write_times):.2f} ms",
            "write_95th": f"{np.percentile(write_times, 95):.2f} ms",
            "read_time": f"{read_time:.2f} ms",
            "read_avg": f"{np.mean(read_times):.2f} ms",
            "read_95th": f"{np.percentile(read_times, 95):.2f} ms"
        }

        # Emit metrics to all clients
        socketio.emit("update_stats", metrics)
        socketio.sleep(0.1)

@app.route("/")
def index():
    """
    Serve the index page.
    """
    return render_template("index.html")

@socketio.on("connect")
def handle_connect():
    """
    Start metrics simulation when a client connects.
    """
    app.logger.info("Client connected")
    socketio.start_background_task(simulate_metrics)

@socketio.on("disconnect")
def handle_disconnect():
    """
    Stop metrics simulation when a client disconnects.
    """
    app.logger.info("Client disconnected")
    stop_event.set()

if __name__ == "__main__":
    socketio.run(app, host="0.0.0.0", port=5000, debug=True)