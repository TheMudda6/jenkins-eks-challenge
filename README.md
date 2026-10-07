# Kubernetes E-Commerce Platform on Amazon EKS

A production-inspired Kubernetes e-commerce platform built on **Amazon EKS**, using Terraform, Kubernetes, Kustomize, ArgoCD, GitHub Actions, AWS managed services, and a full observability stack.

This project evolved from an earlier Jenkins-on-EKS deployment into a complete nine-service Kubernetes platform based on **The K8s Project (v2 Edition) – E-Commerce Platform**.

The goal was not simply to deploy an application, but to build, automate, validate, break, troubleshoot, and document a realistic cloud-native platform from infrastructure creation through application delivery and destruction.

---

## Project Overview

The platform demonstrates:

- Infrastructure as Code with Terraform
- Amazon EKS 1.33
- Multi-AZ networking
- Karpenter node provisioning
- AWS EBS CSI storage
- Persistent PostgreSQL and Redis
- AWS Secrets Manager with External Secrets
- Amazon SQS with a Dead Letter Queue
- Traefik ingress behind an AWS Network Load Balancer
- TLS with cert-manager and Let's Encrypt
- Route53 DNS automation
- ArgoCD GitOps
- Kustomize development and production overlays
- Prometheus and Grafana observability
- GitHub Actions CI/CD
- GitHub Actions OIDC authentication
- Container image security scanning
- Horizontal Pod Autoscaling
- Snapshot and restore workflows
- Automated infrastructure destruction and cleanup

The project was deployed to EKS for live validation and was subsequently destroyed to avoid unnecessary AWS costs.

---

# Architecture

```text
                         Internet
                            |
                            v
                    AWS Network Load Balancer
                            |
                            v
                       Traefik Ingress
                            |
                    HTTPS / TLS termination
                            |
                            v
                     api-gateway :8080
                            |
          +-----------------+------------------+
          |                 |                  |
          v                 v                  v
   order-service     inventory-service    payment-service
       :8081              :8082               :8083
          |
          +------------------+
          |                  |
          v                  v
 notification-service   shipping-service
       :8084                 :8085
          |
          +------------------+
          |
          v
     worker :8090
     scheduler :8091
     dashboard-api :8086

          |
          +--------------------+
          |                    |
          v                    v
     PostgreSQL              Redis
       20Gi                   10Gi
          |
          v
     AWS EBS gp3

order-service / payment-service / shipping-service
                    |
                    v
              Amazon SQS
                    |
                    v
               Worker
                    |
                    v
                DLQ

                    AWS
                     |
       +-------------+-------------+
       |             |             |
       v             v             v
  Secrets Manager   ECR          Route53
       |                           |
       v                           v
External Secrets              DNS records

                     |
                     v
                  ArgoCD
                     |
        +------------+-------------+
        |            |             |
        v            v             v
       Dev          Prod       Platform Apps

                     |
                     v
              Prometheus
                     |
                     v
                  Grafana
```

---

# Application Services

The application consists of the nine services defined by the project architecture.

| Service | Port | Purpose |
|---|---:|---|
| `api-gateway` | 8080 | Entry point for application requests |
| `order-service` | 8081 | Order processing |
| `inventory-service` | 8082 | Inventory management |
| `payment-service` | 8083 | Payment processing |
| `notification-service` | 8084 | Notifications |
| `shipping-service` | 8085 | Shipping operations |
| `worker` | 8090 | Background event processing |
| `scheduler` | 8091 | Scheduled background processing |
| `dashboard-api` | 8086 | Dashboard/API functionality |

Each service is deployed using:

- Kubernetes Deployment
- ClusterIP Service
- Resource requests and limits
- Liveness probes
- Readiness probes
- Dedicated ServiceAccount
- Container security settings
- Multi-stage Docker builds
- ECR images tagged with the Git commit SHA

Request-path services also use Horizontal Pod Autoscaling.

---

# Infrastructure

Infrastructure is managed entirely through Terraform.

## AWS Infrastructure

The platform provisions:

- VPC
- Public and private subnets
- Multi-AZ networking
- Internet Gateway
- NAT Gateway infrastructure
- VPC Flow Logs
- Amazon EKS
- EKS managed components
- Karpenter
- IAM roles
- KMS encryption
- Amazon ECR
- Amazon SQS
- AWS Secrets Manager integration
- Route53 integration

The EKS cluster uses:

- Kubernetes 1.33
- Control-plane logging
- KMS secrets encryption
- EKS access entries
- EBS CSI
- VPC CNI network policy support

---

# Terraform State

Terraform uses remote state stored in Amazon S3.

```text
S3 Bucket:
mudassir-tf-state-893061519920

Platform State:
jenkins/terraform.tfstate

Bootstrap State:
bootstrap/terraform.tfstate
```

Native S3 lockfile-based state locking is enabled.

This keeps Terraform state outside the local machine and allows CI/CD to operate against the same remote state.

---

# Karpenter

Karpenter is used for Kubernetes node provisioning.

The project includes:

- Karpenter controller
- IAM permissions
- EC2NodeClass
- NodePool
- Required subnet and security-group discovery tags

This allows Kubernetes workloads to trigger dynamic node provisioning instead of relying entirely on statically defined worker nodes.

---

# Storage

Persistent storage is provided through the AWS EBS CSI driver.

The project includes:

- EBS CSI EKS add-on
- IAM permissions for EBS CSI
- IRSA
- `gp3` StorageClass
- `gp3-retain` StorageClass
- VolumeSnapshotClass

## Storage Classes

```text
gp3
├── ReclaimPolicy: Delete
└── Used for normal persistent workloads

gp3-retain
├── ReclaimPolicy: Retain
└── Used for PostgreSQL
```

PostgreSQL uses `gp3-retain` so that the underlying persistent volume is not automatically deleted when the Kubernetes claim is removed.

This also introduced an important operational lesson: retained EBS volumes can survive cluster destruction and must be deliberately accounted for during cleanup.

---

# PostgreSQL

PostgreSQL runs inside the Kubernetes cluster as a StatefulSet.

Configuration includes:

- PostgreSQL 16.9
- 1 replica
- 20Gi persistent volume
- `gp3-retain`
- Persistent `PGDATA`
- Kubernetes Secret generated through External Secrets
- Liveness/readiness checks

The PostgreSQL storage lifecycle was tested using Kubernetes snapshot and restore workflows.

---

# Redis

Redis runs as a StatefulSet with persistent storage.

Configuration includes:

- Redis 8.2
- 1 replica
- 10Gi persistent volume
- `gp3`
- Append-only file persistence
- Password authentication
- Readiness/liveness checks

Redis is used as the platform's stateful caching/data component.

---

# Secrets Management

Application secrets are not stored directly in Git.

The platform uses:

```text
AWS Secrets Manager
        |
        v
External Secrets
        |
        v
Kubernetes Secret
        |
        v
Application
```

External Secrets uses:

- IAM
- IRSA
- AWS Secrets Manager
- KMS permissions

The External Secrets IAM policy is restricted to the required Secrets Manager and KMS operations.

For the documented secret rotation procedure, see [Secrets Rotation](docs/secrets-rotation.md).

During deployment validation, an IRSA lifecycle issue was discovered where an existing External Secrets controller pod had been created before the required IAM mutation was available.

The issue was diagnosed by comparing the existing controller pod with a newly created test pod and confirming the presence of:

```text
AWS_ROLE_ARN
AWS_WEB_IDENTITY_TOKEN_FILE
aws-iam-token
```

The permanent Terraform configuration was then updated so the External Secrets IAM role has permission to decrypt the specific KMS key used by the secrets.

---

# Event Bus

The application uses Amazon SQS for asynchronous event processing.

The platform includes:

```text
orders queue
     |
     v
worker
     |
     v
orders DLQ
```

Configuration includes:

- 30 second visibility timeout
- 4 day message retention
- 20 second long polling
- Dead Letter Queue
- 14 day DLQ retention
- Maximum receive count of 5

IAM permissions are separated between event producers and consumers.

Producers can send messages while the worker can receive, delete, and inspect queue attributes.

---

# Ingress and TLS

External application traffic enters through an AWS Network Load Balancer.

```text
Internet
   |
   v
AWS Network Load Balancer
   |
   v
Traefik
   |
   v
Kubernetes Ingress
   |
   v
api-gateway
```

Traefik is deployed as a Kubernetes LoadBalancer service using:

- AWS NLB
- Internet-facing scheme
- IP target mode
- `traefik` ingress class
- HTTP to HTTPS redirection

---

# TLS

TLS certificates are managed by cert-manager and Let's Encrypt.

The platform uses an ACME DNS-01 challenge.

```text
cert-manager
     |
     v
Let's Encrypt
     |
     v
Route53 DNS challenge
     |
     v
TLS Certificate
```

The application hostname is:

```text
jenkins.mud-as-sir.uk
```

The Kubernetes ingress uses the generated TLS secret and routes traffic to the application gateway.

---

# GitOps

ArgoCD manages Kubernetes application state.

The platform uses an **App-of-Apps** architecture.

```text
platform-root
      |
      +-- e-commerce-dev
      +-- e-commerce-prod
      +-- postgres
      +-- redis
      +-- secrets
      +-- storage
      +-- monitoring
      +-- monitoring-stack
      +-- cert-manager
      +-- security
```

The ArgoCD root application tracks:

```text
terraform/infrastructure/argocd/applications
```

against:

```text
stable-v1.31
```

## Development

Development uses automated synchronization with:

- prune
- self-heal

## Production

Production deliberately uses manual synchronization.

This allows production changes to be reviewed before they are applied.

Git remains the source of truth for Kubernetes configuration.

---

# Kustomize

The application uses a base/overlay structure.

```text
application/
├── base/
│   ├── services/
│   ├── kustomization.yaml
│   └── ...
│
└── overlays/
    ├── dev/
    └── prod/
```

This allows the same application definitions to be reused while applying environment-specific configuration.

Examples include:

- replica counts
- HPA configuration
- environment-specific settings

---

# Observability

The platform uses the Prometheus and Grafana ecosystem.

The monitoring stack is deployed using:

```text
kube-prometheus-stack
```

Components include:

- Prometheus
- Grafana
- Alertmanager
- ServiceMonitors
- Prometheus rules
- Persistent storage

## Prometheus

Prometheus uses:

```text
20Gi gp3 PVC
7 day retention
```

## Grafana

Grafana uses:

```text
5Gi gp3 PVC
```

The monitoring configuration includes ServiceMonitors and dashboards for the application services.

---

# CI/CD

GitHub Actions provides the CI/CD pipeline.

The project uses GitHub Actions OIDC to authenticate with AWS.

No long-lived AWS access keys are required by the workflows.

---

## Application Pipeline

The application pipeline performs:

1. Matrix-based service processing
2. Go linting
3. Dependency download
4. Build
5. Unit tests
6. Trivy filesystem scanning
7. AWS authentication through OIDC
8. ECR authentication
9. Docker image build
10. Container image scanning
11. ECR push
12. Commit-SHA tagging
13. Kustomize validation
14. Manifest image update
15. Git commit and push

Images are tagged using the Git commit SHA rather than relying on `latest`.

Example:

```text
68bf0180...
```

This makes deployments traceable to an exact source revision.

---

# Infrastructure Pipeline

The Terraform pipeline performs:

```text
Terraform fmt
      |
      v
Terraform init
      |
      v
Terraform validate
      |
      v
TFLint
      |
      v
Checkov
      |
      v
Terraform plan
      |
      v
Required approval
      |
      v
Terraform apply
```

The deployment workflow uses the `terraform-production` GitHub environment with required reviewer approval.

The pipeline applies the exact Terraform plan artifact that was generated during the plan stage.

---

# Kubernetes Validation

The project also includes Kubernetes validation workflows covering:

- Kubernetes manifest validation
- Kustomize validation
- Configuration checks

This provides an additional validation layer before Kubernetes configuration reaches the cluster.

---

# Security

Security controls implemented throughout the project include:

- GitHub Actions OIDC
- No static AWS credentials in CI/CD
- IAM least-privilege policies
- IRSA
- KMS encryption
- EKS secrets encryption
- AWS Secrets Manager
- External Secrets
- Container image scanning
- Trivy
- Kubernetes resource limits
- Liveness/readiness probes
- Non-root containers
- Runtime container hardening
- Network policy support
- VPC Flow Logs
- Restricted IAM trust policies

Application containers use a non-root runtime user:

```text
UID 10001
```

---

# Disaster Recovery and Storage Restore

Persistent workloads were designed with storage recovery in mind.

The project includes:

- EBS VolumeSnapshotClass
- PostgreSQL snapshot manifests
- PostgreSQL restore manifests
- Restore test workflow
- Retained PostgreSQL storage
- Documented snapshot/restore procedure

PostgreSQL restore testing was successfully completed as part of the project validation.

The detailed storage and restore procedure is documented in [Storage and PostgreSQL Restore](docs/storage-restore.md).

---

# Deployment

The project can be deployed using the Terraform/deployment workflow.

From the repository root:

```bash
cd terraform
terraform init
terraform validate
terraform plan
terraform apply
```

The repository also contains deployment automation for bringing up the complete platform.

Before deployment, Terraform plans should always be reviewed before applying infrastructure changes.

---

# Destruction

The environment can be destroyed using the project destruction script:

```bash
./terraform/scripts/destroy.sh
```

The destroy workflow includes cleanup and verification for resources that may otherwise remain behind after EKS destruction.

This includes checks for:

- EKS
- VPC
- Load Balancers
- Security Groups
- NAT infrastructure
- Elastic IPs
- SQS queues
- Kubernetes resources
- EKS control-plane log groups

ECR repositories are intentionally preserved.

---

# Challenges and Troubleshooting

One of the main goals of this project was to encounter realistic infrastructure problems and solve them rather than simply following a deployment guide.

## External Secrets IRSA Failure

### Problem

PostgreSQL and application pods initially entered:

```text
CreateContainerConfigError
```

The External Secrets controller could not decrypt the required secret.

### Investigation

A newly created test pod using the External Secrets ServiceAccount was compared with the existing controller pod.

The new pod received:

```text
AWS_ROLE_ARN
AWS_WEB_IDENTITY_TOKEN_FILE
aws-iam-token
```

This confirmed the IRSA webhook was functioning correctly for newly created pods.

### Root Cause

The existing controller pod had been created before the required IAM mutation was available.

### Resolution

The controller was restarted and the IAM configuration was permanently updated through Terraform.

The IAM policy was given:

```text
kms:Decrypt
```

permission against the specific Secrets Manager KMS key.

After the controller restarted:

```text
ExternalSecret: SecretSynced
PostgreSQL: Ready
```

---

## ArgoCD Root Application State

The production ArgoCD application intentionally uses manual synchronization.

This meant the root application could report:

```text
OutOfSync
Healthy
```

even though the platform was healthy.

The deployment script was therefore changed to wait for:

```text
Healthy
```

rather than requiring:

```text
Synced + Healthy
```

This prevents the deployment process from treating intentional production drift as a deployment failure.

---

## Terraform Destroy Cleanup

The first complete destruction revealed that the EKS control-plane log group remained after Terraform destroyed the cluster.

The log group:

```text
/aws/eks/jenkins-eks/cluster
```

was automatically created by EKS rather than being directly managed by Terraform.

The destruction script was updated to discover and remove the relevant EKS log groups and then verify that they no longer existed.

The final destruction was successfully validated with no remaining:

- EKS cluster
- VPC
- Load Balancers
- NAT resources
- EKS security groups
- SQS queues
- EKS control-plane log groups

ECR was intentionally preserved.

---

# Lessons Learned

## Infrastructure as Code Is More Than Creating Resources

Terraform makes infrastructure reproducible, but resource lifecycle still needs to be understood.

AWS-managed or automatically generated resources may not behave exactly like resources directly managed by Terraform.

---

## Kubernetes Storage Has Lifecycle Implications

A PVC disappearing does not necessarily mean the underlying AWS storage has disappeared.

Using:

```text
Retain
```

means storage must be deliberately managed and recovered or deleted.

This is particularly important for databases.

---

## IRSA Depends on Pod Lifecycle

Adding or correcting an IAM role does not necessarily update already-running pods.

When debugging IRSA, checking the actual pod environment and projected token is often more useful than only checking the IAM configuration.

---

## GitOps Changes the Deployment Model

With ArgoCD, the deployment pipeline does not need to directly apply Kubernetes manifests.

Instead:

```text
Git change
    |
    v
ArgoCD
    |
    v
Kubernetes
```

This provides a clear separation between infrastructure provisioning and application reconciliation.

---

## Production Should Not Be Treated Like Development

Development can use:

```text
automated sync
prune
self-heal
```

Production deliberately uses manual synchronization.

This creates a review point before production changes are applied.

---

## Image Tags Should Be Immutable

Using:

```text
:latest
```

makes it difficult to determine exactly what version is running.

Using the Git commit SHA provides a direct relationship between:

```text
Git commit
     |
     v
Docker image
     |
     v
Kubernetes deployment
```

---

# Repository Structure

The repository is organised around infrastructure, Kubernetes configuration, CI/CD, and deployment automation.

```text
.
├── .github/
│   └── workflows/
│       ├── application-ci.yml
│       ├── kubernetes-validation.yaml
│       ├── terraform-deploy.yml
│       └── validate.yaml
│
├── bootstrap/
│   └── Terraform configuration for persistent GitHub OIDC access
│
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── backend.tf
│   ├── helm.tf
│   │
│   ├── modules/
│   │   ├── eks/
│   │   ├── iam/
│   │   ├── vpc/
│   │   ├── ecr/
│   │   ├── sqs/
│   │   ├── secrets/
│   │   ├── argocd/
│   │   └── ...
│   │
│   ├── infrastructure/
│   │   ├── application/
│   │   │   ├── base/
│   │   │   └── overlays/
│   │   │       ├── dev/
│   │   │       └── prod/
│   │   │
│   │   ├── argocd/
│   │   │   └── applications/
│   │   │
│   │   └── monitoring/
│   │
│   └── scripts/
│       ├── deploy.sh
│       └── destroy.sh
│
├── services/
│   ├── api-gateway/
│   ├── order-service/
│   ├── inventory-service/
│   ├── payment-service/
│   ├── notification-service/
│   ├── shipping-service/
│   ├── worker/
│   ├── scheduler/
│   └── dashboard-api/
│
└── README.md
```

---

# Core 100 Validation

The project was audited against the Core 100 requirements.

| Phase | Requirement | Status |
|---|---|---|
| 1 | Infrastructure | PASS |
| 2 | Storage | PASS |
| 3 | Stateful Tier | PASS |
| 4 | Application | PASS |
| 5 | Event Bus | PASS |
| 6 | Ingress | PASS |
| 7 | GitOps | PASS |
| 8 | Observability | PASS |
| 9 | CI/CD | PASS |
| 10 | Documentation | In progress |

The first nine phases were implemented and validated through Terraform checks, repository inspection, CI/CD validation, Kubernetes deployment testing, and live EKS validation.

---

# Validation Approach

The project was not considered complete simply because Terraform could create resources.

Validation included:

- Terraform validation
- Terraform plan review
- TFLint
- Checkov
- Shell validation
- Kustomize validation
- Docker builds
- Trivy scanning
- GitHub Actions validation
- Live EKS deployment
- Kubernetes readiness checks
- ArgoCD health checks
- PostgreSQL readiness
- Redis readiness
- Persistent volume validation
- Monitoring validation
- Snapshot/restore testing
- Destroy and cleanup verification

The platform was successfully deployed to EKS and subsequently destroyed after validation to avoid leaving unnecessary AWS resources running.

---

# Project Status

The implementation has completed the Core 100 requirements through the first nine phases.

The final documentation phase is being completed through this README.

The project demonstrates the full lifecycle:

```text
Design
  |
  v
Terraform
  |
  v
AWS Infrastructure
  |
  v
EKS
  |
  v
Kubernetes Platform
  |
  v
Application Deployment
  |
  v
GitOps
  |
  v
Observability
  |
  v
CI/CD
  |
  v
Validation
  |
  v
Troubleshooting
  |
  v
Destruction
```

The environment can therefore be created, validated, and destroyed through Infrastructure as Code rather than depending on manually configured infrastructure.

---

# Author

**Mudassir Shaikh**

DevOps / Cloud Engineering Portfolio Project

Technologies demonstrated:

```text
AWS
Amazon EKS
Terraform
Kubernetes
Docker
Kustomize
ArgoCD
GitHub Actions
Karpenter
Traefik
cert-manager
Let's Encrypt
Prometheus
Grafana
PostgreSQL
Redis
Amazon SQS
AWS Secrets Manager
External Secrets
Amazon ECR
IAM
IRSA
KMS
Route53
```
