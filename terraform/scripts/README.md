# Terraform Scripts

This directory contains helper scripts for deploying, validating, and destroying the Jenkins-on-EKS infrastructure, checking Argo CD application health, and initializing a local SQS queue through LocalStack.

The scripts support a repeatable infrastructure lifecycle while providing validation, diagnostic output, and explicit confirmation steps for operations that can create or destroy AWS resources.

## Scripts

| Script | Purpose |
|---|---|
| `deploy.sh` | Validates prerequisites, provisions the infrastructure in stages, waits for platform and application components, and checks DNS and HTTPS connectivity. |
| `destroy.sh` | Removes managed platform resources, runs a Terraform destroy plan, and verifies that selected AWS resources have been cleaned up. |
| `check-argocd.sh` | Reports Argo CD application status and checks synchronization and health, allowing for the intentionally manual production application. |
| `localstack-init.sh` | Creates the `orders` SQS queue in a running LocalStack environment. |

## Prerequisites

### Infrastructure deployment and destruction

The deployment and destruction scripts require the following tools:

- Terraform
- AWS CLI
- `kubectl`
- Helm
- `curl`

The AWS CLI must be configured with credentials that can access the target AWS account. The scripts check the active AWS identity before proceeding.

The scripts use the `eu-west-2` AWS region and the EKS cluster name `jenkins-eks`.

Before running either script, review the Terraform configuration, confirm the AWS account and region, and understand which resources may be created, removed, or retained.

### Argo CD validation

`check-argocd.sh` requires `kubectl` access to the target cluster and an available Argo CD installation.

### LocalStack initialization

`localstack-init.sh` requires `awslocal` and a running, reachable LocalStack environment configured to accept SQS requests.

## Usage

Run the scripts from the repository root.

### Deploy the platform

bash terraform/scripts/deploy.sh

The deployment workflow:

1. Checks required tools, AWS access, Terraform formatting, and Terraform configuration validity.
2. Checks for existing ECR repositories and a VPC flow-log group, importing eligible existing resources into Terraform state where necessary.
3. Creates and presents a targeted bootstrap plan for review and confirmation.
4. Applies the bootstrap infrastructure and configures local Kubernetes access.
5. Creates and presents the full platform plan for review and confirmation, then applies it.
6. Waits for platform components, storage, Argo CD applications, application deployments, and monitoring components.
7. Checks the Jenkins hostname's Route 53 records, ExternalDNS ownership TXT record, load balancer target, public DNS resolution, and HTTPS response.
8. Prints diagnostic information if the final checks fail.

The script uses separate bootstrap and platform Terraform plans because some resources must exist before the Kubernetes and Helm providers can operate against the cluster.

**Important:** The script can import existing resources into Terraform state before the plan approval prompts. Review the script and current state before running it.

### Check Argo CD

bash terraform/scripts/check-argocd.sh

The script displays discovered Argo CD applications and their synchronization and health statuses.

- `platform-root` must be Healthy; it may be OutOfSync.
- `e-commerce-prod` is intentionally allowed to be OutOfSync because production synchronization is manual.
- Other discovered applications are expected to be Synced and Healthy.

This check evaluates the applications it discovers. It does not independently prove that every expected application exists; the deployment script separately checks for its expected application set.

### Destroy the platform

bash terraform/scripts/destroy.sh

The destruction workflow:

1. Checks prerequisites, AWS identity, and Terraform configuration validity.
2. Requires explicit confirmation before continuing.
3. Attempts to remove the Argo CD root and child applications.
4. Performs selected Helm and load balancer cleanup and removes selected resources from Terraform state where required.
5. Creates a Terraform destroy plan and requests a second confirmation before applying it.
6. Checks the resulting AWS environment for selected leftover resources, including EKS, VPC, load balancers, log groups, SQS queues, security groups, NAT gateways, and NAT Elastic IP allocations.

**Important:** This is not a universal cleanup of every resource that could incur AWS charges. The script intentionally preserves ECR repositories and their images by removing those repositories from Terraform state before the destroy plan. The DNS configuration also has a separate Terraform state, so destroying the main infrastructure does not necessarily destroy the DNS stack.

Review the destroy plan carefully before approving it. Ensure any data, snapshots, retained volumes, and other resources you want to keep are accounted for.

### Initialize LocalStack

bash terraform/scripts/localstack-init.sh

The script creates an SQS queue named `orders` using `awslocal`. It does not configure the wider application environment or verify that the queue is usable by the application.

## Validation and diagnostics

The scripts provide different levels of validation:

- **Terraform:** formatting and configuration validation, followed by plan review and apply.
- **Kubernetes:** readiness checks for selected platform components and application workloads.
- **Argo CD:** application synchronization and health checks.
- **DNS and HTTPS:** checks for the Jenkins hostname's DNS records, ExternalDNS ownership, load balancer target, and HTTPS response.
- **Destruction:** checks for selected infrastructure resources remaining after teardown.

A successful script run should not be interpreted as proof that every application integration, security control, disaster-recovery procedure, or AWS resource has been independently validated.

## Operational notes

- The scripts target a Jenkins-named environment, including the `jenkins-eks` cluster and `jenkins.mud-as-sir.uk` hostname, even though the application layer contains the e-commerce services.
- The deploy and destroy workflows include explicit approval gates, but some preparatory operations occur before those gates.
- The destroy workflow has special handling for selected resources that can outlive or interfere with Terraform-managed teardown.
- The LocalStack initialization script is separate from the AWS infrastructure deployment workflow.
- Run these scripts only when the target environment and intended operation are understood.
