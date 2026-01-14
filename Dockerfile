FROM ubuntu:22.04

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
ENV RENDER_URL="https://ping-dockerfile.onrender.com"

# Install advanced dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    tzdata \
    netcat-openbsd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for security
RUN useradd -m -u 1000 appuser
WORKDIR /home/appuser

# Create all scripts as root first, then change ownership
COPY <<'EOF' /home/appuser/monitor1.sh
#!/bin/bash
echo "=== Main Monitor Started ==="
while true; do
    START_TIME=$(date +%s)
    TIMESTAMP=$(date +%s%N | cut -b1-13)
    
    # Check 1: thriiievents.com
    curl -Is --max-time 10 https://thriiievents.com >/dev/null 2>&1 &&
        echo "[OK-1] $(date): thriiievents.com" ||
        echo "[ERROR-1] $(date): thriiievents.com"
    
    # Check 2: securechat.online
    curl -Is --max-time 10 https://www.securechat.online >/dev/null 2>&1 &&
        echo "[OK-1] $(date): securechat.online" ||
        echo "[ERROR-1] $(date): securechat.online"
    
    # Check 3: ping-dockerfile.onrender.com
    curl -Is --max-time 10 https://ping-dockerfile.onrender.com >/dev/null 2>&1 &&
        echo "[OK-1] $(date): ping-dockerfile.onrender.com" ||
        echo "[ERROR-1] $(date): ping-dockerfile.onrender.com"
    
    # Check 4: Socket.IO endpoint
    curl -Is --max-time 10 "https://securechat.online/socket.io/?EIO=4&transport=polling&t=w3n1gh6z$TIMESTAMP" \
        -H "Host: securechat.online" \
        -H "User-Agent: Mozilla/5.0" \
        -H "Accept: */*" >/dev/null 2>&1 &&
        echo "[OK-1] $(date): Socket.IO" ||
        echo "[ERROR-1] $(date): Socket.IO"
    
    ELAPSED=$(( $(date +%s) - START_TIME ))
    [ $ELAPSED -lt 15 ] && sleep $((15 - ELAPSED))
done
EOF

COPY <<'EOF' /home/appuser/pinger.sh
#!/bin/bash
echo "=== Self-Pinger Started ==="
while true; do
    # Ping our own Render URL every 30 seconds
    echo "[SELF-PING] $(date): Pinging $RENDER_URL"
    curl -s --max-time 10 "$RENDER_URL" >/dev/null 2>&1 || true
    
    # Also ping via different methods for redundancy
    curl -s --max-time 5 "https://httpbin.org/get" >/dev/null 2>&1 || true
    curl -s --max-time 5 "https://google.com" >/dev/null 2>&1 || true
    
    echo "[SELF-PING] $(date): Completed"
    sleep 30
done
EOF

COPY <<'EOF' /home/appuser/monitor2.sh
#!/bin/bash
echo "=== Backup Monitor Started ==="
sleep 7  # Offset from main monitor
while true; do
    # Check all endpoints with different timeout
    curl -Is --max-time 8 https://thriiievents.com >/dev/null 2>&1 &&
        echo "[OK-2] $(date): thriiievents.com" ||
        echo "[ERROR-2] $(date): thriiievents.com"
    
    curl -Is --max-time 8 https://ping-dockerfile.onrender.com >/dev/null 2>&1 &&
        echo "[OK-2] $(date): ping-dockerfile.onrender.com" ||
        echo "[ERROR-2] $(date): ping-dockerfile.onrender.com"
    
    sleep 15
done
EOF

COPY <<'EOF' /home/appuser/health.sh
#!/bin/bash
echo "=== Health Server Started on port \${PORT:-8080} ==="
HEALTH_PORT=\${PORT:-8080}
while true; do
    echo -e "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"status\":\"running\",\"timestamp\":\"\$(date)\"}" |
    nc -l -p "\$HEALTH_PORT" -q 1 -s 0.0.0.0
done
EOF

# Main startup script
COPY <<'EOF' /home/appuser/start.sh
#!/bin/bash
echo "======================================="
echo "ULTIMATE 24/7 MONITOR STARTING"
echo "Start Time: $(date)"
echo "Render URL: $RENDER_URL"
echo "======================================="

# Start all services in background
echo "Starting Health Server..."
/home/appuser/health.sh &

echo "Starting Main Monitor..."
/home/appuser/monitor1.sh &

echo "Starting Self-Pinger..."
/home/appuser/pinger.sh &

echo "Starting Backup Monitor..."
/home/appuser/monitor2.sh &

echo "All systems started! Monitoring 24/7..."
echo "======================================="

# Keep container running
while true; do
    echo "[HEARTBEAT] $(date): Monitor is running"
    sleep 60
done
EOF

# Set permissions and ownership
RUN chmod +x /home/appuser/*.sh && chown -R appuser:appuser /home/appuser

# Switch to non-root user
USER appuser

# Run the startup script
CMD ["/home/appuser/start.sh"]
