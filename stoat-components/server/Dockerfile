# Stoat Server (API) Dockerfile
# Updated: 2026-02-10
FROM rust:1.75-slim as builder

# Install required system dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    cmake \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Clone the backend repository
RUN apt-get update && apt-get install -y git && \
    git clone https://github.com/revoltchat/backend.git . && \
    rm -rf /var/lib/apt/lists/*

# Build the server
RUN cargo build --release --bin revolt-delta

# Runtime image
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy the binary
COPY --from=builder /app/target/release/revolt-delta /usr/local/bin/revolt-delta

# Create app user
RUN useradd -r -s /bin/false revolt

# Switch to app user
USER revolt

EXPOSE 8000

CMD ["revolt-delta"]