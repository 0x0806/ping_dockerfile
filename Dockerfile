FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

CMD while true; do \
      curl -Is https://thriiievents.com >/dev/null || echo "DOWN"; \
      sleep 2; \
    done
