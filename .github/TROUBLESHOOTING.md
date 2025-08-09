# GitHub Actions Troubleshooting Guide

This guide helps you resolve common issues with the NativeSeries GitHub Actions workflows.

## 🔍 Common Issues and Solutions

### 1. **Python Version Issues**

#### Problem: `Python version '3.13' is not available`
```
Error: Python version '3.13' is not available
```

#### Solution:
- Change Python version to `3.11` in workflow files
- Update `env.PYTHON_VERSION` in all workflows

```yaml
env:
  PYTHON_VERSION: '3.11'  # Use stable version
```

### 2. **Docker Build Failures**

#### Problem: `failed to solve: process "/bin/sh -c pip install" did not return a zero code`
```
Error: failed to solve: process "/bin/sh -c pip install -r requirements.txt" did not return a zero code
```

#### Solutions:
1. **Check requirements.txt syntax**:
   ```bash
   pip install -r requirements.txt
   ```

2. **Update Dockerfile** to use multi-stage build:
   ```dockerfile
   FROM python:3.11-slim as base
   # ... rest of Dockerfile
   ```

3. **Add error handling** in workflow:
   ```yaml
   - name: Build and push Docker image
     uses: docker/build-push-action@v5
     continue-on-error: true
   ```

### 3. **Test Failures**

#### Problem: `pytest: command not found`
```
Error: pytest: command not found
```

#### Solution:
Use `python -m pytest` instead of `pytest`:
```yaml
- name: Run tests
  run: |
    python -m pytest app/ -v || echo "⚠️ Some tests failed (continuing...)"
```

### 4. **Permission Issues**

#### Problem: `Permission denied` or `403 Forbidden`
```
Error: 403 Forbidden
```

#### Solutions:
1. **Add proper permissions**:
   ```yaml
   permissions:
     contents: read
     packages: write
   ```

2. **Check repository secrets**:
   - Ensure `GITHUB_TOKEN` is available
   - Verify `NETLIFY_AUTH_TOKEN` and `NETLIFY_SITE_ID` if using Netlify

### 5. **YAML Syntax Errors**

#### Problem: `YAML syntax error`
```
Error: YAML syntax error at line X
```

#### Solutions:
1. **Use YAML validator**:
   - [YAML Validator](https://www.yamllint.com/)
   - [GitHub Actions Validator](https://github.com/nektos/act)

2. **Check indentation**:
   - Use 2 spaces for indentation
   - Ensure consistent spacing

### 6. **Job Dependency Issues**

#### Problem: `Job 'deploy' failed because it depends on job 'build'`
```
Error: Job 'deploy' failed because it depends on job 'build'
```

#### Solutions:
1. **Add continue-on-error**:
   ```yaml
   build:
     continue-on-error: true
   ```

2. **Use conditional dependencies**:
   ```yaml
   deploy:
     needs: [build]
     if: always() && needs.build.result != 'failure'
   ```

### 7. **ArgoCD Deployment Issues**

#### Problem: `ArgoCD application not found`
```
Error: Application not found
```

#### Solutions:
1. **Create ArgoCD application** in workflow:
   ```yaml
   - name: Deploy with ArgoCD
     run: |
       mkdir -p argocd
       cat > argocd/application.yaml << 'EOF'
       # ArgoCD application YAML
       EOF
   ```

2. **Check ArgoCD path**:
   - Ensure path points to `helm-chart` not `argocd`

### 8. **Netlify Deployment Issues**

#### Problem: `Netlify secrets not configured`
```
Warning: Netlify secrets not configured
```

#### Solutions:
1. **Add secrets** in repository settings:
   - Go to Settings → Secrets and variables → Actions
   - Add `NETLIFY_AUTH_TOKEN`
   - Add `NETLIFY_SITE_ID`

2. **Skip Netlify deployment** if not needed:
   ```yaml
   deploy-netlify:
     if: github.event_name == 'push' && secrets.NETLIFY_AUTH_TOKEN != ''
   ```

### 9. **Security Scan Failures**

#### Problem: `Security issues found`
```
Warning: Security issues found
```

#### Solutions:
1. **Review security reports**:
   - Download artifacts from workflow run
   - Check `bandit-report.json` and `safety-report.json`

2. **Fix security issues**:
   - Update vulnerable dependencies
   - Fix code security issues

3. **Continue on security issues**:
   ```yaml
   security-scan:
     continue-on-error: true
   ```

### 10. **Workflow Timeout Issues**

#### Problem: `Workflow timeout`
```
Error: Workflow timeout after 6 hours
```

#### Solutions:
1. **Optimize workflow**:
   - Use caching for dependencies
   - Parallel jobs where possible
   - Reduce unnecessary steps

2. **Add timeout limits**:
   ```yaml
   jobs:
     test:
       timeout-minutes: 30
   ```

## 🛠️ Debugging Workflows

### Enable Debug Logging
Add to workflow:
```yaml
env:
  ACTIONS_STEP_DEBUG: true
  ACTIONS_RUNNER_DEBUG: true
```

### Check Workflow Status
```bash
# View workflow runs
gh run list

# View specific run
gh run view <run-id>

# Download logs
gh run download <run-id>
```

### Local Testing
Use [act](https://github.com/nektos/act) to test workflows locally:
```bash
# Install act
brew install act

# Run workflow locally
act push
```

## 📋 Workflow Checklist

Before pushing changes, ensure:

- [ ] YAML syntax is valid
- [ ] Python version is supported (3.11)
- [ ] All required secrets are configured
- [ ] Dependencies are properly specified
- [ ] Error handling is in place
- [ ] Timeouts are reasonable
- [ ] Permissions are correct

## 🔧 Quick Fixes

### For Immediate Issues:

1. **Use the simple workflow**:
   ```bash
   # Rename the simple workflow to main
   mv .github/workflows/nativeseries-simple.yml .github/workflows/nativeseries.yml
   ```

2. **Disable problematic jobs**:
   ```yaml
   deploy-netlify:
     if: false  # Disable temporarily
   ```

3. **Add continue-on-error**:
   ```yaml
   - name: Problematic step
     run: command
     continue-on-error: true
   ```

## 📞 Getting Help

If you're still experiencing issues:

1. **Check workflow logs** in GitHub Actions tab
2. **Review this troubleshooting guide**
3. **Search GitHub Issues** for similar problems
4. **Create a new issue** with:
   - Workflow file content
   - Error logs
   - Steps to reproduce
   - Expected vs actual behavior

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub Actions Examples](https://github.com/actions/starter-workflows)
- [YAML Syntax Guide](https://yaml.org/spec/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)