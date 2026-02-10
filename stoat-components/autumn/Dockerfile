# Stoat Autumn (File Server) Dockerfile
# Updated: 2026-02-10 : 2
FROM rust:1.92.0-slim as builder

# Install required system dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    cmake \
    build-essential \
    git \
    libmagic-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Clone the stoat backend repository
RUN git clone https://github.com/stoatchat/stoatchat.git .

# Build autumn
RUN cargo build --release --bin revolt-autumn

# Runtime image
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    libmagic1 \
    && rm -rf /var/lib/apt/lists/*

# Copy the binary
COPY --from=builder /app/target/release/revolt-autumn /usr/local/bin/revolt-autumn

# Create app user
RUN useradd -r -s /bin/false revolt

# Switch to app user
USER revolt

EXPOSE 14704

CMD ["revolt-autumn"]