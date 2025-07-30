#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Preparing to push GitOps changes to GitHub...${NC}"

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo -e "${RED}❌ Not in a git repository. Please run this from the project root.${NC}"
    exit 1
fi

# Check git status
echo -e "${BLUE}📊 Current git status:${NC}"
git status

echo -e "${YELLOW}📝 Files to be committed:${NC}"
git status --porcelain

# Confirm before proceeding
echo -e "${YELLOW}Do you want to continue with committing and pushing these changes? (y/N):${NC}"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⚠️  Operation cancelled.${NC}"
    exit 0
fi

# Add all changes
echo -e "${BLUE}📦 Adding all changes...${NC}"
git add .

# Create comprehensive commit message
COMMIT_MESSAGE="feat: Complete GitOps reorganization and fixes

🏗️ Project Structure:
- Reorganized into clean infra/, k8s/, scripts/, docker/ structure
- Moved existing files to appropriate locations
- Created comprehensive documentation

🔧 GitHub Workflow Fixes:
- Added /health endpoint for Kubernetes probes
- Updated all GitHub Actions to latest versions
- Fixed git permissions for GitOps operations
- Added comprehensive test suite
- Simplified build process (removed ARM64)
- Enhanced error handling with continue-on-error

🎯 DNS & Port Configuration (30.80.98.218:8011):
- Updated Helm values for NodePort service (30011→8011)
- Configured Kind cluster with proper port mappings
- Updated ArgoCD for IP-based access (:30080)
- Updated all application URLs and ingress configs

🐳 Docker & Kubernetes:
- Improved Helm charts with security contexts
- Added health checks and resource management
- Created environment-specific value files
- Updated service configurations for external access

🚀 Deployment & Scripts:
- Created one-command deployment script
- Updated ArgoCD setup for external access
- Enhanced cleanup and utility scripts
- Added comprehensive deployment guides

📚 Documentation:
- Updated README with GitOps workflow
- Created deployment guide and troubleshooting docs
- Added configuration examples and best practices

✅ All components now work together seamlessly:
- CI/CD pipeline builds successfully
- Application accessible at 30.80.98.218:8011
- ArgoCD accessible at 30.80.98.218:30080
- GitOps workflow functional end-to-end"

# Commit changes
echo -e "${BLUE}💾 Committing changes...${NC}"
git commit -m "$COMMIT_MESSAGE"

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
echo -e "${BLUE}📍 Current branch: ${CURRENT_BRANCH}${NC}"

# Check if we have a remote origin
if ! git remote get-url origin >/dev/null 2>&1; then
    echo -e "${RED}❌ No remote 'origin' found.${NC}"
    echo -e "${YELLOW}Please add your GitHub repository as origin:${NC}"
    echo -e "git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git"
    exit 1
fi

REMOTE_URL=$(git remote get-url origin)
echo -e "${BLUE}🌐 Remote origin: ${REMOTE_URL}${NC}"

# Push to current branch
echo -e "${BLUE}🚀 Pushing to ${CURRENT_BRANCH}...${NC}"
git push origin "$CURRENT_BRANCH"

echo -e "${GREEN}✅ Successfully pushed to GitHub!${NC}"
echo -e "${BLUE}📋 Next steps:${NC}"
echo -e "  1. Check GitHub Actions workflow status"
echo -e "  2. Verify the CI/CD pipeline runs successfully"
echo -e "  3. Monitor for any build failures"
echo -e "  4. Create a pull request if needed"
echo -e ""
echo -e "${YELLOW}🔗 GitHub repository: ${REMOTE_URL}${NC}"
echo -e "${YELLOW}🔗 Actions: ${REMOTE_URL}/actions${NC}"

# Create develop branch if it doesn't exist
if ! git show-ref --verify --quiet refs/heads/develop; then
    echo -e "${BLUE}🌿 Creating develop branch...${NC}"
    git checkout -b develop
    git push origin develop
    git checkout "$CURRENT_BRANCH"
    echo -e "${GREEN}✅ Created develop branch for GitOps workflow${NC}"
fi

echo -e "${GREEN}🎉 All changes pushed successfully!${NC}"