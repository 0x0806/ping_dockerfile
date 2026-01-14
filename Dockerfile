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
    inotify-tools \
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
RUN echo '#!/bin/bash\n\
echo "=== Main Monitor Started ==="\n\
while true; do\n\
    START_TIME=$(date +%s)\n\
    TIMESTAMP=$(date +%s%N | cut -b1-13)\n\
    \n\
    # Check 1: thriiievents.com\n\
    curl -Is --max-time 10 https://thriiievents.com >/dev/null 2>&1 && \\\n\
        echo "[OK-1] $(date): thriiievents.com" || \\\n\
        echo "[ERROR-1] $(date): thriiievents.com"\n\
    \n\
    # Check 2: securechat.online\n\
    curl -Is --max-time 10 https://www.securechat.online >/dev/null 2>&1 && \\\n\
        echo "[OK-1] $(date): securechat.online" || \\\n\
        echo "[ERROR-1] $(date): securechat.online"\n\
    \n\
    # Check 3: Socket.IO endpoint\n\
    curl -Is --max-time 10 "https://securechat.online/socket.io/?EIO=4&transport=polling&t=w3n1gh6z$TIMESTAMP" \\\n\
        -H "Host: securechat.online" \\\n\
        -H "User-Agent: Mozilla/5.0" \\\n\
        -H "Accept: */*" >/dev/null 2>&1 && \\\n\
        echo "[OK-1] $(date): Socket.IO" || \\\n\
        echo "[ERROR-1] $(date): Socket.IO"\n\
    \n\
    ELAPSED=$(( $(date +%s) - START_TIME ))\n\
    [ $ELAPSED -lt 15 ] && sleep $((15 - ELAPSED))\n\
done' > /home/appuser/monitor1.sh && chmod +x /home/appuser/monitor1.sh

# Script 2: Continuous self-pinging to keep Render alive
RUN echo '#!/bin/bash\n\
echo "=== Self-Pinger Started ==="\n\
while true; do\n\
    # Ping our own Render URL every 30 seconds\n\
    echo "[SELF-PING] $(date): Pinging $RENDER_URL"\n\
    curl -s --max-time 10 "$RENDER_URL" >/dev/null 2>&1 || true\n\
    \n\
    # Also ping via different methods for redundancy\n\
    curl -s --max-time 5 "https://httpbin.org/get" >/dev/null 2>&1 || true\n\
    curl -s --max-time 5 "https://google.com" >/dev/null 2>&1 || true\n\
    \n\
    echo "[SELF-PING] $(date): Completed"\n\
    sleep 30\n\
done' > /home/appuser/pinger.sh && chmod +x /home/appuser/pinger.sh

# Script 3: Backup monitor with different timing
RUN echo '#!/bin/bash\n\
echo "=== Backup Monitor Started ==="\n\
sleep 7  # Offset from main monitor\n\
while true; do\n\
    # Check all endpoints with different timeout\n\
    curl -Is --max-time 8 https://thriiievents.com >/dev/null 2>&1 && \\\n\
        echo "[OK-2] $(date): thriiievents.com" || \\\n\
        echo "[ERROR-2] $(date): thriiievents.com"\n\
    \n\
    sleep 15\n\
done' > /home/appuser/monitor2.sh && chmod +x /home/appuser/monitor2.sh

# Script 4: Webhook alert system (extensible for notifications)
RUN echo '#!/bin/bash\n\
echo "=== Alert System Started ==="\n\
ERROR_COUNT=0\n\
while true; do\n\
    # Monitor log file for errors\n\
    ERRORS=$(tail -100 /home/appuser/monitor.log 2>/dev/null | grep -c "ERROR")\n\
    \n\
    if [ $ERRORS -gt $ERROR_COUNT ]; then\n\
        echo "[ALERT] $(date): Detected new errors! Total: $ERRORS"\n\
        ERROR_COUNT=$ERRORS\n\
        \n\
        # Here you can add webhook calls:\n\
        # curl -X POST https://hooks.slack.com/services/...\n\
        # curl -X POST https://discord.com/api/webhooks/...\n\
    fi\n\
    \n\
    sleep 60\n\
done' > /home/appuser/alerts.sh && chmod +x /home/appuser/alerts.sh

# Script 5: Health endpoint server (for external monitoring)
RUN echo '#!/bin/bash\n\
echo "=== Health Server Started on port ${PORT:-8080} ==="\n\
HEALTH_PORT=${PORT:-8080}\n\
while true; do\n\
    echo -e "HTTP/1.1 200 OK\\r\\nContent-Type: application/json\\r\\n\\r\\n{\\"status\\":\\"running\\",\\"timestamp\\":\\"$(date)\\"}" | \\\n\
    nc -l -p "$HEALTH_PORT" -q 1 -s 0.0.0.0\n\
done' > /home/appuser/health.sh && chmod +x /home/appuser/health.sh

# Main startup script that runs everything
RUN echo '#!/bin/bash\n\
# Redirect all output to log file\n\
exec > /home/appuser/monitor.log 2>&1\n\
\n\
echo "======================================="\n\
echo "ULTIMATE 24/7 MONITOR STARTING"\n\
echo "Start Time: $(date)"\n\
echo "Render URL: $RENDER_URL"\n\
echo "======================================="\n\
\n\
# Start all services in background\n\
echo "Starting Health Server..."\n\
/home/appuser/health.sh &\n\
\n\
echo "Starting Main Monitor..."\n\
/home/appuser/monitor1.sh &\n\
\n\
echo "Starting Self-Pinger..."\n\
/home/appuser/pinger.sh &\n\
\n\
echo "Starting Backup Monitor..."\n\
/home/appuser/monitor2.sh &\n\
\n\
echo "Starting Alert System..."\n\
/home/appuser/alerts.sh &\n\
\n\
echo "All systems started! Monitoring 24/7..."\n\
echo "Log file: /home/appuser/monitor.log"\n\
echo "======================================="\n\
\n\
# Keep container running and show tail of logs\n\
tail -f /home/appuser/monitor.log' > /home/appuser/start.sh && chmod +x /home/appuser/start.sh

# Create a Python script for advanced monitoring
RUN echo '#!/usr/bin/env python3\n\
import requests\n\
import time\n\
import sys\n\
from datetime import datetime\n\
\n\
URLS = [\n\
    "https://thriiievents.com",\n\
    "https://www.securechat.online",\n\
    "https://ping-dockerfile.onrender.com"\n\
]\n\
\n\
SOCKET_IO_HEADERS = {\n\
    "Host": "securechat.online",\n\
    "Sec-Ch-Ua-Platform": "Windows",\n\
    "Accept-Language": "en-US,en;q=0.9",\n\
    "Accept": "*/*",\n\
    "Sec-Ch-Ua": \'"Chromium";v="143", "Not A(Brand";v="24"\',\n\
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",\n\
    "Sec-Ch-Ua-Mobile": "?0",\n\
    "Sec-Fetch-Site": "same-origin",\n\
    "Sec-Fetch-Mode": "cors",\n\
    "Sec-Fetch-Dest": "empty",\n\
    "Accept-Encoding": "gzip, deflate, br",\n\
    "Priority": "u=1, i"\n\
}\n\
\n\
def check_url(url, headers=None, name=None):\n\
    try:\n\
        if headers:\n\
            response = requests.head(url, headers=headers, timeout=10)\n\
        else:\n\
            response = requests.head(url, timeout=10)\n\
        return response.status_code < 500\n\
    except:\n\
        return False\n\
\n\
def main():\n\
    print(f"[PY-MONITOR] Started at {datetime.now()}")\n\
    \n\
    while True:\n\
        try:\n\
            timestamp = int(time.time() * 1000)\n\
            \n\
            # Check regular URLs\n\
            for url in URLS:\n\
                status = check_url(url)\n\
                print(f"[PY-{'OK' if status else 'ERROR'}] {datetime.now()}: {url}")\n\
            \n\
            # Check Socket.IO\n\
            socket_url = f"https://securechat.online/socket.io/?EIO=4&transport=polling&t=w3n1gh6z{timestamp}"\n\
            socket_status = check_url(socket_url, SOCKET_IO_HEADERS)\n\
            print(f"[PY-{'OK' if socket_status else 'ERROR'}] {datetime.now()}: Socket.IO")\n\
            \n\
            # Self-ping to keep alive\n\
            try:\n\
                requests.get("https://ping-dockerfile.onrender.com", timeout=5)\n\
                print(f"[PY-SELFPING] {datetime.now()}: Self-ping successful")\n\
            except:\n\
                pass\n\
            \n\
            time.sleep(20)  # Different interval than bash scripts\n\
            \n\
        except Exception as e:\n\
            print(f"[PY-ERROR] {datetime.now()}: {e}")\n\
            time.sleep(5)\n\
\n\
if __name__ == "__main__":\n\
    main()' > /home/appuser/monitor.py && chmod +x /home/appuser/monitor.py

# Create cron job for additional pings
RUN echo '#!/bin/bash\n\
# Run every 5 minutes via cron\n\
echo "[CRON] $(date): Running scheduled ping"\n\
curl -s --max-time 10 "https://ping-dockerfile.onrender.com" >/dev/null 2>&1\n\
curl -s --max-time 5 "https://api.ipify.org" >/dev/null 2>&1\n\
echo "[CRON] $(date): Scheduled ping complete"' > /home/appuser/cron-ping.sh && chmod +x /home/appuser/cron-ping.sh

# Setup crontab
RUN echo '*/5 * * * * /home/appuser/cron-ping.sh >> /home/appuser/cron.log 2>&1\n\
* * * * * echo "[HEARTBEAT] $(date): Still alive" >> /home/appuser/heartbeat.log' > /tmp/crontab.txt && \
    crontab /tmp/crontab.txt

# Run the ultimate startup script
CMD ["/home/appuser/start.sh"]
