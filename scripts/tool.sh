#!/usr/bin/env bash
set -euo pipefail
GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; NC=$'\033[0m'
echo -e "${YELLOW}🔧 Starting setup on AWS EC2 (Amazon Linux 2023)…${NC}"

# 1. System Update (YUM → DNF under the hood)
echo -e "${GREEN}🔄 Applying OS updates...${NC}"
sudo yum update -y  # yum is a symlink to dnf, fully supported in AL2023 [oai_citation_attribution:4‡AWS Documentation](https://docs.aws.amazon.com/linux/al2023/ug/package-management.html?utm_source=chatgpt.com)

# 2. Python 3.13 + venv
echo -e "${GREEN}📦 Installing Python 3.13…${NC}"
sudo yum groupinstall -y "Development Tools"
sudo yum install -y gcc bzip2-devel libffi-devel zlib-devel wget make \
  openssl-devel readline-devel gdbm-devel tk-devel sqlite-devel

pushd /usr/src >/dev/null

# Ensure no dirty leftover folder from copy-paste Unicode hyphens
for t in Python-3.13*.tgz; do
  if [[ -f "$t" ]]; then
    sudo rm -rf -- "${t%.tgz}.*" "${t%.tgz}"
    sudo wget -q "https://www.python.org/ftp/python/${t%.tgz#Python-}.tgz"
  fi
done

latest_python_dir=$(ls -1d Python-3.13.* 2>/dev/null | \
  tr '‑' '-' | sort -V | tail -n1)
[[ -d "$latest_python_dir" ]] || { echo "❌ No Python‑3.13 source dir found"; exit 1; }

echo "Using source: $latest_python_dir"
sudo mv "$latest_python_dir" python_install_3_13
cd python_install_3_13

sudo ./configure --prefix=/usr/local --enable-optimizations \
  --enable-shared LDFLAGS='-Wl,-rpath=/usr/local/lib'
sudo make -j"$(nproc)"
sudo make altinstall

popd >/dev/null

# Ensure python3.13 is on PATH
if ! echo "$PATH" | grep -q "/usr/local/bin"; then
  echo 'export PATH=/usr/local/bin:$PATH' >> ~/.bashrc
  source ~/.bashrc
fi

echo -e "${GREEN}✔ Installed Python: $(python3.13 --version)${NC}"
python3.13 -m venv ~/venv
source ~/venv/bin/activate
python --version
pip install --upgrade pip setuptools

# 3. Docker 28.0+
echo -e "${GREEN}🚢 Installing Docker…${NC}"
sudo amazon-linux-extras enable docker
sudo yum install -y docker
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
echo -e "${GREEN}✔ Docker: $(docker --version)${NC}"

# 4. kubectl 1.32.x
echo -e "${GREEN}🔧 Installing kubectl v1.32.x…${NC}"
curl -sLO "https://dl.k8s.io/release/v1.32.0/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
echo -e "${GREEN}✔ kubectl: $(kubectl version --client --short)${NC}"

# 5. Helm 3.16.x
echo -e "${GREEN}🪿 Installing Helm v3.16.x…${NC}"
curl -sLO https://get.helm.sh/helm-v3.16.0-linux-amd64.tar.gz
tar zxvf helm-v3.16.0-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
rm -rf linux-amd64 helm-v3.16.0-linux-amd64.tar.gz
echo -e "${GREEN}✔ Helm: $(helm version --short)${NC}"

# 6. Kind 0.27.0
echo -e "${GREEN}☸️ Installing Kind v0.27.0…${NC}"
curl -sLo kind https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-amd64
chmod +x kind
sudo mv kind /usr/local/bin/
echo -e "${GREEN}✔ Kind: $(kind version)${NC}"

# 7. Argo CD CLI v2.13.2
echo -e "${GREEN}📥 Installing Argo CD CLI v2.13.2…${NC}"
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/download/v2.13.2/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/argocd
echo -e "${GREEN}✔ Argo CD CLI: $(argocd version --client)${NC}"

cat <<EOF
${GREEN}🎉 Setup complete!

• Logout and log back in to activate Docker group membership.
• To reuse Python environment, run: source ~/venv/bin/activate
• Validate installations:
    python --version
    pip list
    docker run hello-world
    kubectl version --client
    helm version
    kind version
    argocd version --client${NC}
EOF
