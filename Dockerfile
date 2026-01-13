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
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for security
RUN useradd -m -u 1000 appuser
USER appuser
WORKDIR /home/appuser

# HEALTHCHECK removed - Not used by Background Workers

# Create and run the monitoring script
RUN echo '#!/bin/bash\n\
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
    sleep 49\n\
done' > /home/appuser/checker.sh && \
    chmod +x /home/appuser/checker.sh

CMD ["/home/appuser/checker.sh"]
