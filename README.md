# Bonaventure Simeon: Student-Tracker Web App


[![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?style=for-the-badge&logo=prometheus&logoColor=white)](https://prometheus.io/)
[![Grafana](https://img.shields.io/badge/Grafana-F46800?style=for-the-badge&logo=grafana&logoColor=white)](https://grafana.com/)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-326CE5?style=for-the-badge&logo=argo&logoColor=white)](https://argoproj.github.io/argo-cd/)
[![Helm](https://img.shields.io/badge/Helm-0F1689?style=for-the-badge&logo=helm&logoColor=white)](https://helm.sh/)
[![Loki](https://img.shields.io/badge/Loki-F7B93E?style=for-the-badge&logo=loki&logoColor=white)](https://grafana.com/oss/loki/)

A simple FastAPI web application for registering students and tracking their weekly progress during the Cloud Native Series.

---

## Table of Contents

- [Repository URL](#repository-url)  
- [Original Author](#original-author)  
- [Adopted and Collaborated by](#adopted-and-collaborated-by)  
- [🚀 Key Features](#-key-features)  
- [📦 Prerequisites](#-prerequisites)  
- [💻 Local Development Setup](#-local-development-setup)  
- [🐳 Docker Instructions](#-docker-instructions)  
- [📬 API Endpoints](#-api-endpoints)  
- [🌐 Deploying to Cloud (Optional)](#-deploying-to-cloud-optional)  
- [⚙️ Environment Variables](#️-environment-variables)  
- [🛠 Troubleshooting](#-troubleshooting)  
- [🤝 Contributing](#-contributing)  
- [👩🏽‍💻 Credits](#-credits)  

---

## Repository URL

https://github.com/bonaventuresimeon/Student-Tracker.git

---

## Original Author

Chisom Jude

---

## Adopted and Collaborated by

Bonaventure Simeon

---

## 🚀 Key Features

- Register new students: Generates a unique ID for each student upon registration.  
- Track weekly progress: Monitor individual student progress week by week.  
- Centralized database: Stores all student data in a single MongoDB instance (hosted on MongoDB Atlas or similar).  
- RESTful API: Simple endpoints for registration, status retrieval, and progress updates.  
- Secure secret management: Integrates with Vault to securely manage sensitive credentials.

### 📊 Diagrams

#### System Architecture
```mermaid
flowchart LR
  U[User Browser] --> I[NGINX Ingress]
  I --> SVC[Service (NodePort 80->8000)]
  SVC --> APP[FastAPI App (Deployment)]
  APP -->|/metrics| PROM[Prometheus]
  PROM --> G[Grafana]
  APP -->|stdout logs| PT[Promtail]
  PT --> L[Loki]
  G -->|query| PROM
  G -->|query| L
  G -->|dashboards| U
  GIT[GitHub (Manifests + Helm Chart)] --> A[ArgoCD]
  A -->|sync| K8s[(Kubernetes Cluster: gitops)]
  K8s --> APP
```

#### GitOps Flow
```mermaid
flowchart LR
  Dev[Developer] --> Push[Push/PR]
  Push --> GH[GitHub]
  GH --> CI[GitHub Actions: build & push image]
  CI --> REG[Container Registry]
  GH --> Manifests[Manifests/Chart]
  Manifests --> Argo[ArgoCD]
  Argo --> Cluster[K8s Cluster: gitops]
  Cluster --> App[NativeSeries App]
```

#### Monitoring & Logging
```mermaid
flowchart LR
  App[App] -->|/metrics| Prom[Prometheus]
  App -->|logs| Promtail[Promtail]
  Promtail --> Loki[Loki]
  Prom --> Graf[Grafana]
  Loki --> Graf
  Graf --> User[User]
```

![GitOps repo layout](doc/7.0%20-%20GitOps/image.png)

## ⚡ Quick GitOps Install

- Ensure inbound TCP to 80, 443, 30011, 30080, 30081, 30082, 30083 on your host/firewall
- Optional: set your public DNS or IP for the summary

```bash
chmod +x scripts/gitops-*.sh
export PUBLIC_HOST=<your-dns-or-ip>   # e.g. 54.166.101.159
./scripts/gitops-install.sh
```

Access URLs (using PUBLIC_HOST or your DNS):
- App:       http://$PUBLIC_HOST:30011
- ArgoCD:    http://$PUBLIC_HOST:30080 (user: admin; script prints password)
- Grafana:   http://$PUBLIC_HOST:30081 (admin/admin123)
- Prometheus:http://$PUBLIC_HOST:30082
- Loki:      http://$PUBLIC_HOST:30083

Destroy everything:
```bash
./scripts/gitops-destroy.sh
```

---

## 📦 Prerequisites

- Python 3.10 or higher  
- Git  
- MongoDB Atlas account (or equivalent MongoDB cluster) to obtain your connection string  
- HashiCorp Vault (for secrets management)

---

## 💻 Local Development Setup

1. **Clone the Repository**

```
git clone https://github.com/bonaventuresimeon/Student-Tracker.git
cd Student-Tracker
```

2. **Create Virtual Environment & Install Dependencies**

```
python3 -m venv venv
source venv/bin/activate  # On Windows use: venv\Scripts\activate
pip install -r requirements.txt
```

3. **Configure Database and Vault**

- Create a `.env` and update the Vault IP address if necessary.  
- Set your Vault token as an environment variable.
- Remember to `.gitignore` when pushing to github.

```
export VAULT_TOKEN=<your_vault_token>
```

4. **Run the Application Locally**

```
uvicorn app.main:app –host 0.0.0.0 –port 8011 –reload
```

5. **Access the Application**

Open your browser and visit:  

```
http://localhost:8011
```

Or if running on a remote server, replace `localhost` with the server’s IP address:  

```
http://<server-ip>:8011
```

---

## 🐳 Docker Instructions

1. **Build Docker Image**

```
docker build -t student-tracker .
```

2. **Run Docker Container**

```
docker run –env-file .env -p 8011:8000 student-tracker
```

3. **Push to Docker Hub**

- Log in to Docker Hub:

  ```
  docker login
  ```

- Tag and push your image (replace `your-dockerhub-username` accordingly):

  ```
  docker tag student-tracker your-dockerhub-username/student-tracker
  docker push your-dockerhub-username/student-tracker
  ```

---

## 📬 API Endpoints

| Method | Endpoint                         | Description                         |
|--------|---------------------------------|-----------------------------------|
| POST   | `/register?name=YourName`        | Register a new student             |
| GET    | `/status/{student_id}`           | View registration & progress       |
| POST   | `/update/{student_id}?week=week1`| Update progress by week            |

---

## 🌐 Deploying to Cloud (Optional)

Deploy your app to popular cloud platforms such as:  
- Render  
- Railway  
- Fly.io  
- Azure App Service  
- AWS Elastic Beanstalk  
- And many more…

---

## ⚙️ Environment Variables

| Variable    | Description                | Example                                             |
|-------------|----------------------------|-----------------------------------------------------|
| VAULT_TOKEN | Vault authentication token | s.1234567890abcdef                                  |
| MONGO_URI   | MongoDB connection URI     | mongodb+srv://user:pass@cluster0.mongodb.net/db    |

Make sure to place these variables in a `.env` file or your environment to avoid exposing sensitive data.

---

## 🛠 Troubleshooting

- **MongoDB connection issues?**  
Verify your connection string and whitelist your IP on MongoDB Atlas.

- **Vault token errors?**  
Confirm your Vault token is valid and Vault server is reachable.

- **Docker container crashes?**  
Check logs with `docker logs <container_id>` and ensure environment variables are set.

- **API requests failing?**  
Confirm endpoints and parameters are correct and the server is running.

---

## 🤝 Contributing

Contributions are welcome! Feel free to:  
- Fork the repository  
- Open issues and feature requests  
- Submit pull requests with improvements or bug fixes  

Please adhere to the existing code style and include tests when applicable.

---

## 👩🏽‍💻 Credits

Built for the Cloud Native Series by:  
- Original Author: Chisom Jude  
- Adopted and Collaborated by: Bonaventure Simeon

---

Quick Test - Create the following:  
- GitHub badges (build status, Docker pulls, etc.)  
- GitHub Actions CI/CD pipelines for automated testing and deployment  

Just ask! 😊

Thank you for using Student-Tracker!
