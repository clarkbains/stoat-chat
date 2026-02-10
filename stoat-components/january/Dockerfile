# Stoat January (Metadata and Image Proxy) Dockerfile
# Updated: 2026-02-10
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

# Clone the january repository
RUN git clone https://github.com/revoltchat/january.git .

# Build january
RUN cargo build --release

# Runtime image
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy the binary
COPY --from=builder /app/target/release/january /usr/local/bin/january

# Create app user
RUN useradd -r -s /bin/false revolt

# Switch to app user
USER revolt

EXPOSE 7000

CMD ["january"]