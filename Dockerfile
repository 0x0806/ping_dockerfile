FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install ping
RUN apt-get update && \
    apt-get install -y iputils-ping && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Run ping nonstop
CMD ["ping", "thriiievents.com"]
