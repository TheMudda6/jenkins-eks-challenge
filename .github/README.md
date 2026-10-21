# GitHub Actions

This directory contains the GitHub Actions workflows used to validate the repository, test and publish the application services, validate Kubernetes manifests, and deploy the AWS infrastructure.

The workflows provide automated quality checks and deployment automation for the E-Commerce Platform hosted on Amazon EKS.

## Directory structure

.github/
└── workflows/
    ├── application-ci.yml
    ├── kubernetes-validation.yaml
    ├── terraform-deploy.yml
    └── validate.yaml

## Workflows

### 1. Application CI

**File:** `workflows/application-ci.yml`

Builds and validates the nine Go microservices:

- API Gateway
- Order Service
- Inventory Service
- Payment Service
- Notification Service
- Shipping Service
- Dashboard API
- Scheduler
- Worker

The workflow uses matrix jobs to lint and test each service independently. It then scans source and container images with Trivy, builds Docker images, and publishes images to Amazon ECR on push events.

Published images use the Git commit SHA as their tag. The workflow subsequently updates the Kubernetes Deployment manifests and validates the Kustomize base and development and production overlays.

flowchart TD
    A[Push or Pull Request] --> B[Lint Services]
    B --> C[Test and Build Services]
    C --> D[Trivy Source Scan]
    D --> E[Build Docker Images]
    E --> F[Trivy Image Scan]
    F --> G{Push Event?}
    G -- Yes --> H[Authenticate to AWS]
    H --> I[Push Images to ECR]
    I --> J[Update Kubernetes Image Tags]
    J --> K[Validate Kustomize]
    K --> L[Commit Manifest Updates]
    G -- No --> M[CI Checks Only]

AWS authentication uses GitHub Actions OIDC and the configured `AWS_ROLE_ARN` secret. The workflow also uses the repository's `AWS_REGION` variable.

### 2. Kubernetes Manifest Validation

**File:** `workflows/kubernetes-validation.yaml`

Validates Kubernetes configuration by:

- Checking for the deprecated External Secrets API version `external-secrets.io/v1beta1`.
- Rendering the platform manifests with Kustomize.
- Rendering the production application overlay.
- Validating the rendered resources with Kubeconform against Kubernetes 1.33 schemas.

This workflow helps catch manifest and schema errors before configuration changes are deployed.

### 3. Terraform Deployment

**File:** `workflows/terraform-deploy.yml`

Automates Terraform deployment for the AWS platform. The workflow is triggered by changes under `terraform/` or changes to its own workflow on the `stable-v1.31` branch. It can also be started manually.

The pipeline separates infrastructure provisioning into stages:

1. Initialize Terraform and prepare the bootstrap plan.
2. Apply the bootstrap plan through the configured GitHub Actions environment.
3. Prepare the platform plan using the EKS connection details.
4. Continue through the platform deployment stages defined in the workflow.

AWS authentication uses GitHub Actions OIDC. Terraform inputs are supplied through repository variables and secrets.

**Operational warning:** this workflow can create or modify AWS resources and may incur charges. Review its plan, environment protection rules, variables, and secrets before running it.

### 4. Infrastructure Validation

**File:** `workflows/validate.yaml`

Runs infrastructure quality and security checks:

- Terraform formatting with `terraform fmt -check`.
- Terraform initialization and validation.
- TFLint.
- Checkov Terraform security scanning.
- ShellCheck against scripts in `terraform/scripts/`.

This workflow is designed to detect configuration, security, and shell-script issues before infrastructure changes are accepted.

## Workflow relationships

The workflows have distinct responsibilities:

flowchart LR
    A[Repository Change] --> B[Infrastructure Validation]
    A --> C[Kubernetes Validation]
    A --> D[Application CI]
    A --> E[Terraform Deployment]

    B --> F[Terraform and Shell Checks]
    C --> G[Kustomize and Schema Checks]
    D --> H[Service Tests and Container Images]
    E --> I[AWS Infrastructure Changes]

The exact triggers and job dependencies are defined in each workflow file. A workflow appearing in this diagram does not imply that another workflow automatically waits for it unless that dependency is explicitly configured.

## Repository configuration

Depending on the workflow, the repository may require the following configuration.

| Configuration | Purpose |
|---|---|
| `AWS_REGION` variable | AWS region used by Application CI. |
| `AWS_ROLE_ARN` secret | IAM role assumed by Application CI through OIDC. |
| `AWS_TERRAFORM_ROLE_ARN` variable | IAM role assumed by Terraform Deployment. |
| `TF_*` variables | Terraform environment, network, cluster, IAM and platform settings. |
| `TF_POSTGRES_PASSWORD` secret | PostgreSQL password supplied to Terraform. |
| `TF_GRAFANA_PASSWORD` secret | Grafana password supplied to Terraform. |
| `terraform-production` environment | Environment used by Terraform apply jobs. |

Use the workflow files as the authoritative source for the exact names and required values. Never commit credentials, API tokens, or unredacted secrets to the repository.

## Troubleshooting

### Application CI fails

1. Open the failed job in the GitHub Actions run.
2. Identify the service in the matrix job name.
3. Review lint, test, or Trivy output.
4. Fix the service or image issue and rerun the workflow.

### Kubernetes validation fails

1. Check the External Secrets API version check.
2. Inspect Kustomize rendering errors.
3. Review Kubeconform output for schema violations or missing schemas.

### Terraform validation fails

1. Run `terraform fmt -check -recursive terraform`.
2. Run Terraform initialization and validation from the `terraform/` directory.
3. Review TFLint and Checkov findings.
4. Run ShellCheck on the affected scripts.

### Terraform deployment fails

1. Inspect the failed stage and Terraform logs.
2. Verify the required GitHub variables, secrets, OIDC trust, and IAM permissions.
3. Review the Terraform plan and state before retrying an apply.
4. Avoid repeatedly rerunning failed apply jobs without understanding the cause.

## Maintenance

When adding or changing a workflow:

- Keep triggers and branch filters explicit.
- Use OIDC instead of long-lived AWS access keys where supported.
- Pin or deliberately manage action and tool versions.
- Keep secrets in GitHub's secret store.
- Review deployment permissions and plan/apply boundaries.
- Update this README when workflow responsibilities change.
