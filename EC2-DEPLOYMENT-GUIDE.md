# 🚀 EC2 Deployment Guide for Student Tracker

This guide provides step-by-step instructions for deploying the Student Tracker application on EC2 using `ec2-user` with GitHub Actions automation.

## 📋 Prerequisites

### 1. EC2 Instance Requirements
- **OS**: Amazon Linux 2 or Ubuntu 20.04+
- **Instance Type**: t2.micro (minimum) or t2.small (recommended)
- **Storage**: 8GB minimum
- **Security Groups**: 
  - SSH (Port 22)
  - HTTP (Port 80)
  - Custom TCP (Port 30011) - Application
  - Custom TCP (Port 30080) - ArgoCD HTTP
  - Custom TCP (Port 30443) - ArgoCD HTTPS

### 2. GitHub Repository Setup
- Repository with Student Tracker code
- GitHub Actions enabled
- Repository secrets configured

## 🔧 Step 1: EC2 Instance Setup

### Launch EC2 Instance
```bash
# Connect to your EC2 instance
ssh -i your-key.pem ec2-user@your-ec2-ip

# Update system
sudo yum update -y

# Install basic tools
sudo yum install -y git curl wget unzip
```

### Configure Security Groups
1. Go to EC2 Console → Security Groups
2. Create or modify security group with these rules:

| Type | Protocol | Port Range | Source |
|------|----------|------------|--------|
| SSH | TCP | 22 | Your IP |
| HTTP | TCP | 80 | 0.0.0.0/0 |
| Custom TCP | TCP | 30011 | 0.0.0.0/0 |
| Custom TCP | TCP | 30080 | 0.0.0.0/0 |
| Custom TCP | TCP | 30443 | 0.0.0.0/0 |

## 🔑 Step 2: GitHub Secrets Configuration

### Required Secrets
Add these secrets in your GitHub repository (Settings → Secrets and variables → Actions):

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `EC2_HOST` | Your EC2 public IP or domain | `18.206.89.183` |
| `EC2_SSH_KEY` | Your private SSH key content | `-----BEGIN RSA PRIVATE KEY-----...` |

### How to Add Secrets
1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret with the exact name and value

### Generate SSH Key (if needed)
```bash
# Generate new SSH key pair
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"

# Copy public key to EC2
ssh-copy-id -i ~/.ssh/id_rsa.pub ec2-user@your-ec2-ip

# Copy private key content for GitHub secret
cat ~/.ssh/id_rsa
```

## 🚀 Step 3: Manual Deployment (Option 1)

### Quick Deployment
```bash
# Connect to EC2
ssh ec2-user@your-ec2-ip

# Clone repository
git clone https://github.com/bonaventuresimeon/NativeSeries.git
cd NativeSeries

# Make deployment script executable
chmod +x deploy-ec2-user.sh

# Run deployment
./deploy-ec2-user.sh
```

### Verify Deployment
```bash
# Check container status
sudo docker ps

# Test endpoints
curl http://localhost:30011/health
curl http://localhost:30011/docs
curl http://localhost:30011/students/

# View logs
sudo docker logs -f student-tracker
```

## 🔄 Step 4: Automated Deployment (Option 2)

### GitHub Actions Workflow
The repository includes `.github/workflows/ec2-deploy.yml` that will:

1. **Validate** code and configurations
2. **Build** Docker image
3. **Push** to GitHub Container Registry
4. **Deploy** to EC2 automatically
5. **Verify** all endpoints

### Trigger Deployment
```bash
# Push to main branch to trigger deployment
git add .
git commit -m "Update application"
git push origin main
```

### Monitor Deployment
1. Go to GitHub repository → **Actions** tab
2. Click on the latest workflow run
3. Monitor the deployment progress

## 🧪 Step 5: Testing and Verification

### Health Checks
```bash
# Test from EC2
curl http://localhost:30011/health

# Test from external
curl http://your-ec2-ip:30011/health
```

### Endpoint Testing
```bash
# All endpoints should return 200 OK
curl -I http://your-ec2-ip:30011/health
curl -I http://your-ec2-ip:30011/docs
curl -I http://your-ec2-ip:30011/students/
curl -I http://your-ec2-ip:30011/metrics
```

### Container Management
```bash
# View running containers
sudo docker ps

# View container logs
sudo docker logs -f student-tracker

# Restart container
sudo docker restart student-tracker

# Stop container
sudo docker stop student-tracker

# Remove container
sudo docker rm -f student-tracker
```

## 🔧 Step 6: Troubleshooting

### Common Issues

#### 1. Docker Not Running
```bash
# Start Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group
sudo usermod -aG docker ec2-user
# Logout and login again
```

#### 2. Port Already in Use
```bash
# Check what's using port 30011
sudo netstat -tlnp | grep 30011

# Kill process if needed
sudo kill -9 <PID>
```

#### 3. Container Won't Start
```bash
# Check container logs
sudo docker logs student-tracker

# Check Docker daemon
sudo systemctl status docker

# Restart Docker
sudo systemctl restart docker
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

### Debug Commands
```bash
# Check system resources
free -h
df -h
top

# Check Docker status
sudo docker info
sudo docker version

# Check network connectivity
curl -v http://localhost:30011/health
telnet localhost 30011

# Check firewall
sudo iptables -L
```

## 📊 Step 7: Monitoring

### Application Monitoring
- **Health Check**: `http://your-ec2-ip:30011/health`
- **Metrics**: `http://your-ec2-ip:30011/metrics`
- **API Docs**: `http://your-ec2-ip:30011/docs`

### System Monitoring
```bash
# Monitor system resources
htop

# Monitor Docker
sudo docker stats

# Monitor logs
sudo journalctl -f
```

## 🔒 Step 8: Security Best Practices

### Security Recommendations
1. **Use HTTPS** in production
2. **Restrict security groups** to specific IPs
3. **Regular updates** of system packages
4. **Monitor logs** for suspicious activity
5. **Use IAM roles** instead of access keys
6. **Enable CloudWatch** monitoring

### Security Commands
```bash
# Update system regularly
sudo yum update -y

# Check for security updates
sudo yum check-update

# Monitor failed login attempts
sudo tail -f /var/log/secure

# Check open ports
sudo netstat -tlnp
```

## 🎯 Success Criteria

Your deployment is successful when:

✅ **Container is running**: `sudo docker ps` shows student-tracker  
✅ **Health check passes**: `curl http://localhost:30011/health` returns 200  
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

---

**🎉 Congratulations! Your Student Tracker is now deployed on EC2!**