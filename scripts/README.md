# Deployment Scripts

This directory contains the main deployment script for the Student Tracker application.

## deploy.sh

A robust deployment script optimized for Amazon Linux and other Linux distributions.

### Features

- **Automatic OS Detection**: Detects Amazon Linux, Ubuntu, and other distributions
- **Tool Installation**: Automatically installs kubectl, helm, docker, argocd, and other tools
- **Project Validation**: Validates project structure and prerequisites
- **Docker Build**: Builds Docker images with proper error handling
- **Kubernetes Deployment**: Deploys to Kubernetes clusters when available
- **Production Deployment**: Handles production deployment preparation
- **Validation Report**: Generates detailed validation reports

### Usage

```bash
# Basic deployment
./scripts/deploy.sh

# With Docker Hub username
DOCKER_USERNAME=yourusername ./scripts/deploy.sh

# With custom production host
PRODUCTION_HOST=your-host-ip ./scripts/deploy.sh
```

### Environment Variables

- `DOCKER_USERNAME`: Your Docker Hub username (for pushing images)
- `PRODUCTION_HOST`: Production server IP (default: 18.206.89.183)
- `PRODUCTION_PORT`: Production server port (default: 30011)

### What the Script Does

1. **Validates Project Structure**: Checks for required files (app/main.py, helm-chart/Chart.yaml, etc.)
2. **Installs Tools**: Automatically installs kubectl, helm, docker, argocd, jq, yq
3. **Sets Up Docker**: Configures Docker access and group membership
4. **Builds Docker Image**: Creates the application Docker image
5. **Deploys to Kubernetes**: If a cluster is available, deploys the application
6. **Prepares Production**: Sets up production deployment configuration
7. **Generates Report**: Creates a detailed validation report

### Output Files

- `deployment_validation_report.txt`: Detailed validation report
- `.docker_image_name`: Contains the built Docker image name

### Troubleshooting

#### Docker Issues
If Docker is not accessible:
```bash
# Add user to docker group
sudo usermod -a -G docker $USER

# Log out and back in, or run:
newgrp docker

# Start Docker daemon
sudo systemctl start docker
```

#### Kubernetes Cluster
To set up a local Kubernetes cluster:
```bash
# Install kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Create cluster
kind create cluster
```

#### Production Deployment
For production deployment:
1. Set `DOCKER_USERNAME` environment variable
2. Ensure production server is accessible
3. Run the script with proper network access

### Amazon Linux Compatibility

The script is specifically optimized for Amazon Linux:
- Uses `yum` package manager for Amazon Linux
- Handles Amazon Linux specific Docker installation
- Provides proper error handling for container environments
- Includes Amazon Linux specific tool installation paths

### Error Handling

The script includes robust error handling:
- Continues execution even if Docker is not available
- Provides clear error messages and recommendations
- Creates validation reports for troubleshooting
- Handles container environments gracefully