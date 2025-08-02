#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🚨 Cleaning Docker + Kind environment...${NC}"

### Step 1: Delete all Kind clusters
echo -e "${YELLOW}🧹 Deleting all Kind clusters...${NC}"
KIND_CLUSTERS=$(kind get clusters || true)
for cluster in $KIND_CLUSTERS; do
    kind delete cluster --name "$cluster"
done
echo -e "${GREEN}✅ All Kind clusters removed.${NC}"

### Step 2: Stop all Docker containers
echo -e "${YELLOW}🛑 Stopping all Docker containers...${NC}"
docker ps -q | xargs -r docker stop

### Step 3: Remove all Docker containers
echo -e "${YELLOW}🗑️ Removing all Docker containers...${NC}"
docker ps -aq | xargs -r docker rm -f

### Step 4: Remove all Docker images
echo -e "${YELLOW}🔥 Removing all Docker images...${NC}"
docker images -q | xargs -r docker rmi -f

### Step 5: Kill any process using key ports (8080, 8443, 80, 443)
PORTS=(80 443 8080 8443)
for PORT in "${PORTS[@]}"; do
    PID=$(sudo lsof -ti tcp:$PORT || true)
    if [[ -n "$PID" ]]; then
        echo -e "${YELLOW}⚠️  Killing process on port $PORT (PID $PID)...${NC}"
        sudo kill -9 $PID || true
    else
        echo -e "${GREEN}✅ Port $PORT is free.${NC}"
    fi
done

### Step 6: Restart Docker service
echo -e "${YELLOW}🔁 Restarting Docker service...${NC}"
sudo systemctl restart docker

echo -e "${GREEN}✅ Environment cleaned and Docker restarted.${NC}"


