# GitHub Actions Workflows

This directory contains the CI/CD workflows for the NativeSeries project.

## 📋 Workflow Overview

### 1. **nativeseries.yml** - Main Pipeline
The primary workflow that runs on pushes to main/develop branches and pull requests.

**Triggers:**
- Push to `main`, `develop`, or `cursor/deploy-application-fix-errors-and-merge-pr-2456`
- Pull requests to `main`
- Manual dispatch

**Jobs:**
- **Test**: Linting, formatting, and unit tests
- **Build**: Docker image build and push to GHCR
- **Deploy**: Production deployment with ArgoCD
- **Deploy-Netlify**: Netlify Functions deployment
- **Security-Scan**: Security vulnerability scanning
- **Notify**: Deployment status notifications

### 2. **pr-check.yml** - Pull Request Checks
Focused workflow for pull request validation with faster feedback.

**Triggers:**
- Pull requests to `main` or `develop`
- Manual dispatch

**Jobs:**
- **Lint-and-Test**: Code quality checks and unit tests
- **Build-Test**: Docker and Netlify build validation
- **Integration-Test**: API and integration tests
- **Notify-PR**: PR status summary

### 3. **maintenance.yml** - Scheduled Maintenance
Automated maintenance tasks for security and dependency management.

**Triggers:**
- Weekly schedule (Sundays at 2 AM UTC)
- Manual dispatch

**Jobs:**
- **Dependency-Check**: Security vulnerabilities and outdated packages
- **Security-Scan**: Comprehensive security scanning
- **Code-Quality**: Code formatting and type checking
- **Notify-Maintenance**: Maintenance results summary

### 4. **release.yml** - Release Management
Automated release creation and deployment.

**Triggers:**
- Push tags matching `v*`
- Manual dispatch with version input

**Jobs:**
- **Release**: GitHub release creation with changelog
- **Build-Release**: Release-specific Docker image
- **Deploy-Release**: Production deployment of release

## 🔧 Configuration

### Environment Variables
```yaml
REGISTRY: ghcr.io
IMAGE_NAME: bonaventuresimeon/nativeseries
PYTHON_VERSION: '3.11'
```

### Required Secrets
- `GITHUB_TOKEN`: Automatically provided by GitHub
- `NETLIFY_AUTH_TOKEN`: For Netlify deployment (optional)
- `NETLIFY_SITE_ID`: For Netlify deployment (optional)

### Branch Protection
Recommended branch protection rules for `main`:
- Require status checks to pass before merging
- Require branches to be up to date before merging
- Require pull request reviews before merging
- Require conversation resolution before merging

## 🚀 Usage

### Manual Workflow Execution
1. Go to the **Actions** tab in your repository
2. Select the workflow you want to run
3. Click **Run workflow**
4. Choose the branch and any required inputs
5. Click **Run workflow**

### Creating a Release
```bash
# Create and push a tag
git tag v1.0.0
git push origin v1.0.0

# Or use the manual workflow with version input
```

### Monitoring Workflows
- Check the **Actions** tab for real-time status
- Review workflow summaries for detailed results
- Download artifacts for security reports and logs

## 📊 Workflow Status

### Success Indicators
- ✅ All tests passing
- ✅ Code quality checks passing
- ✅ Security scans clean
- ✅ Docker builds successful
- ✅ Deployments completed
- ✅ Health checks passing

### Failure Handling
- ⚠️ Non-critical failures use `continue-on-error: true`
- 🔄 Automatic retries for transient failures
- 📧 Notifications for deployment status
- 📋 Detailed error reporting in summaries

## 🔒 Security Features

### Automated Security Scanning
- **Bandit**: Python security linting
- **Safety**: Known vulnerability checking
- **pip-audit**: Dependency vulnerability scanning
- **Flake8**: Code quality and security checks

### Security Reports
- JSON-formatted reports uploaded as artifacts
- 30-day retention for security artifacts
- Integration with GitHub Security tab

## 🐳 Docker Integration

### Multi-Stage Builds
- **Base**: Common dependencies and setup
- **Test**: Testing environment with test execution
- **Production**: Optimized production image

### Image Tags
- `latest`: Latest successful build
- `{branch}`: Branch-specific builds
- `{sha}`: Commit-specific builds
- `{version}`: Release version tags

## 🌐 Deployment Targets

### Production (Kubernetes)
- **Target**: `54.166.101.159:30011`
- **Method**: Helm + ArgoCD
- **Namespace**: `nativeseries`
- **Health Check**: `/health` endpoint

### Netlify Functions
- **Target**: Netlify platform
- **Method**: Netlify CLI
- **Functions**: `/.netlify/functions/api/*`
- **Health Check**: `/.netlify/functions/api/health`

## 📈 Monitoring and Notifications

### Workflow Notifications
- GitHub step summaries for each workflow
- Deployment status notifications
- Release summaries with changelog
- Maintenance reports

### Health Checks
- Application health endpoint monitoring
- Docker container health checks
- Netlify function health verification
- Retry logic for transient failures

## 🛠️ Troubleshooting

### Common Issues

#### Build Failures
```bash
# Check Docker build logs
docker build --no-cache .

# Verify requirements.txt
pip install -r requirements.txt
```

#### Test Failures
```bash
# Run tests locally
python -m pytest app/ -v

# Check linting
flake8 app/
black --check app/
```

#### Deployment Issues
```bash
# Check ArgoCD status
kubectl get applications -n argocd

# Verify Helm chart
helm lint helm-chart/
helm template test helm-chart/
```

### Debug Mode
Add `debug: true` to workflow steps for verbose output:
```yaml
- name: Debug step
  run: |
    echo "Debug information"
    env | sort
  env:
    ACTIONS_STEP_DEBUG: true
```

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Buildx Documentation](https://docs.docker.com/buildx/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Netlify Functions Documentation](https://docs.netlify.com/functions/overview/)

## 🤝 Contributing

When adding new workflows or modifying existing ones:

1. Test workflows locally when possible
2. Use `continue-on-error: true` for non-critical steps
3. Add comprehensive error handling
4. Include meaningful step summaries
5. Document any new secrets or environment variables
6. Update this README with workflow changes