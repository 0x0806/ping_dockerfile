FROM ubuntu:22.04

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Install dependencies
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
USER appuser
WORKDIR /home/appuser

# Create the monitoring script with thriiievents.com and self-ping only
RUN echo '#!/bin/bash\n\
# Start a minimal HTTP server on $PORT (if set) in the background\n\
if [ -n "$PORT" ]; then\n\
    echo "Starting health check server on port $PORT..."\n\
    while true; do\n\
        echo -e "HTTP/1.1 200 OK\\r\\n\\r\\nMonitor is running - $(date)" | nc -l -p $PORT -q 1 2>/dev/null || true\n\
        sleep 1\n\
    done &\n\
fi\n\
\n\
echo "=== Website Monitoring Started (15-second intervals) ==="\n\
echo "Monitoring: thriiievents.com only"\n\
echo ""\n\
\n\
while true; do\n\
    START_TIME=$(date +%s)\n\
    echo "=== Checking at $(date) ==="\n\
    \n\
    # 1. thriiievents.com\n\
    if ! curl -Is --max-time 10 https://thriiievents.com >/dev/null 2>&1; then\n\
        echo "[ERROR] thriiievents.com is DOWN"\n\
    else\n\
        echo "[OK] thriiievents.com is UP"\n\
    fi\n\
    \n\
    # 2. SELF-PING to keep Render awake (critical for free tier)\n\
    echo "=== Self-pinging to prevent sleep ==="\n\
    \n\
    # Try to ping own Render URL if environment variable exists\n\
    if [ -n "$RENDER_EXTERNAL_URL" ]; then\n\
        echo "Pinging own Render URL: $RENDER_EXTERNAL_URL"\n\
        curl -s --max-time 5 "$RENDER_EXTERNAL_URL" >/dev/null 2>&1 || echo "Self-ping failed (normal)"\n\
    else\n\
        # Generate network activity with external sites\n\
        echo "Generating network activity..."\n\
        curl -s --max-time 3 "https://httpbin.org/get" >/dev/null 2>&1 || true\n\
        curl -s --max-time 3 "https://api.ipify.org" >/dev/null 2>&1 || true\n\
    fi\n\
    \n\
    echo "Self-ping complete"\n\
    \n\
    # Calculate timing for consistent 15-second intervals\n\
    END_TIME=$(date +%s)\n\
    ELAPSED=$((END_TIME - START_TIME))\n\
    \n\
    # Ensure total cycle is 15 seconds\n\
    if [ $ELAPSED -lt 15 ]; then\n\
        SLEEP_TIME=$((15 - ELAPSED))\n\
        echo "Check completed in ${ELAPSED}s. Sleeping for ${SLEEP_TIME}s..."\n\
        echo "----------------------------------------"\n\
        sleep $SLEEP_TIME\n\
    else\n\
        echo "Check took ${ELAPSED}s (longer than 15s interval)"\n\
        echo "----------------------------------------"\n\
        # If check took longer than 15s, continue immediately\n\
    fi\n\
done' > /home/appuser/checker.sh && \
    chmod +x /home/appuser/checker.sh

# Run the script
CMD ["/home/appuser/checker.sh"]
