# Stoat Client (Web Frontend) Dockerfile
# Updated: 2026-02-10 : 2
FROM node:20-slim as builder

WORKDIR /app

# Install required dependencies for building
RUN apt-get update && apt-get install -y \
    git \
    curl \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Install mise
RUN curl https://mise.run | sh
ENV PATH="/root/.local/bin:$PATH"

# Clone the frontend repository
RUN git clone --recursive https://github.com/stoatchat/for-web.git .

# Trust mise configuration files
RUN mise trust

# Install all packages using mise
RUN mise install

# Install Node.js dependencies
RUN mise exec -- pnpm install

# Build dependencies
RUN mise build:deps

# Build for web production
RUN mise build:prod

# Runtime image
FROM nginx:alpine

# Copy built files
COPY --from=builder /app/packages/client/dist /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]