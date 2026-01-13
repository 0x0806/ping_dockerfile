FROM ubuntu:22.04

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Install dependencies (Added 'netcat-openbsd' for the HTTP server)
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

# Create the monitoring script
RUN echo '#!/bin/bash\n\
# Start a minimal HTTP server on $PORT (if set) in the background\n\
if [ -n "$PORT" ]; then\n\
    echo "Starting health check server on port $PORT..."\n\
    while true; do\n\
        echo -e "HTTP/1.1 200 OK\\r\\n\\r\\nI'\''m a background worker. Monitor is running." | nc -l -p $PORT -q 1\n\
    done &\n\
fi\n\
\n\
echo "=== Website Monitoring Started ==="\n\
\n\
while true; do\n\
    echo "Checking websites at $(date)"\n\
    \n\
    if ! curl -Is --max-time 10 https://thriiievents.com >/dev/null 2>&1; then\n\
        echo "[ERROR] $(date): thriiievents.com is DOWN"\n\
    else\n\
        echo "[OK] $(date): thriiievents.com is UP"\n\
    fi\n\
    \n\
    if ! curl -Is --max-time 10 https://www.securechat.online >/dev/null 2>&1; then\n\
        echo "[ERROR] $(date): securechat.online is DOWN"\n\
    else\n\
        echo "[OK] $(date): securechat.online is UP"\n\
    fi\n\
    \n\
    echo "Waiting 49 seconds..."\n\
    echo "----------------------------------------"\n\
    sleep 49\n\
done' > /home/appuser/checker.sh && \
    chmod +x /home/appuser/checker.sh

# Run the script
CMD ["/home/appuser/checker.sh"]
