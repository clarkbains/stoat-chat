#!/bin/bash
set -e

# Logging setup
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting Stoat Chat installation..."
echo "Timestamp: $(date)"

# Update system
echo "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install dependencies
echo "Installing dependencies..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    jq

# Install Docker
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
systemctl enable docker
systemctl start docker

# Install Docker Compose
echo "Installing Docker Compose..."
DOCKER_COMPOSE_VERSION="v2.24.5"
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-linux-$(uname -m)" \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Build Caddy with Route53 DNS plugin
echo "Building Caddy with Route53 DNS plugin..."
cat > /tmp/Dockerfile.caddy <<EOF
FROM caddy:builder AS builder
RUN xcaddy build \
    --with github.com/caddy-dns/route53

FROM caddy:latest
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
EOF

docker build -f /tmp/Dockerfile.caddy -t caddy:latest-dns /tmp

# Create Stoat directory
echo "Creating Stoat directory structure..."
mkdir -p /opt/stoat/data/{db,rabbit,minio}

# Write docker-compose.yml
echo "Creating compose.yml..."
cat > /opt/stoat/compose.yml <<'COMPOSE_EOF'
name: stoat

services:
  # MongoDB: Database
  database:
    image: docker.io/mongo
    restart: always
    volumes:
      - ./data/db:/data/db
    healthcheck:
      test: echo 'db.runCommand("ping").ok' | mongosh localhost:27017/test --quiet
      interval: 10s
      timeout: 10s
      retries: 5
      start_period: 10s

  # Redis: Event message broker & KV store
  redis:
    image: docker.io/eqalpha/keydb
    restart: always

  # RabbitMQ: Internal message broker
  rabbit:
    image: docker.io/rabbitmq:4
    restart: always
    environment:
      RABBITMQ_DEFAULT_USER: rabbituser
      RABBITMQ_DEFAULT_PASS: rabbitpass
    volumes:
      - ./data/rabbit:/var/lib/rabbitmq
    healthcheck:
      test: rabbitmq-diagnostics -q ping
      interval: 10s
      timeout: 10s
      retries: 3
      start_period: 20s

  # Caddy: Web server with Route53 DNS plugin
  caddy:
    image: caddy:latest-dns
    restart: always
    env_file: .env.web
    environment:
      AWS_REGION: ${aws_region}
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./data/caddy-data:/data
      - ./data/caddy-config:/config
    depends_on:
      - api
      - web
  # API server
  api:
    image: ghcr.io/revoltchat/server:20250930-2
    depends_on:
      database:
        condition: service_healthy
      redis:
        condition: service_started
      rabbit:
        condition: service_healthy
    volumes:
      - type: bind
        source: ./Revolt.toml
        target: /Revolt.toml
    restart: always

  # Events service
  events:
    image: ghcr.io/revoltchat/bonfire:20250930-2
    depends_on:
      database:
        condition: service_healthy
      redis:
        condition: service_started
    volumes:
      - type: bind
        source: ./Revolt.toml
        target: /Revolt.toml
    restart: always

  # Web App
  web:
    image: ghcr.io/revoltchat/client:master
    restart: always
    env_file: .env.web

  # File server
  autumn:
    image: ghcr.io/revoltchat/autumn:20250930-2
    depends_on:
      database:
        condition: service_healthy
    volumes:
      - type: bind
        source: ./Revolt.toml
        target: /Revolt.toml
    restart: always

  # Metadata and image proxy
  january:
    image: ghcr.io/revoltchat/january:20250930-2
    volumes:
      - type: bind
        source: ./Revolt.toml
        target: /Revolt.toml
    restart: always

  # Tenor proxy
  gifbox:
    image: ghcr.io/revoltchat/gifbox:20250930-2
    volumes:
      - type: bind
        source: ./Revolt.toml
        target: /Revolt.toml
    restart: always

  # Regular task daemon
  crond:
    image: ghcr.io/revoltchat/crond:20250930-2
    depends_on:
      database:
        condition: service_healthy
    volumes:
      - type: bind
        source: ./Revolt.toml
        target: /Revolt.toml
    restart: always

  # Push notification daemon
  pushd:
    image: ghcr.io/revoltchat/pushd:20250930-2
    depends_on:
      database:
        condition: service_healthy
      redis:
        condition: service_started
      rabbit:
        condition: service_healthy
    volumes:
      - type: bind
        source: ./Revolt.toml
        target: /Revolt.toml
    restart: always
COMPOSE_EOF

# Create Caddyfile
echo "Creating Caddyfile..."
cat > /opt/stoat/Caddyfile <<CADDY_EOF
{\$HOSTNAME} {
	tls internal

	route /api* {
		uri strip_prefix /api
		reverse_proxy http://api:14702 {
			header_down Location "^/" "/api/"
		}
	}

	route /ws {
		uri strip_prefix /ws
		reverse_proxy http://events:14703 {
			header_down Location "^/" "/ws/"
		}
	}

	route /autumn* {
		uri strip_prefix /autumn
		reverse_proxy http://autumn:14704 {
			header_down Location "^/" "/autumn/"
		}
	}

	route /january* {
		uri strip_prefix /january
		reverse_proxy http://january:14705 {
			header_down Location "^/" "/january/"
		}
	}

	route /gifbox* {
		uri strip_prefix /gifbox
		reverse_proxy http://gifbox:14706 {
			header_down Location "^/" "/gifbox/"
		}
	}

	reverse_proxy http://web:5000
}
CADDY_EOF

# Create Revolt.toml
echo "Creating Revolt.toml configuration..."
cat > /opt/stoat/Revolt.toml <<REVOLT_EOF
[database]
# MongoDB connection
mongodb = "mongodb://database"

[redis]
# Redis connection
redis = "redis://redis/"

[rabbit]
host = "rabbit"
port = 5672
username = "rabbituser"
password = "rabbitpass"

[hosts]
# Web locations of various services
app = "https://${domain_name}"
api = "https://${domain_name}/api"
events = "wss://${domain_name}/ws"
autumn = "https://${domain_name}/autumn"
january = "https://${domain_name}/january"
voso_legacy = ""
voso_legacy_ws = ""

[api]

[api.registration]
# Whether an invite should be required for registration
invite_only = false

[api.smtp]
# Email server configuration for verification
# Defaults to no email verification (host field is empty)
host = ""
username = ""
password = ""
from_address = "noreply@${domain_name}"

[api.security]
# Security configuration
authifier_shield_key = ""
voso_legacy_token = ""
trust_cloudflare = false
easypwned = ""
tenor_key = ""

[api.security.captcha]
# hCaptcha configuration
hcaptcha_key = ""
hcaptcha_sitekey = ""

[pushd]
# Push notification configuration
production = true
mass_mention_chunk_size = 200

[pushd.vapid]
queue = "notifications.outbound.vapid"
private_key = "$(openssl ecparam -name prime256v1 -genkey | openssl pkcs8 -topk8 -nocrypt | base64 -w 0)"
public_key = "$(openssl ecparam -name prime256v1 -genkey -out /tmp/vapid_private.pem && openssl ec -in /tmp/vapid_private.pem -outform DER | tail --bytes 65 | base64 | tr '/+' '_-' | tr -d '\n' | tr -d '='; rm -f /tmp/vapid_private.pem)"

[files]
# File configuration
encryption_key = "$(openssl rand -base64 32)"
webp_quality = 80.0
blocked_mime_types = []
clamd_host = ""
scan_mime_types = [
    "application/vnd.microsoft.portable-executable",
    "application/vnd.android.package-archive",
    "application/zip",
]

[files.s3]
# S3 configuration for AWS
endpoint = "https://s3.${s3_region}.amazonaws.com"
path_style_buckets = false
region = "${s3_region}"
default_bucket = "${s3_bucket_name}"
# Note: Access keys not needed - using IAM instance profile

[features]
# Feature flags
webhooks_enabled = false
mass_mentions_send_notifications = true
mass_mentions_enabled = true

[features.limits.global]
group_size = 100
message_embeds = 5
message_replies = 5
message_reactions = 20
server_emoji = 100
server_roles = 200
server_channels = 200
new_user_hours = 72
body_limit_size = 20_000_000

[features.limits.default]
outgoing_friend_requests = 10
bots = 5
message_length = 2000
message_attachments = 5
servers = 100
voice_quality = 16000
video = true
video_resolution = [1080, 720]
video_aspect_ratio = [0.3, 2.5]

[features.limits.default.file_upload_size_limit]
attachments = 20_000_000
avatars = 4_000_000
backgrounds = 6_000_000
icons = 2_500_000
banners = 6_000_000
emojis = 500_000

[features.limits.new_user]
outgoing_friend_requests = 5
bots = 2
message_length = 2000
message_attachments = 5
servers = 50
voice_quality = 16000
video = true
video_resolution = [1080, 720]
video_aspect_ratio = [0.3, 2.5]

[features.limits.new_user.file_upload_size_limit]
attachments = 20_000_000
avatars = 4_000_000
backgrounds = 6_000_000
icons = 2_500_000
banners = 6_000_000
emojis = 500_000
REVOLT_EOF

# Create .env.web
echo "Creating .env.web configuration..."
cat > /opt/stoat/.env.web <<ENV_EOF
HOSTNAME=https://${domain_name}
REVOLT_PUBLIC_URL=https://${domain_name}/api
ENV_EOF

# Start services
echo "Starting Stoat Chat services..."
cd /opt/stoat
docker compose up -d

# Wait for services to be healthy
echo "Waiting for services to start..."
sleep 30

# Check service status
echo "Service status:"
docker compose ps

# Setup log rotation for Docker
echo "Configuring Docker log rotation..."
cat > /etc/docker/daemon.json <<LOG_EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
LOG_EOF

# Restart Docker to apply log config
systemctl restart docker

# Wait a bit and restart compose to ensure it picks up the new Docker config
sleep 10
cd /opt/stoat
docker compose up -d

echo "Stoat Chat installation complete!"
echo "Deployment timestamp: $(date)"
echo "Access your Stoat instance at: https://${domain_name}"
echo "Note: SSL certificate generation may take a few minutes on first access."
echo ""
echo "To check logs:"
echo "  cd /opt/stoat"
echo "  docker compose logs -f"
