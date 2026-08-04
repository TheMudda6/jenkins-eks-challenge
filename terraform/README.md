# Jenkins on Amazon EKS

Production-style Infrastructure as Code (IaC) project that provisions a complete Jenkins platform on Amazon Elastic Kubernetes Service (EKS) using Terraform.

The project demonstrates how a modern DevOps platform can be built from scratch using reproducible infrastructure, Kubernetes, IAM Roles for Service Accounts (IRSA), persistent storage, AWS Load Balancer Controller, Amazon EBS CSI Driver, and automated deployment scripts.

Every infrastructure component can be created with a single deployment script and removed with a matching destroy script to minimise cloud costs while maintaining a fully repeatable environment.

## Overview

This project was built to simulate how a real DevOps engineer provisions and manages cloud infrastructure rather than simply deploying an application.

Instead of relying on manual AWS configuration, every major infrastructure component is defined as code using Terraform and deployed onto Amazon EKS.

The platform currently includes:

- Amazon VPC
- Amazon EKS
- Managed Node Groups
- IAM Roles
- IAM Roles for Service Accounts (IRSA)
- Amazon EBS CSI Driver
- AWS Load Balancer Controller
- Volume Snapshot support
- Jenkins Deployment
- PostgreSQL StatefulSet
- Redis Deployment
- Persistent GP3 storage
- HTTPS using AWS Certificate Manager (ACM)
- Cloudflare-managed DNS
- Automated deployment, validation and destruction scripts

## Features

- Fully modular Terraform architecture
- Production-style Amazon EKS deployment
- Managed worker node groups
- Secure IAM Roles for Service Accounts (IRSA)
- Amazon EBS CSI Driver
- Dynamic GP3 StorageClasses
- Persistent Jenkins storage
- PostgreSQL StatefulSet with retained persistent storage
- Redis Deployment for application caching
- Kubernetes Volume Snapshot support
- AWS Load Balancer Controller
- HTTPS using AWS Certificate Manager (ACM)
- Cloudflare-managed DNS
- One-command deployment
- One-command destruction
- Infrastructure validation
- Automated deployment verification
- Automated cleanup verification

## Technology Stack

| Category | Technologies |
|----------|--------------|
| Cloud Platform | Amazon Web Services (AWS) |
| Infrastructure as Code | Terraform |
| Container Orchestration | Amazon Elastic Kubernetes Service (EKS) |
| Containers | Docker |
| Networking | Amazon VPC, Internet Gateway, NAT Gateway, Route Tables |
| Storage | Amazon EBS, EBS CSI Driver, GP3 Storage Classes |
| Identity & Access | AWS IAM, IAM Roles for Service Accounts (IRSA), OpenID Connect (OIDC) |
| Load Balancing | AWS Load Balancer Controller, Application Load Balancer (ALB) |
| TLS | AWS Certificate Manager (ACM) |
| DNS | Cloudflare |
| Kubernetes | Deployments, Services, Ingress, Persistent Volumes, Persistent Volume Claims |
| Disaster Recovery | Volume Snapshots |
| Automation | Bash |
| Version Control | Git & GitHub |

## Repository Structure

```text
.
├── bootstrap/               # Initial remote state bootstrap
├── docs/                    # Project documentation
├── kubernetes/              # Learning notes and Kubernetes practice resources
├── screenshots/             # Project screenshots
├── terraform/
│   ├── k8s/                 # Kubernetes manifests
│   ├── modules/
│   │   ├── eks/
│   │   ├── iam/
│   │   ├── vpc/
│   │   ├── ecr/
│   │   └── sqs/
│   ├── scripts/
│   │   ├── deploy.sh
│   │   ├── destroy.sh
│   │   └── README.md
│   ├── main.tf
│   ├── provider.tf
│   ├── variables.tf
│   └── backend.tf
└── README.md
```

## Project Highlights

- Fully reproducible Infrastructure as Code using Terraform
- Modular infrastructure following production-style design
- Secure authentication using IAM Roles for Service Accounts (IRSA)
- Automated deployment and teardown scripts
- Dynamic persistent storage using Amazon EBS
- Kubernetes Volume Snapshot support for disaster recovery
- HTTPS-enabled public access through an AWS Application Load Balancer
- Cloudflare-managed DNS
- Infrastructure validated through complete deploy and destroy lifecycle testing

## Architecture

The platform follows a modular Infrastructure as Code (IaC) architecture where
each layer has a single responsibility. Terraform provisions the AWS
infrastructure while Kubernetes manages the application workloads.

```text
                 Internet
                     │
                     ▼
              Cloudflare DNS
                     │
                     ▼
         AWS Application Load Balancer
                     │
                     ▼
            Kubernetes Ingress
                     │
          ┌──────────┴──────────┐
          ▼                     ▼
   Jenkins Service        PostgreSQL Service
          │                     │
          ▼                     ▼
  Jenkins Deployment     PostgreSQL StatefulSet
          │                     │
          ▼                     ▼
     Jenkins Pod          PostgreSQL Pod
          │                     │
          ▼                     ▼
     Jenkins PVC        PostgreSQL PVC (Retain)
          │                     │
          ▼                     ▼
     Amazon EBS          Amazon EBS

                     ▲
                     │
             Redis Service
                     │
                     ▼
             Redis Deployment
                     │
                     ▼
                Redis Pod

────────────────────────────────────────────

Terraform provisions:

• Amazon VPC
• Public & Private Subnets
• Internet Gateway
• NAT Gateway
• Amazon EKS
• Managed Node Groups
• IAM Roles
• IRSA
• Amazon EBS CSI Driver
• AWS Load Balancer Controller
• OIDC Provider
```

## Infrastructure Components

| Component | Purpose |
|----------|---------|
| Amazon VPC | Provides an isolated network for the platform. |
| Public Subnets | Host internet-facing load balancers. |
| Private Subnets | Host Kubernetes worker nodes securely. |
| NAT Gateway | Allows private resources to access the internet without being publicly reachable. |
| Amazon EKS | Managed Kubernetes control plane. |
| Managed Node Groups | EC2 worker nodes that run Kubernetes workloads. |
| IAM Roles | Secure permissions for AWS resources. |
| IRSA | Allows Kubernetes Service Accounts to securely assume IAM Roles without static AWS credentials. |
| AWS Load Balancer Controller | Automatically provisions Application Load Balancers from Kubernetes Ingress resources. |
| Amazon EBS CSI Driver | Dynamically provisions persistent storage for Kubernetes workloads. |
| Volume Snapshot Controller | Enables Kubernetes volume snapshot and restore functionality. |
| Jenkins | CI/CD automation server deployed on Kubernetes with persistent storage. |

## Deployment Workflow

```text
Git Repository
      │
      ▼
Run deploy.sh
      │
      ▼
Terraform Validate
      │
      ▼
Terraform Plan
      │
      ▼
Terraform Apply
      │
      ▼
Configure kubectl
      │
      ▼
Install Snapshot Infrastructure
      │
      ▼
Create Storage Classes
      │
      ▼
Deploy PostgreSQL
      │
      ▼
Deploy Redis
      │
      ▼
Deploy Jenkins
      │
      ▼
Create Ingress
```

## Deployment

### Prerequisites

Before deploying the platform, ensure the following tools are installed:

- AWS CLI
- Terraform
- kubectl
- Helm
- Git

AWS credentials must also be configured with sufficient permissions to create EKS resources.

### Deploy

```bash
cd terraform
./scripts/deploy.sh
```

The deployment script automatically:

- Formats and validates the Terraform configuration
- Creates and reviews a Terraform execution plan
- Provisions AWS infrastructure
- Configures kubectl
- Installs the EBS CSI Driver
- Installs the AWS Load Balancer Controller
- Installs Volume Snapshot infrastructure
- Creates GP3 StorageClasses
- Deploys PostgreSQL
- Deploys Redis
- Deploys Jenkins
- Creates the Application Load Balancer
- Verifies the deployment

### Destroy

```bash
cd terraform
./scripts/destroy.sh
```

The destroy script safely removes Kubernetes resources before destroying all Terraform-managed infrastructure to minimise AWS costs.

## Current Status

| Area | Status |
|-------|--------|
| Infrastructure | ✅ Complete |
| Networking | ✅ Complete |
| IAM & IRSA | ✅ Complete |
| Amazon EKS | ✅ Complete |
| Storage | ✅ Complete |
| PostgreSQL | ✅ Complete |
| Redis | ✅ Complete |
| Volume Snapshots | ✅ Complete |
| Jenkins Platform | ✅ Complete |
| Deploy & Destroy Automation | ✅ Complete |
| HTTPS & Cloudflare | ✅ Complete* |
| Platform Validation | ✅ Complete |
| Sample Application | ⏳ Phase 2 |
| Amazon SQS | ⏳ Phase 2 |
| Application CI/CD | ⏳ Phase 2 |
| ArgoCD | ⏳ Phase 3 |
| Prometheus & Grafana | ⏳ Phase 3 |

> **Note:** Cloudflare DNS is currently managed manually. Automating DNS management with Terraform is planned as a future enhancement.

## Roadmap

### Version 1.0 ✅

- Modular Terraform architecture
- Amazon EKS cluster
- Managed node groups
- IAM Roles
- IAM Roles for Service Accounts (IRSA)
- Amazon EBS CSI Driver
- AWS Load Balancer Controller
- Persistent Jenkins storage
- Volume Snapshot support
- Cloudflare DNS
- HTTPS with ACM
- Automated deployment
- Automated destruction

### Phase 2

- Deploy sample microservice application
- Connect application to PostgreSQL
- Integrate Redis caching
- Amazon SQS event bus
- Application CI/CD
- Automate Cloudflare DNS with Terraform

### Phase 3

- ArgoCD GitOps
- Prometheus
- Grafana
- AlertManager
- Centralised monitoring

## Screenshots

### Successful Deployment

![Deployment](screenshots/deploy-successful.png)

### Platform Verification

![Platform Verification](screenshots/services.png)

### Successful Cleanup

![Cleanup](screenshots/destroy-successful.png)

## Lessons Learned

This project reinforced several important DevOps engineering principles:

- Infrastructure should be reproducible and fully automated.
- Security should rely on IAM roles rather than static credentials.
- Small, modular Terraform modules are easier to maintain than large monolithic configurations.
- Every deployment should include validation before and after infrastructure changes.
- Automated cleanup is just as important as automated deployment for controlling cloud costs.
- Building, breaking, debugging and rebuilding infrastructure provides a deeper understanding than following tutorials.
- Separating infrastructure provisioning (Terraform) from workload deployment (Kubernetes manifests and deployment scripts) results in a cleaner, more maintainable platform.

## License

This project is released under the MIT License.

## Key Skills Demonstrated

- Terraform Infrastructure as Code
- Amazon Web Services (AWS)
- Amazon EKS
- Kubernetes
- Docker
- Bash Scripting
- IAM & IRSA
- Networking
- Persistent Storage
- Disaster Recovery
- Cloud Infrastructure
- Infrastructure Automation
- Git & GitHub
- Technical Documentation