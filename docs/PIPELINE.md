# CI/CD Pipeline Documentation

## Overview

This document describes the CI/CD pipeline for the Student Tracker application. The pipeline is built using GitHub Actions and provides automated testing, building, and deployment capabilities.

## Pipeline Structure

### 🔄 Workflows

1. **Main CI/CD Pipeline** (`.github/workflows/ci-cd.yml`)
   - Triggers on pushes to `main` and `develop` branches
   - Runs comprehensive tests, security scans, and deployments

2. **PR Checks** (`.github/workflows/pr-checks.yml`)
   - Triggers on pull requests to `main` and `develop`
   - Runs quick validation and provides PR feedback

3. **Manual Deployment** (`.github/workflows/manual-deploy.yml`)
   - Manual trigger for on-demand deployments
   - Supports both staging and production environments

## Pipeline Stages

### 🧪 Test Stage
- **Python Setup**: Sets up Python 3.11 environment
- **Dependency Installation**: Installs requirements from `requirements.txt`
- **Code Linting**: Runs `flake8` for code quality checks
- **Code Formatting**: Validates formatting with `black`
- **Unit Tests**: Executes `pytest` test suite
- **Docker Build Test**: Validates Dockerfile builds successfully

### 🔒 Security Stage
- **Vulnerability Scanning**: Uses Trivy to scan for security issues
- **SARIF Upload**: Uploads security results to GitHub Security tab
- **Dependency Scanning**: Checks for known vulnerabilities in dependencies

### 🐳 Build & Push Stage
- **Docker Image Build**: Creates production Docker image
- **Container Registry**: Pushes to GitHub Container Registry (ghcr.io)
- **Image Tagging**: Tags with branch name, SHA, and latest
- **Build Caching**: Uses GitHub Actions cache for faster builds

### 🚀 Deployment Stages

#### Staging Deployment
- **Environment**: `staging`
- **Automatic**: Deploys automatically on main branch pushes
- **Smoke Tests**: Runs basic health checks
- **Rollback**: Manual rollback available

#### Production Deployment
- **Environment**: `production`
- **Manual Approval**: Requires manual approval for production
- **Post-deployment Verification**: Runs comprehensive health checks
- **Notifications**: Sends deployment notifications

## Environment Configuration

### GitHub Environments

You need to configure these environments in your GitHub repository:

1. **staging**
   - No protection rules (auto-deploy)
   - Environment variables for staging URLs

2. **production**
   - Required reviewers for manual approval
   - Environment variables for production URLs

### Environment Variables

Set these in your GitHub repository settings:

```yaml
# Repository Variables
PRODUCTION_HOST: "18.206.89.183"  # Your production server IP
PRODUCTION_PORT: "30011"          # Your production port

# Repository Secrets (if needed)
DOCKER_USERNAME: "your-docker-username"
KUBE_CONFIG: "base64-encoded-kubeconfig"
SLACK_WEBHOOK: "your-slack-webhook-url"
```

## Manual Deployment

### Using GitHub Actions UI

1. Go to your repository's Actions tab
2. Select "Manual Deployment" workflow
3. Click "Run workflow"
4. Choose:
   - Environment (staging/production)
   - Version/tag to deploy
   - Whether to skip tests

### Using Your Deploy Script

The pipeline integrates with your existing `deploy.sh` script:

```bash
# Production deployment
./deploy.sh --deploy-prod

# Build image only
./deploy.sh --build-image

# Setup cluster
./deploy.sh --setup-cluster
```

## Testing

### Local Testing

Run tests locally before pushing:

```bash
# Install dependencies
pip install -r requirements.txt

# Run linting
flake8 app/ --count --select=E9,F63,F7,F82 --show-source --statistics

# Check formatting
black --check app/

# Run tests
pytest app/test_*.py -v

# Test Docker build
docker build -t student-tracker .
```

### Smoke Tests

The pipeline includes automated smoke tests:

```bash
# Run smoke tests locally
./scripts/smoke-tests.sh http://localhost:8000

# Run against staging
./scripts/smoke-tests.sh http://staging.yourdomain.com

# Run against production
./scripts/smoke-tests.sh http://yourdomain.com
```

## Monitoring & Notifications

### GitHub Actions
- All workflow runs are logged in the Actions tab
- Failed runs send email notifications to committers
- Security scan results appear in the Security tab

### Deployment Status
- Deployment summaries are shown in workflow runs
- Environment deployment history is tracked
- Manual approvals are logged with approver information

## Troubleshooting

### Common Issues

1. **Tests Failing**
   ```bash
   # Run tests locally to debug
   pytest app/test_*.py -v --tb=long
   ```

2. **Docker Build Failing**
   ```bash
   # Test Docker build locally
   docker build -t test .
   docker run --rm test
   ```

3. **Linting Errors**
   ```bash
   # Fix formatting issues
   black app/
   
   # Check specific linting issues
   flake8 app/ --show-source
   ```

4. **Deployment Failures**
   - Check the deploy.sh script logs in the workflow
   - Verify environment variables are set correctly
   - Ensure target servers are accessible

### Getting Help

1. Check workflow logs in GitHub Actions
2. Review the deployment validation report
3. Run smoke tests manually to isolate issues
4. Check your application logs after deployment

## Pipeline Configuration

The pipeline behavior can be customized by modifying:

- `.github/workflows/*.yml` - Workflow definitions
- `.github/pipeline-config.yml` - Pipeline configuration
- `scripts/smoke-tests.sh` - Post-deployment tests
- `deploy.sh` - Deployment script

## Security Considerations

- All secrets are stored in GitHub Secrets
- Container images are scanned for vulnerabilities
- Production deployments require manual approval
- All deployment activities are logged and auditable

## Next Steps

1. **Set up GitHub Environments** with appropriate protection rules
2. **Configure Environment Variables** for your specific setup
3. **Test the Pipeline** with a small change on a feature branch
4. **Customize Smoke Tests** for your specific application endpoints
5. **Set up Notifications** for your team's communication channels

---

For more information about GitHub Actions, see the [official documentation](https://docs.github.com/en/actions).