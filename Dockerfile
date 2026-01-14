FROM alpine:latest

# Install curl for HTTP requests
RUN apk add --no-cache curl bash

# Create the monitoring script
RUN echo '#!/bin/bash
echo "=== 24/7 Render Monitor Started ==="
echo "Targets: securechat.online (Node.js), thriiievents.com, self-ping"
echo "Interval: 15 seconds"
echo ""

# Counter for tracking
cycle=0

while true; do
    cycle=$((cycle + 1))
    echo "=== Cycle #$cycle - $(date) ==="
    
    # 1. Check securechat.online (Node.js backend)
    echo -n "securechat.online (Node.js): "
    if curl -Is --max-time 10 "https://www.securechat.online" >/dev/null 2>&1; then
        echo "✓ UP"
    else
        # Try alternative check for Node.js app
        echo -n "Trying API endpoint... "
        if curl -s --max-time 10 "https://www.securechat.online" | grep -q "html"; then
            echo "✓ UP (HTML detected)"
        else
            echo "✗ DOWN"
        fi
    fi
    
    # 2. Check thriiievents.com
    echo -n "thriiievents.com: "
    if curl -Is --max-time 10 "https://thriiievents.com" >/dev/null 2>&1; then
        echo "✓ UP"
    else
        echo "✗ DOWN"
    fi
    
    # 3. Check Socket.IO endpoint (Node.js WebSocket)
    echo -n "Socket.IO endpoint: "
    TIMESTAMP=$(date +%s%N | cut -b1-13)
    if curl -Is --max-time 10 "https://securechat.online/socket.io/?EIO=4&transport=polling&t=w3n1gh6z$TIMESTAMP" \
        -H "Host: securechat.online" \
        -H "User-Agent: Render-Monitor/1.0" \
        -H "Accept: */*" >/dev/null 2>&1; then
        echo "✓ UP"
    else
        echo "✗ DOWN (Node.js WebSocket)"
    fi
    
    # 4. SELF-PING - CRITICAL FOR RENDER FREE TIER
    echo "=== Self-pinging to stay awake ==="
    
    # Try to get container URL from Render environment
    if [ -n "$RENDER_EXTERNAL_URL" ]; then
        echo "Pinging: $RENDER_EXTERNAL_URL"
        curl -s --max-time 5 "$RENDER_EXTERNAL_URL" >/dev/null 2>&1 || true
    fi
    
    # Also ping known endpoints to generate network activity
    echo "Generating network activity..."
    curl -s --max-time 3 "https://httpbin.org/status/200" >/dev/null 2>&1 || true
    curl -s --max-time 3 "https://api.ipify.org?format=json" >/dev/null 2>&1 || true
    curl -s --max-time 3 "https://checkip.amazonaws.com" >/dev/null 2>&1 || true
    
    echo "Self-ping complete"
    
    # 5. Additional Node.js specific check
    echo -n "Node.js health check: "
    if curl -s --max-time 10 "https://securechat.online" | head -c 100 | grep -q -E "(html|DOCTYPE|script|div|body)"; then
        echo "✓ Node.js app responding"
    else
        echo "⚠ Node.js response unusual"
    fi
    
    # Calculate timing for consistent 15-second intervals
    END_TIME=$(date +%s)
    START_TIME=$(echo "$(date +%s) - 1" | bc)  # Approximate start time
    
    ELAPSED=$((END_TIME - START_TIME))
    
    if [ $ELAPSED -lt 15 ]; then
        SLEEP_TIME=$((15 - ELAPSED))
        echo "Cycle took ${ELAPSED}s, sleeping ${SLEEP_TIME}s"
        sleep $SLEEP_TIME
    else
        echo "Cycle took ${ELAPSED}s, continuing..."
    fi
    
    echo ""
    
    # Every 10 cycles, do extra pings to ensure Render doesn\'t sleep
    if [ $((cycle % 10)) -eq 0 ]; then
        echo "=== EXTENDED KEEP-ALIVE ACTIVITY ==="
        for i in {1..5}; do
            curl -s --max-time 2 "https://google.com" >/dev/null 2>&1 || true
            sleep 0.5
        done
        echo "Extended keep-alive complete"
        echo ""
    fi
done' > /monitor.sh && chmod +x /monitor.sh

# Create a simple health endpoint if PORT is provided
RUN echo '#!/bin/bash
# Simple HTTP server for Render health checks
if [ -n "$PORT" ]; then
    echo "Starting health endpoint on port $PORT"
    while true; do
        echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nOK - Monitor running at $(date)" | \
        nc -l -p $PORT -q 1 2>/dev/null || true
        sleep 1
    done
fi' > /health.sh && chmod +x /health.sh

# Main entry point that starts both monitor and health server
RUN echo '#!/bin/bash
echo "========================================"
echo "RENDER 24/7 MONITOR"
echo "Start Time: $(date)"
echo "External URL: ${RENDER_EXTERNAL_URL:-Not set}"
echo "PORT: ${PORT:-Not set}"
echo "========================================"

# Start health server in background if PORT is set
if [ -n "$PORT" ]; then
    /health.sh &
    echo "Health endpoint started on port $PORT"
fi

# Start the main monitor (foreground)
exec /monitor.sh' > /start.sh && chmod +x /start.sh

CMD ["/start.sh"]
