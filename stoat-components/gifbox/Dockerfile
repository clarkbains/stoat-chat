# Stoat Gifbox (Tenor Proxy) Dockerfile
# Updated: 2026-02-10 : 3
FROM rust:1.92.0-slim as builder

# Install required system dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    cmake \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Clone the stoat backend repository
RUN git clone https://github.com/stoatchat/stoatchat.git .

# Build gifbox
RUN cargo build --release --bin revolt-gifbox

# Runtime image
FROM ubuntu:24.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3t64 \
    && rm -rf /var/lib/apt/lists/*

# Copy the binary
COPY --from=builder /app/target/release/revolt-gifbox /usr/local/bin/revolt-gifbox

# Create app user
RUN useradd -r -s /bin/false revolt

# Switch to app user
USER revolt

EXPOSE 14706

CMD ["revolt-gifbox"]