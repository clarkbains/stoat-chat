# Stoat Autumn (File Server) Dockerfile
# Updated: 2026-02-10
FROM rust:1.75-slim as builder

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

# Clone the autumn repository
RUN git clone https://github.com/revoltchat/autumn.git .

# Build autumn
RUN cargo build --release

# Runtime image
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    libmagic1 \
    && rm -rf /var/lib/apt/lists/*

# Copy the binary
COPY --from=builder /app/target/release/autumn /usr/local/bin/autumn

# Create app user
RUN useradd -r -s /bin/false revolt

# Switch to app user
USER revolt

EXPOSE 3000

CMD ["autumn"]