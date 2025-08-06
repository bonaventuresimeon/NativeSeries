#!/bin/bash

# Docker Image Push Script
set -e

echo "🐳 Pushing Docker images to registry..."

# Login to GitHub Container Registry (requires token)
# echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin

# Push images
echo "📤 Pushing ghcr.io/bonaventuresimeon/nativeseries:latest..."
docker push ghcr.io/bonaventuresimeon/nativeseries:latest

echo "📤 Pushing ghcr.io/bonaventuresimeon/nativeseries:v1.1.0..."
docker push ghcr.io/bonaventuresimeon/nativeseries:v1.1.0

echo "✅ Images pushed successfully!"
