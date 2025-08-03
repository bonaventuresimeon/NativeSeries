# 🚀 EC2 Deployment Quick Reference

## ⚡ Quick Commands

### Deployment
```bash
# Full EC2 deployment
./deploy.sh ec2

# Quick Docker deployment
./deploy.sh docker

# Validate deployment
./deploy.sh ec2-validate

# Check health
./deploy.sh health-check

# Show status
./deploy.sh status
```

### Validation
```bash
# Comprehensive validation
./scripts/ec2-validation.sh

# Test endpoints
curl http://18.206.89.183:30011/health
curl http://18.206.89.183:30011/docs
curl http://18.206.89.183:30011/students/

# Check container
sudo docker ps
sudo docker logs student-tracker
```

## 🔧 Common Issues & Solutions

### Docker Issues
```bash
# Docker not running
sudo systemctl start docker
sudo systemctl enable docker

# Permission denied
sudo usermod -aG docker ec2-user
# Logout and login again

# Port already in use
sudo docker stop student-tracker
sudo docker rm student-tracker
```

### Network Issues
```bash
# Check ports
sudo netstat -tlnp | grep 30011

# Test connectivity
curl -v http://18.206.89.183:30011/health

# Check security groups
# Ensure ports 22, 80, 30011, 30080, 30443 are open
```

### Application Issues
```bash
# Check logs
sudo docker logs -f student-tracker

# Restart container
sudo docker restart student-tracker

# Check resources
sudo docker stats student-tracker
htop
```

## 📊 Monitoring Commands

### System Monitoring
```bash
# System resources
htop
free -h
df -h

# Docker monitoring
sudo docker stats
sudo docker ps

# Application monitoring
curl http://18.206.89.183:30011/metrics
```

### Log Monitoring
```bash
# Application logs
sudo docker logs -f student-tracker

# System logs
sudo journalctl -f

# Docker daemon logs
sudo journalctl -u docker -f
```

## 🔒 Security Checklist

### Security Groups
- [ ] SSH (Port 22) - Your IP only
- [ ] HTTP (Port 80) - 0.0.0.0/0
- [ ] Custom TCP (Port 30011) - 0.0.0.0/0
- [ ] Custom TCP (Port 30080) - 0.0.0.0/0
- [ ] Custom TCP (Port 30443) - 0.0.0.0/0

### System Security
- [ ] System packages updated
- [ ] Docker running as non-root
- [ ] Firewall configured
- [ ] SSH key-based authentication
- [ ] Regular security updates

## 📱 Application URLs

### Production URLs
- **Application**: http://18.206.89.183:30011
- **API Docs**: http://18.206.89.183:30011/docs
- **Health Check**: http://18.206.89.183:30011/health
- **Students Interface**: http://18.206.89.183:30011/students/
- **Metrics**: http://18.206.89.183:30011/metrics

### ArgoCD URLs
- **Production**: https://argocd-prod.18.206.89.183.nip.io
- **Development**: https://argocd-dev.18.206.89.183.nip.io
- **Staging**: https://argocd-staging.18.206.89.183.nip.io

## 🎯 Success Indicators

### ✅ Deployment Success
- Container is running: `sudo docker ps` shows student-tracker
- Health check passes: `curl http://18.206.89.183:30011/health` returns 200
- All endpoints work: Health, docs, students, metrics accessible
- External access: Application accessible from internet
- Logs are clean: No errors in container logs

### 📊 Performance Metrics
- Response time: < 2 seconds
- Memory usage: < 80%
- CPU usage: < 70%
- Disk usage: < 85%

## 🆘 Emergency Commands

### Quick Recovery
```bash
# Emergency restart
sudo docker restart student-tracker

# Emergency cleanup
sudo docker system prune -f

# Emergency logs
sudo docker logs --tail 100 student-tracker

# Emergency health check
curl -f http://18.206.89.183:30011/health || echo "CRITICAL: Health check failed"
```

### Backup & Restore
```bash
# Backup container
sudo docker commit student-tracker student-tracker-backup

# Save image
sudo docker save student-tracker:latest > backup.tar

# Restore image
sudo docker load < backup.tar
```

## 📞 Support Contacts

### Documentation
- **Main Guide**: README.md
- **Architecture**: docs/architecture-diagram.md
- **Screenshots**: docs/screenshots.md
- **Validation**: scripts/ec2-validation.sh

### Troubleshooting
1. Run validation: `./deploy.sh ec2-validate`
2. Check logs: `sudo docker logs student-tracker`
3. Review documentation: README.md
4. Create GitHub issue for problems

---

**🎉 Happy Deploying!**