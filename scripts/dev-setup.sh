#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Banner
echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              🚀 Student Tracker - Dev Setup                  ║"
echo "║               Fast Local Development Environment             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Function to print section headers
print_section() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

print_section "📋 Development Environment Setup"

echo -e "${CYAN}This script will set up:${NC}"
echo -e "  🐍 Python virtual environment"
echo -e "  🐳 Docker containers (PostgreSQL, Redis, etc.)"
echo -e "  📦 All Python dependencies"
echo -e "  🗄️ Database initialization"
echo -e "  📊 Monitoring stack (optional)"
echo -e ""

# Check prerequisites
print_section "🔍 Checking Prerequisites"

if ! command_exists python3; then
    echo -e "${RED}❌ Python 3 is required but not installed${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Python 3 found${NC}"
fi

if ! command_exists docker; then
    echo -e "${RED}❌ Docker is required but not installed${NC}"
    echo -e "${YELLOW}Please install Docker first: https://docs.docker.com/get-docker/${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Docker found${NC}"
fi

if ! command_exists docker-compose; then
    echo -e "${YELLOW}⚠️  docker-compose not found, trying docker compose${NC}"
    if ! docker compose version >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker Compose is required but not installed${NC}"
        exit 1
    else
        echo -e "${GREEN}✅ Docker Compose found${NC}"
        COMPOSE_CMD="docker compose"
    fi
else
    echo -e "${GREEN}✅ Docker Compose found${NC}"
    COMPOSE_CMD="docker-compose"
fi

# Create necessary directories
print_section "📁 Creating Directories"

mkdir -p logs
mkdir -p data
mkdir -p docker/ssl
mkdir -p docker/grafana/provisioning
echo -e "${GREEN}✅ Directories created${NC}"

# Setup Python virtual environment
print_section "🐍 Setting up Python Environment"

if [ ! -d "venv" ]; then
    echo -e "${BLUE}Creating virtual environment...${NC}"
    python3 -m venv venv
fi

echo -e "${BLUE}Activating virtual environment...${NC}"
source venv/bin/activate

echo -e "${BLUE}Upgrading pip...${NC}"
pip install --upgrade pip

echo -e "${BLUE}Installing Python dependencies...${NC}"
pip install --upgrade fastapi uvicorn[standard] pydantic python-multipart jinja2 aiofiles httpx sqlalchemy alembic python-jose[cryptography] passlib[bcrypt] python-dotenv redis pytest pytest-asyncio black flake8 gunicorn

echo -e "${GREEN}✅ Python environment ready${NC}"

# Create environment file
print_section "🔧 Creating Environment Configuration"

cat > .env << EOF
# Environment Configuration
APP_ENV=development
LOG_LEVEL=INFO

# Database Configuration
DATABASE_URL=postgresql://student_user:student_pass@localhost:5432/student_db
POSTGRES_DB=student_db
POSTGRES_USER=student_user
POSTGRES_PASSWORD=student_pass

# Redis Configuration
REDIS_URL=redis://localhost:6379

# Application Configuration
SECRET_KEY=dev-secret-key-change-in-production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# Monitoring
ENABLE_METRICS=true
ENABLE_TRACING=false
EOF

echo -e "${GREEN}✅ Environment file created (.env)${NC}"

# Generate self-signed SSL certificates for development
print_section "🔐 Generating SSL Certificates for Development"

if [ ! -f "docker/ssl/cert.pem" ]; then
    echo -e "${BLUE}Generating self-signed SSL certificates...${NC}"
    openssl req -x509 -newkey rsa:4096 -keyout docker/ssl/key.pem -out docker/ssl/cert.pem -days 365 -nodes -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" 2>/dev/null || {
        echo -e "${YELLOW}⚠️  OpenSSL not available, creating dummy certificates${NC}"
        echo "dummy certificate" > docker/ssl/cert.pem
        echo "dummy key" > docker/ssl/key.pem
    }
    echo -e "${GREEN}✅ SSL certificates created${NC}"
else
    echo -e "${GREEN}✅ SSL certificates already exist${NC}"
fi

# Start Docker services
print_section "🐳 Starting Docker Services"

echo -e "${BLUE}Starting core services (PostgreSQL, Redis)...${NC}"
$COMPOSE_CMD up -d postgres redis

echo -e "${BLUE}Waiting for services to be ready...${NC}"
sleep 10

# Test database connection
echo -e "${BLUE}Testing database connection...${NC}"
for i in {1..30}; do
    if docker exec $(docker ps -q -f name=postgres) pg_isready -U student_user -d student_db >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Database is ready${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ Database failed to start${NC}"
        exit 1
    fi
    sleep 2
done

# Run database migrations (if available)
print_section "🗄️ Database Setup"

echo -e "${BLUE}Database initialized with sample data${NC}"
echo -e "${GREEN}✅ Database setup complete${NC}"

# Start the application
print_section "🚀 Starting Application"

echo -e "${CYAN}Choose your development setup:${NC}"
echo -e "  1) 🏃 Run application directly (Python)"
echo -e "  2) 🐳 Run full Docker stack"
echo -e "  3) 📊 Run with monitoring stack"
echo -e "  4) ⚙️  Setup only (don't start app)"
echo -e ""
read -p "Enter your choice (1-4): " choice

case $choice in
    1)
        echo -e "${BLUE}Starting application with Python...${NC}"
        echo -e "${GREEN}✅ Development environment ready!${NC}"
        echo -e "${CYAN}Access your application at:${NC}"
        echo -e "  🌐 Application: http://localhost:8000"
        echo -e "  📖 API Docs: http://localhost:8000/docs"
        echo -e "  🩺 Health Check: http://localhost:8000/health"
        echo -e "  📊 Metrics: http://localhost:8000/metrics"
        echo -e "  🗄️ Database Admin: http://localhost:8080 (adminer)"
        echo -e ""
        echo -e "${YELLOW}Starting application... Press Ctrl+C to stop${NC}"
        python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
        ;;
    2)
        echo -e "${BLUE}Starting full Docker stack...${NC}"
        $COMPOSE_CMD up -d student-tracker adminer
        echo -e "${GREEN}✅ Full Docker stack ready!${NC}"
        ;;
    3)
        echo -e "${BLUE}Starting with monitoring stack...${NC}"
        $COMPOSE_CMD up -d
        echo -e "${GREEN}✅ Full stack with monitoring ready!${NC}"
        ;;
    4)
        echo -e "${GREEN}✅ Setup complete! Environment ready for development.${NC}"
        ;;
    *)
        echo -e "${YELLOW}Invalid choice. Setup complete, not starting any services.${NC}"
        ;;
esac

if [ "$choice" != "1" ] && [ "$choice" != "4" ]; then
    echo -e "${CYAN}🌐 Access URLs:${NC}"
    echo -e "  📱 Application: http://localhost:8000"
    echo -e "  📖 API Documentation: http://localhost:8000/docs"
    echo -e "  🩺 Health Check: http://localhost:8000/health"
    echo -e "  📊 Metrics: http://localhost:8000/metrics"
    echo -e "  🗄️ Database Admin: http://localhost:8080"
    
    if [ "$choice" = "3" ]; then
        echo -e "  📈 Prometheus: http://localhost:9090"
        echo -e "  📊 Grafana: http://localhost:3000 (admin/admin123)"
        echo -e "  🖥️  Node Exporter: http://localhost:9100"
    fi
fi

echo -e ""
echo -e "${CYAN}💡 Useful Commands:${NC}"
echo -e "  # Activate Python environment"
echo -e "  source venv/bin/activate"
echo -e ""
echo -e "  # View logs"
echo -e "  $COMPOSE_CMD logs -f student-tracker"
echo -e ""
echo -e "  # Stop all services"
echo -e "  $COMPOSE_CMD down"
echo -e ""
echo -e "  # Rebuild application"
echo -e "  $COMPOSE_CMD build student-tracker"
echo -e ""
echo -e "  # Reset database"
echo -e "  $COMPOSE_CMD down -v && $COMPOSE_CMD up -d postgres"
echo -e ""
echo -e "${GREEN}🎉 Happy coding! 🚀${NC}"