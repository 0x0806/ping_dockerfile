FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install sudo + ping
RUN apt-get update && \
    apt-get install -y sudo iputils-ping && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user
RUN useradd -m bug && \
    echo "bug ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to non-root user
USER bug

# Use sudo to ping nonstop
CMD ["sudo", "ping", "thriiievents.com"]
