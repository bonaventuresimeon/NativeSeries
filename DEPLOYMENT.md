# NativeSeries Deployment Guide

## Overview
This document describes the simplified deployment setup for NativeSeries application.

## Files Created/Updated

### 1. GitHub Actions Workflow
**File:** `.github/workflows/nativeseries.yml`

**Features:**
- ✅ Simple CI/CD pipeline
- ✅ Tests application on every push/PR
- ✅ Builds Docker image on main branch
- ✅ Pushes to GitHub Container Registry
- ✅ No complex configurations

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` branch
- Manual workflow dispatch

### 2. Netlify Configuration
**File:** `netlify.toml`

**Features:**
- ✅ Simple build configuration
- ✅ API redirects for FastAPI endpoints
- ✅ Security headers
- ✅ Development server configuration
- ✅ No complex environment variables

**Key Endpoints:**
- `/api/*` → Netlify Functions
- `/health` → Health check
- `/docs` → API documentation
- `/*` → SPA fallback

### 3. Build Script
**File:** `build.sh`

**Features:**
- ✅ Creates necessary directories
- ✅ Generates static files if missing
- ✅ Sets up health check function
- ✅ Simple error handling

## Deployment Process

### GitHub Actions (Docker)
1. **Test:** Runs pytest on the application
2. **Build:** Creates Docker image with tag `latest`
3. **Push:** Uploads to `ghcr.io/bonaventuresimeon/nativeseries:latest`
4. **Deploy:** Logs deployment completion

### Netlify (Serverless)
1. **Build:** Runs `./build.sh` script
2. **Publish:** Serves files from `public/` directory
3. **Functions:** Deploys serverless functions from `netlify/functions/`

## Access URLs

### Production (Docker)
- **Application:** http://54.166.101.159:30011
- **Health Check:** http://54.166.101.159:30011/health
- **API Docs:** http://54.166.101.159:30011/docs

### Netlify (Serverless)
- **Application:** [Your Netlify URL]
- **Health Check:** [Your Netlify URL]/health
- **API Docs:** [Your Netlify URL]/docs

## Troubleshooting

### GitHub Actions Issues
1. Check workflow logs in GitHub Actions tab
2. Verify Docker build context
3. Ensure GitHub token has package write permissions

### Netlify Issues
1. Check build logs in Netlify dashboard
2. Verify `build.sh` script is executable
3. Ensure all required files exist in `public/`

### Common Fixes
- **Build fails:** Check `requirements.txt` and Python version
- **Functions not working:** Verify `netlify/functions/` directory
- **Redirects not working:** Check `netlify.toml` syntax

## Environment Variables

### Required for Netlify
```bash
APP_ENV=production
APP_NAME=NativeSeries
SECRET_KEY=your-secret-key
DATABASE_URL=your-database-url
```

### Optional
```bash
DEBUG=false
LOG_LEVEL=INFO
CORS_ORIGINS=*
```

## Security Notes
- ✅ All sensitive data moved to environment variables
- ✅ Security headers configured in Netlify
- ✅ CORS properly configured
- ✅ No hardcoded secrets in configuration files

## Next Steps
1. Connect your repository to Netlify
2. Set up environment variables in Netlify dashboard
3. Deploy and test all endpoints
4. Monitor build logs for any issues

---
**Last Updated:** August 7, 2024
**Version:** 1.0.0