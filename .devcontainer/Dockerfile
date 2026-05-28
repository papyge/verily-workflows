FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create user
RUN useradd -m -s /bin/bash user

# Setup directory
RUN mkdir -p /opt/setup && chown user:user /opt/setup

# Copy init script
COPY init.sh /opt/setup/init.sh
RUN chmod +x /opt/setup/init.sh

USER user
WORKDIR /home/user

EXPOSE 8080
