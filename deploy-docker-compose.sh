#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
TARGET_IP="18.208.149.195"
TARGET_PORT="8011"
APP_NAME="student-tracker"

# Banner
echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║            Student Tracker Docker Deployment                ║"
echo "║              Target Server: ${TARGET_IP}:${TARGET_PORT}                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Docker if not present
install_docker() {
    echo -e "${BLUE}🐳 Installing Docker...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    sudo usermod -aG docker $USER
    sudo systemctl enable docker
    sudo systemctl start docker
    rm get-docker.sh
    echo -e "${GREEN}✅ Docker installed successfully${NC}"
}

# Function to install Docker Compose if not present
install_docker_compose() {
    echo -e "${BLUE}📦 Installing Docker Compose...${NC}"
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}✅ Docker Compose installed successfully${NC}"
}

# Check and install prerequisites
echo -e "${BLUE}🔍 Checking prerequisites...${NC}"

if ! command_exists docker; then
    echo -e "${YELLOW}⚠️  Docker not found. Installing...${NC}"
    install_docker
else
    echo -e "${GREEN}✅ Docker found${NC}"
fi

if ! command_exists docker-compose; then
    echo -e "${YELLOW}⚠️  Docker Compose not found. Installing...${NC}"
    install_docker_compose
else
    echo -e "${GREEN}✅ Docker Compose found${NC}"
fi

echo -e "${GREEN}✅ All prerequisites satisfied${NC}"

# Step 1: Create necessary directories
echo -e "${GREEN}📁 Step 1: Creating necessary directories...${NC}"
mkdir -p logs
mkdir -p docker/ssl
mkdir -p docker/grafana/provisioning

# Step 2: Create SSL certificates (self-signed for development)
echo -e "${GREEN}🔐 Step 2: Creating SSL certificates...${NC}"
if [ ! -f docker/ssl/nginx.crt ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout docker/ssl/nginx.key \
        -out docker/ssl/nginx.crt \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=${TARGET_IP}"
    echo -e "${GREEN}✅ SSL certificates created${NC}"
else
    echo -e "${GREEN}✅ SSL certificates already exist${NC}"
fi

# Step 3: Create Redis configuration
echo -e "${GREEN}🔧 Step 3: Creating Redis configuration...${NC}"
cat > docker/redis.conf << EOF
# Redis configuration for production
bind 0.0.0.0
port 6379
timeout 0
tcp-keepalive 300
daemonize no
supervised no
pidfile /var/run/redis_6379.pid
loglevel notice
logfile ""
databases 16
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir ./
maxmemory 256mb
maxmemory-policy allkeys-lru
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
EOF

# Step 4: Create Nginx configuration
echo -e "${GREEN}🌐 Step 4: Creating Nginx configuration...${NC}"
cat > docker/nginx.conf << EOF
events {
    worker_connections 1024;
}

http {
    upstream student_tracker {
        server student-tracker:8000;
    }

    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone \$binary_remote_addr zone=login:10m rate=1r/s;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    # HTTP server
    server {
        listen 80;
        server_name ${TARGET_IP};
        
        # Redirect HTTP to HTTPS
        return 301 https://\$server_name\$request_uri;
    }

    # HTTPS server
    server {
        listen 443 ssl http2;
        server_name ${TARGET_IP};

        # SSL configuration
        ssl_certificate /etc/nginx/ssl/nginx.crt;
        ssl_certificate_key /etc/nginx/ssl/nginx.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;

        # Security headers
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

        # Rate limiting
        limit_req zone=api burst=20 nodelay;
        limit_req zone=login burst=5 nodelay;

        # Proxy to application
        location / {
            proxy_pass http://student_tracker;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
        }

        # Health check endpoint
        location /health {
            proxy_pass http://student_tracker/health;
            access_log off;
        }

        # API documentation
        location /docs {
            proxy_pass http://student_tracker/docs;
        }

        # Metrics endpoint
        location /metrics {
            proxy_pass http://student_tracker/metrics;
            access_log off;
        }
    }
}
EOF

# Step 5: Create Prometheus configuration
echo -e "${GREEN}📊 Step 5: Creating Prometheus configuration...${NC}"
cat > docker/prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'student-tracker'
    static_configs:
      - targets: ['student-tracker:8000']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'redis'
    static_configs:
      - targets: ['redis:6379']
    metrics_path: '/metrics'
EOF

# Step 6: Create Grafana provisioning
echo -e "${GREEN}📈 Step 6: Creating Grafana provisioning...${NC}"
mkdir -p docker/grafana/provisioning/datasources
mkdir -p docker/grafana/provisioning/dashboards

cat > docker/grafana/provisioning/datasources/prometheus.yml << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF

cat > docker/grafana/provisioning/dashboards/dashboard.yml << EOF
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

# Step 7: Build and deploy with Docker Compose
echo -e "${GREEN}🐳 Step 7: Building and deploying with Docker Compose...${NC}"

# Stop any existing containers
echo -e "${BLUE}Stopping existing containers...${NC}"
docker-compose down --remove-orphans

# Build and start services
echo -e "${BLUE}Building and starting services...${NC}"
docker-compose up -d --build

# Step 8: Wait for services to be ready
echo -e "${GREEN}⏳ Step 8: Waiting for services to be ready...${NC}"

echo -e "${BLUE}Waiting for PostgreSQL...${NC}"
until docker-compose exec -T postgres pg_isready -U student_user -d student_db; do
    echo "Waiting for PostgreSQL..."
    sleep 5
done

echo -e "${BLUE}Waiting for Redis...${NC}"
until docker-compose exec -T redis redis-cli ping; do
    echo "Waiting for Redis..."
    sleep 5
done

echo -e "${BLUE}Waiting for Student Tracker application...${NC}"
until curl -f http://${TARGET_IP}:${TARGET_PORT}/health; do
    echo "Waiting for Student Tracker application..."
    sleep 10
done

# Step 9: Verify deployment
echo -e "${GREEN}✅ Step 9: Verifying deployment...${NC}"

echo -e "${BLUE}Checking container status...${NC}"
docker-compose ps

echo -e "${BLUE}Checking application health...${NC}"
curl -s http://${TARGET_IP}:${TARGET_PORT}/health | jq . || curl -s http://${TARGET_IP}:${TARGET_PORT}/health

# Step 10: Display access information
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo -e "${BLUE}📋 Access Information:${NC}"
echo -e ""
echo -e "${PURPLE}🚀 Student Tracker Application:${NC}"
echo -e "  🌐 HTTP URL: http://${TARGET_IP}:${TARGET_PORT}"
echo -e "  🔒 HTTPS URL: https://${TARGET_IP}:${TARGET_PORT}"
echo -e "  📖 API Documentation: https://${TARGET_IP}:${TARGET_PORT}/docs"
echo -e "  🩺 Health Check: https://${TARGET_IP}:${TARGET_PORT}/health"
echo -e "  📊 Metrics: https://${TARGET_IP}:${TARGET_PORT}/metrics"
echo -e ""
echo -e "${PURPLE}🗄️  Database Management:${NC}"
echo -e "  🌐 Adminer: http://${TARGET_IP}:8080"
echo -e "     🗄️  System: PostgreSQL"
echo -e "     👤 Username: student_user"
echo -e "     🔑 Password: student_pass"
echo -e "     📊 Database: student_db"
echo -e ""
echo -e "${PURPLE}📊 Monitoring:${NC}"
echo -e "  📈 Prometheus: http://${TARGET_IP}:9090"
echo -e "  📊 Grafana: http://${TARGET_IP}:3000"
echo -e "     👤 Username: admin"
echo -e "     🔑 Password: admin123"
echo -e ""
echo -e "${BLUE}🛠️  Management Commands:${NC}"
echo -e "  # View logs"
echo -e "  docker-compose logs -f student-tracker"
echo -e ""
echo -e "  # Restart application"
echo -e "  docker-compose restart student-tracker"
echo -e ""
echo -e "  # Scale application"
echo -e "  docker-compose up -d --scale student-tracker=3"
echo -e ""
echo -e "  # Stop all services"
echo -e "  docker-compose down"
echo -e ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo -e "  1. Configure DNS to point to ${TARGET_IP}"
echo -e "  2. Set up proper SSL certificates"
echo -e "  3. Configure firewall rules"
echo -e "  4. Set up backup strategy"
echo -e "  5. Configure monitoring alerts"
echo -e ""
echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
echo -e "${YELLOW}💡 Access your application at: https://${TARGET_IP}:${TARGET_PORT}${NC}"

# Save deployment info
cat > deployment-info.txt << EOF
Student Tracker Deployment Information
=====================================

Target Server: ${TARGET_IP}:${TARGET_PORT}
Deployment Date: $(date)
Deployment Method: Docker Compose

Access URLs:
- Application: https://${TARGET_IP}:${TARGET_PORT}
- API Docs: https://${TARGET_IP}:${TARGET_PORT}/docs
- Health Check: https://${TARGET_IP}:${TARGET_PORT}/health
- Adminer: http://${TARGET_IP}:8080
- Prometheus: http://${TARGET_IP}:9090
- Grafana: http://${TARGET_IP}:3000

Database Credentials:
- Host: ${TARGET_IP}:5432
- Database: student_db
- Username: student_user
- Password: student_pass

Grafana Credentials:
- Username: admin
- Password: admin123

Management Commands:
- View logs: docker-compose logs -f student-tracker
- Restart: docker-compose restart student-tracker
- Stop all: docker-compose down
- Scale: docker-compose up -d --scale student-tracker=3
EOF

echo -e "${GREEN}💾 Deployment information saved to deployment-info.txt${NC}"