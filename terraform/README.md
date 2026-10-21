# Terraform Infrastructure — E-Commerce Platform

This project provisions the cloud infrastructure and supporting platform components for a nine-service E-Commerce Platform running on Amazon Elastic Kubernetes Service (EKS).

It demonstrates Infrastructure as Code (IaC), modular Terraform design, Kubernetes orchestration, GitOps delivery, persistent storage, asynchronous messaging, observability, and automated infrastructure lifecycle management.

Terraform manages AWS infrastructure and selected Helm releases. Argo CD reconciles Kubernetes application and platform resources from Git, while supporting controllers manage resources such as DNS records, certificates, external secrets, and EBS volumes.

> **Documentation scope:** This README describes the configuration present in the repository. The presence of Terraform resources, manifests, or scripts does not by itself prove that the platform is deployed, healthy, or fully validated.

## Overview

The platform combines AWS infrastructure with Kubernetes workloads and GitOps-based deployment.

The main components include:

- Amazon VPC with public and private subnets.
- Amazon EKS and a managed node group.
- Karpenter infrastructure for dynamic node provisioning.
- Amazon ECR repositories for nine application services.
- AWS IAM, OpenID Connect (OIDC), and IAM Roles for Service Accounts (IRSA).
- AWS KMS encryption keys and AWS Secrets Manager.
- Amazon SQS orders queue and dead-letter queue.
- PostgreSQL and Redis running in Kubernetes.
- EBS-backed persistent storage and volume snapshot support.
- Traefik ingress, AWS Load Balancer Controller, cert-manager, and ExternalDNS.
- Argo CD App-of-Apps GitOps architecture.
- Prometheus, Grafana, ServiceMonitors, and PrometheusRules.
- Terraform deployment and destruction scripts.

The project also contains a separate Compose/LocalStack setup for an older local application stack. This local setup is distinct from the nine-service EKS platform.

## Project highlights

- Modular Terraform infrastructure.
- Repeatable infrastructure provisioning with explicit plan-approval steps.
- Kubernetes application deployment using Kustomize and Argo CD.
- Nine independently containerized Go services.
- Commit-SHA image tagging in the application CI workflow.
- PostgreSQL and Redis integration.
- Asynchronous messaging through Amazon SQS.
- EBS-backed persistence and snapshot/restore resources.
- Centralized metrics and dashboard configuration.
- Separate Terraform state for infrastructure bootstrap and DNS.
- Automated deployment, application checks, and selected infrastructure cleanup.

## Technology stack

| Category | Technologies |
|---|---|
| Cloud platform | Amazon Web Services (AWS) |
| Infrastructure as Code | Terraform |
| Container orchestration | Amazon EKS, Kubernetes |
| Application language | Go |
| Containers | Docker |
| Networking | Amazon VPC, Internet Gateway, NAT Gateway, route tables |
| Container registry | Amazon ECR |
| Identity and access | AWS IAM, IRSA, OIDC |
| Encryption | AWS KMS |
| Messaging | Amazon SQS and dead-letter queue |
| Database | PostgreSQL |
| Cache | Redis |
| Storage | Amazon EBS, EBS CSI Driver, gp3 StorageClasses |
| Ingress | Traefik, AWS Load Balancer Controller, Network Load Balancer |
| TLS | cert-manager and Let's Encrypt |
| DNS | Route 53 and Cloudflare delegation |
| GitOps | Argo CD and Kustomize |
| Monitoring | Prometheus and Grafana |
| Automation | Bash and GitHub Actions |
| Version control | Git and GitHub |

## Repository structure
.
├── bootstrap/                         # Initial Terraform state backend and CI role
├── docs/                              # Operational documentation and runbooks
├── kubernetes/                        # Kubernetes learning and practice resources
├── screenshots/                       # Project screenshots
├── services/                          # Nine Go application services
├── terraform/
│   ├── dns/                           # Separate DNS Terraform root
│   ├── infrastructure/
│   │   ├── application/
│   │   │   ├── base/
│   │   │   └── overlays/
│   │   ├── argocd/
│   │   │   └── applications/
│   │   ├── cert-manager/
│   │   ├── disaster-recovery/
│   │   ├── monitoring/
│   │   ├── postgres/
│   │   ├── redis/
│   │   ├── secrets/
│   │   ├── security/
│   │   ├── snapshot/
│   │   └── storage/
│   ├── modules/
│   │   ├── argocd/
│   │   ├── ecr/
│   │   ├── eks/
│   │   ├── iam/
│   │   ├── karpenter/
│   │   ├── kms/
│   │   ├── legacy/
│   │   ├── secrets/
│   │   ├── sqs/
│   │   └── vpc/
│   ├── scripts/
│   │   ├── README.md
│   │   ├── deploy.sh
│   │   ├── destroy.sh
│   │   ├── check-argocd.sh
│   │   └── localstack-init.sh
│   ├── main.tf
│   ├── helm.tf
│   ├── provider.tf
│   ├── variables.tf
│   └── backend.tf
└── README.md

This tree shows the principal directories and files; it is not an exhaustive listing of every repository resource.

## Architecture

The platform is organized into infrastructure, platform services, application workloads, and supporting data and observability components.

### Request and application flow

                         Internet
                            |
                            v
                  Cloudflare DNS delegation
                            |
                            v
                    Route 53 DNS zone
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
                       API Gateway
                            |
             +--------------+--------------+
             |              |              |
             v              v              v
        Order Service  Inventory Service  Payment Service
             |              |              |
             +--------------+--------------+
                            |
                  PostgreSQL / Redis
                            |
                            v
                      Amazon SQS
                            |
                            v
                          Worker

             Additional application services:
       Notification Service, Shipping Service,
                Scheduler, Dashboard API

This is a conceptual view of the intended application architecture, not a verified runtime trace of every request or event.

### Infrastructure flow

                    Terraform
                        |
          +-------------+-------------+
          |             |             |
          v             v             v
         VPC           EKS         AWS Services
          |             |          ECR / SQS
          |             |          KMS / Secrets
          |             |
          |             v
          |        Helm Releases
          |             |
          |             v
          |          Argo CD
          |             |
          |             v
          |      Kubernetes Resources
          |             |
          |      +------+------+
          |      |             |
          v      v             v
       Routing  Application  Monitoring
                Workloads    and Storage

## Terraform roots and state

The repository uses three distinct Terraform roots.

| Root | Responsibility |
|---|---|
| `terraform/` | Main AWS infrastructure and selected platform Helm releases |
| `bootstrap/` | Initial Terraform state-backend infrastructure and GitHub Actions Terraform role |
| `terraform/dns/` | Route 53 hosted zone, DNSSEC configuration, query-logging resources, and Cloudflare delegation |

The main infrastructure and DNS configurations use separate state keys in the S3 state bucket, with native state locking configured. The bootstrap configuration manages the state-backend infrastructure.

The DNS root is not automatically applied by the main platform deployment workflow. DNS zone creation and Cloudflare delegation therefore require a separate operation.

Keep each Terraform root's state separate and use the corresponding configuration when planning or applying changes.

## Infrastructure modules

| Module | Responsibility |
|---|---|
| `vpc` | VPC, public and private subnets, routing, NAT Gateway, and VPC Flow Logs |
| `eks` | EKS cluster, managed node group, OIDC provider, and cluster-related configuration |
| `iam` | IAM roles and policies for the cluster, nodes, workload identity, and automation |
| `kms` | Customer-managed encryption keys |
| `ecr` | Container image repositories |
| `sqs` | Orders queue and dead-letter queue |
| `secrets` | AWS Secrets Manager resources |
| `argocd` | Argo CD Helm installation |
| `karpenter` | Karpenter controller and supporting IAM and node configuration |

### Networking

The VPC module creates public and private subnets with separate route tables.

- Public subnets route internet traffic through an Internet Gateway.
- Private subnets route outbound internet traffic through a NAT Gateway.
- VPC Flow Logs capture accepted and rejected traffic and deliver records to CloudWatch Logs.
- Private subnets carry tags for Karpenter discovery.

The configuration uses a single NAT Gateway as a cost-saving choice for this portfolio project. This trades availability across Availability Zones for lower infrastructure cost.

### EKS and platform components

The main Terraform root provisions EKS and supporting infrastructure, including IAM and encryption resources.

Terraform-managed Helm releases include:

- AWS Load Balancer Controller
- Argo CD
- External Secrets
- cert-manager
- ExternalDNS
- Traefik
- Metrics Server
- Karpenter

Installing a controller does not automatically establish that every custom resource it needs is being reconciled. The Karpenter `NodePool` and `EC2NodeClass` manifests are present separately from the controller installation.

## Kubernetes and GitOps

The platform uses Argo CD's App-of-Apps pattern to manage Kubernetes resources from Git.

The root Application tracks the `stable-v1.31` revision and loads child Applications for the application environments and supporting platform components.

The application manifests follow a base-and-overlay structure:

- `terraform/infrastructure/application/base/` contains shared application resources.
- `terraform/infrastructure/application/overlays/dev/` contains development-specific configuration.
- `terraform/infrastructure/application/overlays/prod/` contains production-specific configuration.

Production synchronization is configured as manual. The reviewed dev and prod Applications target the same Kubernetes namespace and share underlying resources, so they should not be treated as isolated environments.

The deployment script applies the root Application and creates an `application-config` ConfigMap containing the SQS queue URL. This ConfigMap is supplied outside the application Kustomize resources.

### Resource ownership

| Component | Management mechanism |
|---|---|
| AWS infrastructure and selected Helm releases | Terraform |
| Argo CD root Application | Applied by deployment script |
| Application and platform child Applications | Argo CD |
| Deployments, Services, HPAs, and related manifests | Argo CD and Kustomize |
| DNS records | ExternalDNS |
| Certificate issuance and renewal | cert-manager |
| External Kubernetes Secrets | External Secrets |
| EBS volumes and snapshots | EBS CSI and snapshot components |
| Dynamic compute capacity | Karpenter, when its configuration is present and reconciled |

## Application services

Each service has its own Go source, module definition, and Dockerfile under `services/`.

| Service | Port | Responsibility |
|---|---:|---|
| `api-gateway` | 8080 | HTTP entry point and routing to backend services |
| `order-service` | 8081 | Order operations and order-event publishing |
| `inventory-service` | 8082 | Product and inventory reservation operations |
| `payment-service` | 8083 | Payment-related operations and event publishing |
| `notification-service` | 8084 | Notification templates and history |
| `shipping-service` | 8085 | Shipment operations and carrier webhook |
| `worker` | 8090 | SQS message consumption |
| `scheduler` | 8091 | Periodic background jobs |
| `dashboard-api` | 8086 | Dashboard data and static dashboard content |

The HTTP-facing services have readiness and liveness probes, with horizontal pod autoscaling where configured. The worker and scheduler use fixed two-replica Deployments in the reviewed configuration.

### Data and messaging

PostgreSQL is the shared relational database for services that require persistent relational data. Redis supports gateway rate limiting. Amazon SQS provides asynchronous messaging through the orders queue and dead-letter queue.

The deployment configuration supplies the queue URL through the `application-config` ConfigMap. Producer and consumer workloads use Kubernetes service accounts configured for their AWS permissions.

These definitions describe the intended integration points; end-to-end business workflows require application-level testing to establish that they behave as expected.

## Storage and disaster recovery

PostgreSQL runs as a single-replica StatefulSet backed by EBS storage. Its reviewed persistent volume configuration references a specific EBS volume and Availability Zone and uses a retention-oriented lifecycle.

Redis runs as a single replica with persistent storage configured separately.

Storage and recovery resources include:

- EBS-backed StorageClasses.
- A VolumeSnapshotClass.
- PostgreSQL snapshot and restore manifests.
- Snapshot installation and uninstallation scripts.
- The runbook at `docs/storage-restore.md`.

The repository contains snapshot and restore resources, but these do not establish an automatically scheduled backup service or prove a successful current recovery. A measured recovery time objective (RTO), recovery point objective (RPO), and data-integrity results require separate evidence.

The static PostgreSQL volume configuration also depends on the referenced EBS volume being available in the expected Availability Zone.

## Monitoring and observability

The monitoring configuration includes Prometheus, Grafana, ServiceMonitors, PrometheusRules, and dashboard definitions.

The deployment script checks for monitoring resources and waits for selected Prometheus and Grafana workloads.

The repository defines alert rules. Runtime validation is needed to confirm target scraping, alert evaluation, dashboard availability, and notification delivery.

## Container images and CI/CD

The application CI workflow builds the nine service images, runs scanning steps, pushes commit-SHA image tags, and updates Kubernetes image references.

The GitOps handoff depends on the branch containing the manifest changes. Argo CD tracks `stable-v1.31`; a successful build on another branch does not, by itself, mean that Argo CD will deploy those changes.

The repository also contains a separate Compose/LocalStack setup for an older local application stack. `terraform/scripts/localstack-init.sh` creates an SQS queue named `orders` through LocalStack. This local setup is separate from the nine-service EKS deployment.

## Deployment and validation

The operational scripts are documented in [`scripts/README.md`](scripts/README.md).

### Prerequisites

The deployment and destruction workflows require:

- Terraform
- AWS CLI
- `kubectl`
- Helm
- `curl`

The AWS CLI must be configured with credentials that can access the intended account. Git is also useful for reviewing the repository and its deployment history.

The scripts use the `eu-west-2` region and the `jenkins-eks` cluster name in their current configuration.

### Deploy

Run from the repository root:

bash terraform/scripts/deploy.sh

The deployment workflow:

1. Checks prerequisites, AWS identity, Terraform formatting, and configuration validity.
2. Checks for eligible existing ECR repositories and a VPC flow-log group, importing resources into Terraform state where necessary.
3. Creates and presents a bootstrap plan for review and confirmation.
4. Applies the bootstrap infrastructure and configures Kubernetes access.
5. Creates and presents the full platform plan for review and confirmation, then applies it.
6. Waits for selected platform components and Argo CD applications.
7. Waits for application and monitoring workloads.
8. Checks DNS records, ExternalDNS ownership, load balancer targeting, public DNS resolution, and HTTPS response.

Some eligible existing resources can be imported into Terraform state before the plan approval prompts. Review the AWS account, current state, and planned operations before approving deployment.

### Check Argo CD

bash terraform/scripts/check-argocd.sh

This reports discovered applications and checks synchronization and health according to the script's rules. It does not independently prove that every expected application exists or that every business workflow works correctly.

### Destroy

bash terraform/scripts/destroy.sh

The destruction workflow requires explicit confirmation, performs selected Kubernetes and AWS cleanup, generates a Terraform destroy plan, and requests confirmation before applying it.

The ECR repositories and images are intentionally retained by the reviewed workflow. The separate DNS Terraform root is not automatically destroyed by the main platform teardown.

The script checks selected resource categories after teardown. A successful run should not be interpreted as a universal guarantee that every potentially billable AWS resource has been removed.

### Validation status

Terraform resources, Kubernetes manifests, CI workflows, and operational scripts define the intended implementation. Actual deployment health and integration behaviour require evidence from CI runs, Terraform plans and applies, Kubernetes and Argo CD status, AWS resource inspection, and application-level tests.

## Screenshots

Screenshots provide visual context for the deployment and operational workflow. Review them against the current architecture before treating them as evidence of the present implementation.

### Successful deployment

![Deployment](../screenshots/deploy-successful.png)

### Platform verification

![Platform verification](../screenshots/services.png)

### Successful cleanup

![Cleanup](../screenshots/destroy-successful.png)

## Lessons learned

This project reinforces several DevOps engineering principles:

- Infrastructure should be reproducible and managed through version-controlled configuration.
- Small, modular Terraform modules are easier to maintain than large monolithic configurations.
- Deployment workflows should include plan review and post-deployment validation.
- Infrastructure provisioning and application reconciliation have distinct responsibilities.
- GitOps requires clear ownership of resources and an explicit source revision.
- Persistent storage and disaster recovery require restore verification, not just resource definitions.
- Automated cleanup is important for controlling cloud costs.
- Building, breaking, debugging, and rebuilding infrastructure provides deeper understanding than following tutorials alone.

## Further documentation

- [`scripts/README.md`](scripts/README.md) — deployment, validation, destruction, and LocalStack helper scripts.
- [`docs/secrets-rotation.md`](../docs/secrets-rotation.md) — secret synchronization and rotation workflow.
- [`docs/storage-restore.md`](../docs/storage-restore.md) — persistent storage and restoration workflow.
- `infrastructure/argocd/applications/` — child Argo CD Application definitions.
- `infrastructure/application/` — application base and environment overlays.

## License

This project is released under the MIT License.

## Key skills demonstrated

- Terraform Infrastructure as Code
- Amazon Web Services and Amazon EKS
- Kubernetes and Kustomize
- Docker and Go microservices
- GitOps with Argo CD
- AWS IAM, IRSA, and OIDC
- Cloud networking and load balancing
- Persistent storage and recovery workflows
- Amazon SQS and asynchronous messaging
- Prometheus and Grafana
- Bash scripting and infrastructure automation
- Git and GitHub Actions
- Technical documentation
