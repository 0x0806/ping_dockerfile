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
    cron \
    python3 \
    python3-pip \
    && pip3 install requests \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for security
RUN useradd -m -u 1000 appuser
USER appuser
WORKDIR /home/appuser

# Create multiple monitoring scripts for redundancy

# Script 1: Main website monitoring
RUN echo '#!/bin/bash
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
done' > /home/appuser/monitor1.sh && chmod +x /home/appuser/monitor1.sh

# Script 2: Continuous self-pinging to keep Render alive
RUN echo '#!/bin/bash
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
done' > /home/appuser/pinger.sh && chmod +x /home/appuser/pinger.sh

# Script 3: Backup monitor with different timing
RUN echo '#!/bin/bash
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
done' > /home/appuser/monitor2.sh && chmod +x /home/appuser/monitor2.sh

# Script 4: Webhook alert system (extensible for notifications)
RUN echo '#!/bin/bash
echo "=== Alert System Started ==="
ERROR_COUNT=0
while true; do
    # Monitor log file for errors
    ERRORS=$(tail -100 /home/appuser/monitor.log 2>/dev/null | grep -c "ERROR")
    
    if [ $ERRORS -gt $ERROR_COUNT ]; then
        echo "[ALERT] $(date): Detected new errors! Total: $ERRORS"
        ERROR_COUNT=$ERRORS
    fi
    
    sleep 60
done' > /home/appuser/alerts.sh && chmod +x /home/appuser/alerts.sh

# Script 5: Health endpoint server (for external monitoring)
RUN echo '#!/bin/bash
echo "=== Health Server Started on port ${PORT:-8080} ==="
HEALTH_PORT=${PORT:-8080}
while true; do
    echo -e "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"status\":\"running\",\"timestamp\":\"$(date)\"}" |
    nc -l -p "$HEALTH_PORT" -q 1 -s 0.0.0.0
done' > /home/appuser/health.sh && chmod +x /home/appuser/health.sh

# Create Python monitor as a separate file to avoid quote issues
RUN echo 'import requests
import time
import sys
from datetime import datetime

URLS = [
    "https://thriiievents.com",
    "https://www.securechat.online",
    "https://ping-dockerfile.onrender.com"
]

SOCKET_IO_HEADERS = {
    "Host": "securechat.online",
    "Sec-Ch-Ua-Platform": "Windows",
    "Accept-Language": "en-US,en;q=0.9",
    "Accept": "*/*",
    "Sec-Ch-Ua": '"Chromium";v="143", "Not A(Brand";v="24"',
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    "Sec-Ch-Ua-Mobile": "?0",
    "Sec-Fetch-Site": "same-origin",
    "Sec-Fetch-Mode": "cors",
    "Sec-Fetch-Dest": "empty",
    "Accept-Encoding": "gzip, deflate, br",
    "Priority": "u=1, i"
}

def check_url(url, headers=None):
    try:
        if headers:
            response = requests.head(url, headers=headers, timeout=10)
        else:
            response = requests.head(url, timeout=10)
        return response.status_code < 500
    except:
        return False

def main():
    print(f"[PY-MONITOR] Started at {datetime.now()}")
    
    while True:
        try:
            timestamp = int(time.time() * 1000)
            
            # Check regular URLs
            for url in URLS:
                status = check_url(url)
                print(f"[PY-{'OK' if status else 'ERROR'}] {datetime.now()}: {url}")
            
            # Check Socket.IO
            socket_url = f"https://securechat.online/socket.io/?EIO=4&transport=polling&t=w3n1gh6z{timestamp}"
            socket_status = check_url(socket_url, SOCKET_IO_HEADERS)
            print(f"[PY-{'OK' if socket_status else 'ERROR'}] {datetime.now()}: Socket.IO")
            
            # Self-ping to keep alive
            try:
                requests.get("https://ping-dockerfile.onrender.com", timeout=5)
                print(f"[PY-SELFPING] {datetime.now()}: Self-ping successful")
            except:
                pass
            
            time.sleep(20)
            
        except Exception as e:
            print(f"[PY-ERROR] {datetime.now()}: {e}")
            time.sleep(5)

if __name__ == "__main__":
    main()' > /home/appuser/monitor.py

# Create cron job for additional pings
RUN echo '#!/bin/bash
# Run every 5 minutes via cron
echo "[CRON] $(date): Running scheduled ping"
curl -s --max-time 10 "https://ping-dockerfile.onrender.com" >/dev/null 2>&1
curl -s --max-time 5 "https://api.ipify.org" >/dev/null 2>&1
echo "[CRON] $(date): Scheduled ping complete"' > /home/appuser/cron-ping.sh && chmod +x /home/appuser/cron-ping.sh

# Setup crontab
RUN echo '*/5 * * * * /home/appuser/cron-ping.sh >> /home/appuser/cron.log 2>&1
* * * * * echo "[HEARTBEAT] $(date): Still alive" >> /home/appuser/heartbeat.log' > /tmp/crontab.txt && \
    crontab /tmp/crontab.txt

# Main startup script that runs everything
RUN echo '#!/bin/bash
# Redirect all output to log file
exec > /home/appuser/monitor.log 2>&1

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

echo "Starting Alert System..."
/home/appuser/alerts.sh &

echo "Starting Python Monitor..."
python3 /home/appuser/monitor.py >> /home/appuser/python.log 2>&1 &

echo "Starting Cron Service..."
sudo service cron start

echo "All systems started! Monitoring 24/7..."
echo "Log file: /home/appuser/monitor.log"
echo "======================================="

# Keep container running and show tail of logs
tail -f /home/appuser/monitor.log /home/appuser/python.log' > /home/appuser/start.sh && chmod +x /home/appuser/start.sh

# Run the ultimate startup script
CMD ["/home/appuser/start.sh"]
