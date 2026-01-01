# Use official Ubuntu image
FROM ubuntu:22.04

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install ping utility (iputils-ping)
RUN apt-get update && \
    apt-get install -y iputils-ping && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Command to ping the host nonstop
CMD ["ping", "thriiievents.com"]
