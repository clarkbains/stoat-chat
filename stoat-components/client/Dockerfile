# Stoat Client (Web Frontend) Dockerfile
# Updated: 2026-02-10 : 1
FROM node:20-alpine as builder

WORKDIR /app

# Install git and mise
RUN apk add --no-cache git curl bash python3 make g++

# Install mise
RUN curl https://mise.run | sh
ENV PATH="/root/.local/bin:$PATH"

# Clone the frontend repository
RUN git clone --recursive https://github.com/stoatchat/for-web.git .

# Trust mise configuration files
RUN mise trust

# Install all packages using mise
RUN mise install

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