#!/bin/bash

# 📸 Screenshot Generation Script
# This script creates placeholder screenshots for the documentation

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCREENSHOT_DIR="docs/images"
WIDTH=1200
HEIGHT=800

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to create placeholder screenshot
create_placeholder() {
    local filename="$1"
    local title="$2"
    local description="$3"
    
    print_status "Creating placeholder: $filename"
    
    # Create SVG placeholder
    cat > "${SCREENSHOT_DIR}/${filename}.svg" << EOF
<svg width="${WIDTH}" height="${HEIGHT}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#f8f9fa;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#e9ecef;stop-opacity:1" />
    </linearGradient>
  </defs>
  
  <!-- Background -->
  <rect width="100%" height="100%" fill="url(#bg)"/>
  
  <!-- Border -->
  <rect x="10" y="10" width="${WIDTH-20}" height="${HEIGHT-20}" 
        fill="none" stroke="#dee2e6" stroke-width="2" rx="8"/>
  
  <!-- Title -->
  <text x="${WIDTH/2}" y="80" text-anchor="middle" 
        font-family="Arial, sans-serif" font-size="32" font-weight="bold" 
        fill="#495057">${title}</text>
  
  <!-- Description -->
  <text x="${WIDTH/2}" y="120" text-anchor="middle" 
        font-family="Arial, sans-serif" font-size="18" 
        fill="#6c757d">${description}</text>
  
  <!-- Icon -->
  <circle cx="${WIDTH/2}" cy="${HEIGHT/2-50}" r="60" 
          fill="#007bff" opacity="0.1"/>
  <text x="${WIDTH/2}" y="${HEIGHT/2-30}" text-anchor="middle" 
        font-family="Arial, sans-serif" font-size="48" 
        fill="#007bff">📸</text>
  
  <!-- Placeholder text -->
  <text x="${WIDTH/2}" y="${HEIGHT/2+50}" text-anchor="middle" 
        font-family="Arial, sans-serif" font-size="16" 
        fill="#6c757d">Screenshot placeholder</text>
  <text x="${WIDTH/2}" y="${HEIGHT/2+80}" text-anchor="middle" 
        font-family="Arial, sans-serif" font-size="14" 
        fill="#adb5bd">Replace with actual screenshot</text>
  
  <!-- Footer -->
  <text x="${WIDTH/2}" y="${HEIGHT-30}" text-anchor="middle" 
        font-family="Arial, sans-serif" font-size="12" 
        fill="#adb5bd">Generated: $(date '+%Y-%m-%d %H:%M:%S')</text>
</svg>
EOF

    print_success "✅ Created: ${filename}.svg"
}

# Function to create PNG from SVG (if ImageMagick is available)
convert_to_png() {
    local filename="$1"
    
    if command_exists convert; then
        print_info "Converting ${filename}.svg to PNG..."
        convert "${SCREENSHOT_DIR}/${filename}.svg" "${SCREENSHOT_DIR}/${filename}.png"
        print_success "✅ Created: ${filename}.png"
    else
        print_warning "⚠️  ImageMagick not available, keeping SVG format"
    fi
}

# Main function
main() {
    print_status "🚀 Starting screenshot generation..."
    
    # Create screenshot directory
    mkdir -p "${SCREENSHOT_DIR}"
    print_success "✅ Created directory: ${SCREENSHOT_DIR}"
    
    # Define screenshots to create
    declare -A screenshots=(
        # AWS Console Setup
        ["ec2-launch-instance"]="EC2 Launch Instance|Launch a new EC2 instance with Amazon Linux 2"
        ["security-group-setup"]="Security Group Setup|Configure security groups to allow required ports"
        ["key-pair-download"]="Key Pair Download|Download and secure your SSH key pair"
        
        # System Setup
        ["ssh-connection"]="SSH Connection|Connect to EC2 instance using SSH"
        ["system-update"]="System Update|Update system packages and install dependencies"
        ["docker-setup"]="Docker Setup|Install and configure Docker"
        
        # Application Deployment
        ["repo-clone"]="Repository Clone|Clone the Student Tracker repository"
        ["deploy-script"]="Deploy Script|Run the deployment script"
        ["docker-build"]="Docker Build|Build the Docker image"
        
        # Verification and Testing
        ["container-status"]="Container Status|Verify container is running"
        ["health-check"]="Health Check|Test application health endpoint"
        ["application-ui"]="Application UI|Access the Student Tracker web interface"
        
        # Application Screenshots
        ["main-dashboard"]="Main Dashboard|Student Tracker main interface"
        ["student-registration"]="Student Registration|Add new students to the system"
        ["progress-tracking"]="Progress Tracking|Track student progress over time"
        ["api-docs"]="API Docs|Interactive API documentation"
        
        # Success Indicators
        ["deployment-success"]="Deployment Success|All systems operational"
        ["health-status"]="Health Status|Application health metrics"
        ["performance-metrics"]="Performance Metrics|System performance overview"
        
        # Monitoring and Management
        ["system-resources"]="System Resources|Monitor system performance"
        ["docker-logs"]="Docker Logs|View application logs"
        ["network-config"]="Network Config|Verify network connectivity"
        
        # Troubleshooting
        ["error-logs"]="Error Logs|Debug deployment issues"
        ["port-config"]="Port Config|Check port availability"
        ["security-verification"]="Security Verification|Verify security group settings"
    )
    
    # Create all screenshots
    for filename in "${!screenshots[@]}"; do
        IFS='|' read -r title description <<< "${screenshots[$filename]}"
        create_placeholder "$filename" "$title" "$description"
        convert_to_png "$filename"
        echo ""
    done
    
    # Create README for screenshots
    cat > "${SCREENSHOT_DIR}/README.md" << 'EOF'
# 📸 Screenshots Directory

This directory contains placeholder screenshots for the Student Tracker documentation.

## 📋 Screenshot List

### 🖥️ AWS Console Setup
- `ec2-launch-instance.png` - EC2 Launch Instance
- `security-group-setup.png` - Security Group Setup
- `key-pair-download.png` - Key Pair Download

### 🔧 System Setup
- `ssh-connection.png` - SSH Connection
- `system-update.png` - System Update
- `docker-setup.png` - Docker Setup

### 🚀 Application Deployment
- `repo-clone.png` - Repository Clone
- `deploy-script.png` - Deploy Script
- `docker-build.png` - Docker Build

### ✅ Verification and Testing
- `container-status.png` - Container Status
- `health-check.png` - Health Check
- `application-ui.png` - Application UI

### 📱 Application Screenshots
- `main-dashboard.png` - Main Dashboard
- `student-registration.png` - Student Registration
- `progress-tracking.png` - Progress Tracking
- `api-docs.png` - API Docs

### 🎯 Success Indicators
- `deployment-success.png` - Deployment Success
- `health-status.png` - Health Status
- `performance-metrics.png` - Performance Metrics

### 📊 Monitoring and Management
- `system-resources.png` - System Resources
- `docker-logs.png` - Docker Logs
- `network-config.png` - Network Config

### 🔍 Troubleshooting
- `error-logs.png` - Error Logs
- `port-config.png` - Port Config
- `security-verification.png` - Security Verification

## 🔄 Replacing Placeholders

To replace these placeholder screenshots with actual screenshots:

1. **Capture screenshots** during the deployment process
2. **Use the same filenames** as the placeholders
3. **Maintain the same dimensions** (1200x800 pixels recommended)
4. **Update the documentation** to reference the new screenshots

## 🛠️ Tools for Screenshots

### Recommended Tools:
- **Flameshot**: `sudo apt install flameshot` (Linux)
- **Shutter**: `sudo apt install shutter` (Linux)
- **Snipping Tool**: Built-in (Windows)
- **Screenshot**: Built-in (macOS)
- **Browser Extensions**: Various screenshot extensions

### Command Line:
```bash
# Using ImageMagick (if available)
import -window root screenshot.png

# Using scrot (Linux)
scrot screenshot.png

# Using screencapture (macOS)
screencapture screenshot.png
```

## 📝 Notes

- All screenshots are generated as SVG placeholders
- PNG versions are created if ImageMagick is available
- Screenshots should be clear and well-lit
- Include relevant UI elements and context
- Maintain consistent naming conventions
EOF
    
    print_success "✅ Created README: ${SCREENSHOT_DIR}/README.md"
    
    print_status "🎉 Screenshot generation completed!"
    print_info "📁 Screenshots created in: ${SCREENSHOT_DIR}"
    print_info "📝 Total screenshots: ${#screenshots[@]}"
    print_info "🔄 Replace placeholders with actual screenshots when available"
}

# Run main function
main "$@"