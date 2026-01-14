FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    tzdata \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create a simple but effective 24/7 monitor
RUN echo '#!/bin/bash
echo "=== 24/7 Website Monitor Starting ==="
echo "Checking 4 endpoints every 15 seconds"
echo "Self-pinging to stay awake on Render"
echo ""

while true; do
    START_TIME=$(date +%s)
    echo "=== Cycle started at $(date) ==="
    
    # 1. thriiievents.com
    if curl -Is --max-time 10 https://thriiievents.com >/dev/null 2>&1; then
        echo "✓ $(date): thriiievents.com"
    else
        echo "✗ $(date): thriiievents.com"
    fi
    
    # 2. securechat.online
    if curl -Is --max-time 10 https://www.securechat.online >/dev/null 2>&1; then
        echo "✓ $(date): securechat.online"
    else
        echo "✗ $(date): securechat.online"
    fi
    
    # 3. ping-dockerfile.onrender.com
    if curl -Is --max-time 10 https://ping-dockerfile.onrender.com >/dev/null 2>&1; then
        echo "✓ $(date): ping-dockerfile.onrender.com"
    else
        echo "✗ $(date): ping-dockerfile.onrender.com"
    fi
    
    # 4. Socket.IO endpoint (with timestamp)
    TIMESTAMP=$(date +%s%N | cut -b1-13)
    if curl -Is --max-time 10 "https://securechat.online/socket.io/?EIO=4&transport=polling&t=w3n1gh6z$TIMESTAMP" \
        -H "Host: securechat.online" \
        -H "User-Agent: Monitor/1.0" \
        -H "Accept: */*" >/dev/null 2>&1; then
        echo "✓ $(date): Socket.IO endpoint"
    else
        echo "✗ $(date): Socket.IO endpoint"
    fi
    
    # Calculate time taken and adjust sleep
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    
    # Ensure we ping ourselves to stay awake
    echo "=== Self-ping to prevent sleep ==="
    curl -s --max-time 5 "https://ping-dockerfile.onrender.com" >/dev/null 2>&1 || echo "Self-ping failed (normal if just starting)"
    curl -s --max-time 5 "https://google.com" >/dev/null 2>&1 || true
    
    # Sleep to make total cycle 15 seconds
    if [ $ELAPSED -lt 15 ]; then
        SLEEP_TIME=$((15 - ELAPSED))
        echo "Cycle took ${ELAPSED}s, sleeping ${SLEEP_TIME}s"
        sleep $SLEEP_TIME
    else
        echo "Cycle took ${ELAPSED}s (long), continuing immediately"
    fi
    
    echo ""
done' > /monitor.sh && chmod +x /monitor.sh

CMD ["/monitor.sh"]
