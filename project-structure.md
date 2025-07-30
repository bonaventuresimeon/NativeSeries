# Project Structure

This project follows a clean GitOps architecture with the following structure:

```
├── app/                          # Application source code
│   ├── main.py                   # FastAPI application
│   ├── models.py                 # Database models
│   ├── crud.py                   # CRUD operations
│   ├── database.py               # Database configuration
│   └── routes/                   # API routes
├── infra/                        # Infrastructure as Code
│   ├── kind/                     # Kind cluster configuration
│   ├── helm/                     # Helm charts
│   └── argocd/                   # ArgoCD applications
├── k8s/                          # Kubernetes manifests
│   ├── base/                     # Base manifests
│   └── overlays/                 # Environment-specific overlays
├── .github/                      # CI/CD workflows
│   └── workflows/
├── scripts/                      # Utility scripts
├── docker/                       # Docker configuration
├── docs/                         # Documentation
└── deploy/                       # Deployment scripts
```

## Components

- **Kind**: Local Kubernetes cluster for development
- **Helm**: Package manager for Kubernetes applications
- **ArgoCD**: GitOps continuous delivery tool
- **GitHub Actions**: CI/CD pipeline automation