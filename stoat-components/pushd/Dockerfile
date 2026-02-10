# Stoat Pushd (Push Notifications) Dockerfile
FROM rust:1.75-slim as builder

# Install required system dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    cmake \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Clone the backend repository (pushd is part of backend)
RUN git clone https://github.com/revoltchat/backend.git .

# Build pushd
RUN cargo build --release --bin revolt-pushd

# Runtime image
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy the binary
COPY --from=builder /app/target/release/revolt-pushd /usr/local/bin/revolt-pushd

# Create app user
RUN useradd -r -s /bin/false revolt

# Switch to app user
USER revolt

CMD ["revolt-pushd"]