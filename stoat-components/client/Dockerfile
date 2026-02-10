# Stoat Client (Web Frontend) Dockerfile
# Updated: 2026-02-10
FROM node:20-alpine as builder

WORKDIR /app

# Install git
RUN apk add --no-cache git

# Clone the frontend repository
RUN git clone https://github.com/revoltchat/frontend.git .

# Install dependencies
RUN npm ci

# Build the application
RUN npm run build

# Runtime image
FROM nginx:alpine

# Copy built files
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]