# Pipeline Status

[![CI/CD Pipeline](https://github.com/bonaventuresimeon/NativeSeries/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/bonaventuresimeon/NativeSeries/actions/workflows/ci-cd.yml)
[![PR Checks](https://github.com/bonaventuresimeon/NativeSeries/actions/workflows/pr-checks.yml/badge.svg)](https://github.com/bonaventuresimeon/NativeSeries/actions/workflows/pr-checks.yml)

## Quick Start

### 🚀 Automated Deployment
- **Main Branch**: Automatically deploys to staging, requires approval for production
- **Pull Requests**: Automatically validates code quality and runs tests
- **Manual Deploy**: Use Actions tab for on-demand deployments

### 🧪 Local Development
```bash
# Install dependencies
pip install -r requirements.txt

# Run tests
pytest app/test_*.py -v

# Check code quality
black --check app/
flake8 app/

# Build and test Docker image
docker build -t student-tracker .
```

### 📊 Pipeline Features
- ✅ Automated testing (pytest, flake8, black)
- 🔒 Security scanning (Trivy)
- 🐳 Docker image building and pushing
- 🚀 Multi-environment deployment (staging/production)
- 📈 Smoke tests and health checks
- 🔔 Deployment notifications

### 📖 Documentation
- [Complete Pipeline Documentation](../docs/PIPELINE.md)
- [Deployment Guide](../docs/DEPLOYMENT.md)

---

**Need help?** Check the [troubleshooting guide](../docs/PIPELINE.md#troubleshooting) or create an issue.