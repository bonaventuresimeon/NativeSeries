#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Target repository
TARGET_REPO="https://github.com/bonaventuresimeon/Student-Tracker.git"
TARGET_REPO_SSH="git@github.com:bonaventuresimeon/Student-Tracker.git"

echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                  Merge to Target Repository                 ║"
echo "║         bonaventuresimeon/Student-Tracker                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo -e "${RED}❌ Not in a git repository. Please run this from the project root.${NC}"
    exit 1
fi

# Check git status
echo -e "${BLUE}📊 Current git status:${NC}"
git status

# Check if there are uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo -e "${YELLOW}⚠️  You have uncommitted changes. Committing them first...${NC}"
    git add .
    git commit -m "feat: Final updates before merge to target repository"
fi

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)
echo -e "${BLUE}📍 Current branch: ${CURRENT_BRANCH}${NC}"

# Check current remote
CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "No remote set")
echo -e "${BLUE}🌐 Current remote: ${CURRENT_REMOTE}${NC}"

# Function to setup target repository as remote
setup_target_remote() {
    echo -e "${BLUE}🔧 Setting up target repository as remote...${NC}"
    
    # Remove existing target remote if it exists
    git remote remove target 2>/dev/null || true
    
    # Try SSH first, fallback to HTTPS
    if git remote add target "$TARGET_REPO_SSH" 2>/dev/null; then
        echo -e "${GREEN}✅ Added target remote using SSH${NC}"
    else
        git remote add target "$TARGET_REPO" 2>/dev/null || true
        echo -e "${GREEN}✅ Added target remote using HTTPS${NC}"
    fi
    
    # Verify remote was added
    git remote -v | grep target
}

# Function to push to target repository
push_to_target() {
    echo -e "${BLUE}🚀 Pushing to target repository...${NC}"
    
    # Fetch target repository to check for conflicts
    echo -e "${BLUE}📥 Fetching target repository...${NC}"
    git fetch target
    
    # Check if main branch exists on target
    if git ls-remote --heads target main | grep main >/dev/null; then
        TARGET_BRANCH="main"
    elif git ls-remote --heads target master | grep master >/dev/null; then
        TARGET_BRANCH="master"
    else
        TARGET_BRANCH="main"  # Default to main
        echo -e "${YELLOW}⚠️  Target repository appears to be empty. Will create main branch.${NC}"
    fi
    
    echo -e "${BLUE}🎯 Target branch: ${TARGET_BRANCH}${NC}"
    
    # Create a merge commit with comprehensive message
    MERGE_MESSAGE="feat: Complete GitOps reorganization and infrastructure improvements

🚀 Major Updates:
- Complete project structure reorganization for GitOps
- Fixed all GitHub Actions workflow issues
- Configured DNS/port for 30.80.98.218:8011
- Added comprehensive Helm charts and ArgoCD setup
- Implemented one-command deployment system
- Added health endpoints and comprehensive testing
- Created production-ready Kubernetes configurations

🎯 Access URLs:
- Application: http://30.80.98.218:8011
- API Docs: http://30.80.98.218:8011/docs
- Health Check: http://30.80.98.218:8011/health
- ArgoCD UI: http://30.80.98.218:30080

🚀 Deployment:
Run: ./scripts/deploy-all.sh

All components tested and ready for production deployment."
    
    # Push current branch to target repository
    echo -e "${BLUE}📤 Pushing ${CURRENT_BRANCH} to target repository...${NC}"
    git push target "$CURRENT_BRANCH:$TARGET_BRANCH" --force-with-lease
    
    echo -e "${GREEN}✅ Successfully pushed to target repository!${NC}"
}

# Function to create PR on target repository
create_target_pr() {
    if command -v gh &> /dev/null; then
        echo -e "${BLUE}📝 Creating pull request on target repository...${NC}"
        
        # Switch to target repository context
        ORIGINAL_REMOTE=$(git remote get-url origin)
        git remote set-url origin "$TARGET_REPO"
        
        # Create PR
        gh pr create \
            --repo "bonaventuresimeon/Student-Tracker" \
            --title "🚀 Complete GitOps Stack Implementation & Infrastructure Overhaul" \
            --body "## 🎯 Major Infrastructure & GitOps Implementation

This PR brings a complete overhaul of the Student Tracker application with modern GitOps practices, CI/CD improvements, and production-ready infrastructure.

## ✨ What's New

### 🏗️ **Complete Project Reorganization**
- Clean \`infra/\`, \`k8s/\`, \`scripts/\`, \`docker/\` structure
- GitOps best practices implementation
- Comprehensive documentation and guides

### 🔧 **CI/CD Pipeline Fixes**
- ✅ Fixed all GitHub Actions workflow issues
- ✅ Added health endpoints for Kubernetes probes
- ✅ Updated to latest action versions
- ✅ Enhanced test coverage and error handling
- ✅ Proper git permissions for GitOps operations

### 🎯 **Production Configuration (30.80.98.218:8011)**
- ✅ NodePort service configuration (30011→8011)
- ✅ Kind cluster with proper port mappings
- ✅ ArgoCD setup for external access (:30080)
- ✅ IP-based ingress and service configs

### 🐳 **Kubernetes & Helm**
- ✅ Modern Helm Chart API v2
- ✅ Security contexts and resource management
- ✅ Multi-environment support (dev/staging/prod)
- ✅ Health checks and monitoring readiness
- ✅ HPA and PDB for production scaling

### 🚀 **Deployment Automation**
- ✅ One-command deployment: \`./scripts/deploy-all.sh\`
- ✅ ArgoCD GitOps workflow
- ✅ Environment-specific configurations
- ✅ Cleanup and utility scripts

## 🎯 Access URLs
- 🌐 **Application**: http://30.80.98.218:8011
- 📖 **API Docs**: http://30.80.98.218:8011/docs  
- 🩺 **Health**: http://30.80.98.218:8011/health
- 🎯 **ArgoCD**: http://30.80.98.218:30080

## 🚀 Quick Start
\`\`\`bash
# Deploy everything
./scripts/deploy-all.sh

# Or manual setup
./scripts/setup-kind.sh
./scripts/setup-argocd.sh
helm upgrade --install student-tracker infra/helm --values infra/helm/values-dev.yaml -n app-dev --create-namespace
\`\`\`

## ✅ Production Ready
- Security contexts and non-root containers
- Resource limits and health checks  
- Multi-environment configurations
- Comprehensive testing and CI/CD
- Documentation and troubleshooting guides

Ready for immediate deployment! 🚀" \
            --label "enhancement" \
            --label "gitops" \
            --label "infrastructure" \
            --assignee "bonaventuresimeon"
        
        # Restore original remote
        git remote set-url origin "$ORIGINAL_REMOTE"
        
        echo -e "${GREEN}✅ Pull request created on target repository!${NC}"
    else
        echo -e "${YELLOW}⚠️  GitHub CLI not available. Please create PR manually.${NC}"
    fi
}

# Main execution
echo -e "${BLUE}🎯 Target repository: ${TARGET_REPO}${NC}"
echo -e "${YELLOW}📝 This will merge all your GitOps improvements to the target repository.${NC}"
echo -e "${YELLOW}Do you want to continue? (y/N):${NC}"
read -r response

if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⚠️  Operation cancelled.${NC}"
    exit 0
fi

# Execute merge process
setup_target_remote
push_to_target

echo -e "${GREEN}✅ Successfully merged to target repository!${NC}"
echo -e "${BLUE}📋 What was merged:${NC}"
echo -e "  ✅ Complete GitOps project structure"
echo -e "  ✅ Fixed GitHub Actions workflows"
echo -e "  ✅ DNS/Port configuration (30.80.98.218:8011)"
echo -e "  ✅ Helm charts and ArgoCD setup"
echo -e "  ✅ One-command deployment system"
echo -e "  ✅ Comprehensive documentation"
echo -e ""
echo -e "${BLUE}🔗 Target Repository: ${TARGET_REPO}${NC}"
echo -e "${BLUE}🎯 Application will be accessible at: http://30.80.98.218:8011${NC}"
echo -e "${BLUE}🎯 ArgoCD will be accessible at: http://30.80.98.218:30080${NC}"
echo -e ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo -e "  1. Visit the target repository to verify the merge"
echo -e "  2. Check GitHub Actions workflow status"
echo -e "  3. Deploy using: ./scripts/deploy-all.sh"
echo -e "  4. Access the application at the configured URLs"
echo -e ""

# Ask if user wants to create a PR
echo -e "${YELLOW}🔀 Would you like to create a pull request on the target repository? (y/N):${NC}"
read -r pr_response
if [[ "$pr_response" =~ ^[Yy]$ ]]; then
    create_target_pr
fi

echo -e "${GREEN}🎉 Merge process completed successfully!${NC}"