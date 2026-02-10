# Stoat January (Metadata and Image Proxy) Dockerfile
# Updated: 2026-02-10 : 1
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

# Build january
RUN cargo build --release --bin revolt-january

# Runtime image
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy the binary
COPY --from=builder /app/target/release/revolt-january /usr/local/bin/revolt-january

# Create app user
RUN useradd -r -s /bin/false revolt

# Switch to app user
USER revolt

EXPOSE 14705

CMD ["revolt-january"]