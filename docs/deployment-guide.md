# 🚀 Complete EC2 Deployment Guide

## 📋 Prerequisites

### EC2 Instance Requirements
- **OS**: Amazon Linux 2 or Ubuntu 20.04+
- **Instance Type**: t2.micro (minimum) or t2.small (recommended)
- **Storage**: 8GB minimum
- **Security Groups**: Configure as shown below

### Security Group Configuration

| Type | Protocol | Port Range | Source | Description |
|------|----------|------------|--------|-------------|
| SSH | TCP | 22 | Your IP | SSH Access |
| HTTP | TCP | 80 | 0.0.0.0/0 | HTTP Traffic |
| Custom TCP | TCP | 30011 | 0.0.0.0/0 | Application Port |
| Custom TCP | TCP | 30080 | 0.0.0.0/0 | ArgoCD HTTP |
| Custom TCP | TCP | 30443 | 0.0.0.0/0 | ArgoCD HTTPS |

## 🔧 Step-by-Step EC2 Setup

### Step 1: Launch EC2 Instance

1. **Go to AWS Console** → EC2 → Launch Instance
2. **Choose Amazon Linux 2** AMI
3. **Select Instance Type**: t2.small (recommended)
4. **Configure Security Groups** as shown above
5. **Launch and Download Key Pair**

### Step 2: Connect to EC2

```bash
# Connect using SSH
ssh -i your-key.pem ec2-user@18.206.89.183

# Verify connection
whoami  # Should show: ec2-user
pwd     # Should show: /home/ec2-user
```

### Step 3: System Setup

```bash
# Update system
sudo yum update -y

# Install required packages
sudo yum install -y \
    docker \
    git \
    curl \
    wget \
    unzip \
    python3 \
    python3-pip

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# Logout and login again to apply docker group
exit
# Reconnect: ssh -i your-key.pem ec2-user@18.206.89.183
```

### Step 4: Clone Repository

```bash
# Clone the repository
git clone https://github.com/bonaventuresimeon/NativeSeries.git
cd NativeSeries

# Verify files
ls -la
```

### Step 5: Deploy Application

```bash
# Make deploy script executable
chmod +x deploy.sh

# Run EC2 deployment
./deploy.sh ec2
```

## 🎯 Deployment Verification

### Health Check Commands

```bash
# Check if container is running
sudo docker ps

# Test health endpoint
curl http://18.206.89.183:30011/health

# Test API documentation
curl http://18.206.89.183:30011/docs

# Test students interface
curl http://18.206.89.183:30011/students/

# Check container logs
sudo docker logs -f student-tracker
```

### Expected Output

#### Docker Container Status
```
CONTAINER ID   IMAGE                    COMMAND                  CREATED         STATUS         PORTS                      NAMES
abc123def456   student-tracker:latest   "python app/main.py"     2 minutes ago   Up 2 minutes   0.0.0.0:30011->8000/tcp    student-tracker
```

#### Health Check Response
```json
{
  "status": "healthy",
  "service": "student-tracker",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "version": "1.0.0",
  "uptime_seconds": 3600,
  "request_count": 150,
  "production_url": "http://18.206.89.183:30011",
  "database": "healthy",
  "environment": "production"
}
```

## 🔍 Troubleshooting Guide

### Common Issues and Solutions

#### 1. Docker Not Running
```bash
# Check Docker status
sudo systemctl status docker

# Start Docker if not running
sudo systemctl start docker
sudo systemctl enable docker

# Verify Docker is working
sudo docker info
```

#### 2. Port Already in Use
```bash
# Check what's using port 30011
sudo netstat -tlnp | grep 30011

# Kill process if needed
sudo kill -9 <PID>

# Or stop existing container
sudo docker stop student-tracker
```

#### 3. Container Won't Start
```bash
# Check container logs
sudo docker logs student-tracker

# Check Docker daemon
sudo systemctl status docker

# Restart Docker
sudo systemctl restart docker

# Try running container manually
sudo docker run -d -p 30011:8000 --name student-tracker student-tracker:latest
```

#### 4. Health Check Fails
```bash
# Check if container is running
sudo docker ps

# Check container logs
sudo docker logs student-tracker

# Check if port is exposed
sudo docker port student-tracker

# Test from inside container
sudo docker exec student-tracker curl http://localhost:8000/health
```

#### 5. Permission Issues
```bash
# Fix file permissions
sudo chown -R ec2-user:ec2-user /home/ec2-user/NativeSeries
chmod +x deploy.sh

# Add user to docker group
sudo usermod -aG docker ec2-user
# Logout and login again
```

## 📊 Monitoring and Maintenance

### System Monitoring
```bash
# Monitor system resources
htop

# Monitor Docker
sudo docker stats

# Monitor logs
sudo journalctl -f

# Monitor application logs
sudo docker logs -f student-tracker
```

### Backup and Recovery
```bash
# Backup container
sudo docker commit student-tracker student-tracker-backup

# Save image to file
sudo docker save student-tracker:latest > student-tracker-backup.tar

# Restore from backup
sudo docker load < student-tracker-backup.tar
```

### Updates and Maintenance
```bash
# Update application
cd NativeSeries
git pull origin main
./deploy.sh docker

# Update system packages
sudo yum update -y

# Clean up Docker
sudo docker system prune -f
```

## 🔒 Security Best Practices

### Network Security
- Use security groups to restrict access
- Consider using a VPN for SSH access
- Regularly update security group rules

### Application Security
- Keep system packages updated
- Monitor logs for suspicious activity
- Use HTTPS in production
- Implement proper authentication

### Container Security
- Regularly update base images
- Scan images for vulnerabilities
- Use non-root user in containers
- Limit container capabilities

## 📈 Performance Optimization

### Resource Monitoring
```bash
# Check CPU usage
top

# Check memory usage
free -h

# Check disk usage
df -h

# Check network usage
iftop
```

### Performance Tuning
```bash
# Increase Docker memory limit
sudo docker run -d -p 30011:8000 --memory=1g --name student-tracker student-tracker:latest

# Monitor performance
sudo docker stats student-tracker
```

## 🎉 Success Criteria

Your deployment is successful when:

✅ **Container is running**: `sudo docker ps` shows student-tracker  
✅ **Health check passes**: `curl http://18.206.89.183:30011/health` returns 200  
✅ **All endpoints work**: Health, docs, students, metrics all accessible  
✅ **External access**: Application accessible from internet  
✅ **Logs are clean**: No errors in container logs  
✅ **GitHub Actions pass**: All workflow steps complete successfully  

## 📞 Support

If you encounter issues:

1. **Check logs**: `sudo docker logs student-tracker`
2. **Verify configuration**: Review this guide
3. **Test manually**: Run deployment script step by step
4. **Check GitHub Actions**: Review workflow logs
5. **Contact support**: Create GitHub issue

### Useful Commands Reference
```bash
# Quick health check
curl -f http://18.206.89.183:30011/health || echo "Health check failed"

# Check all endpoints
for endpoint in health docs students metrics; do
    echo "Testing $endpoint..."
    curl -I http://18.206.89.183:30011/$endpoint
done

# Monitor real-time
watch -n 5 'curl -s http://18.206.89.183:30011/health | jq .'
```