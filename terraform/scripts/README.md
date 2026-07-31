# Deployment Scripts

## Purpose

The deployment scripts provide a consistent, repeatable way to create and
destroy the complete Jenkins on Amazon EKS environment.

They automate infrastructure provisioning, Kubernetes deployment and
validation while following Infrastructure as Code (IaC) best practices.

This directory contains automation scripts used to deploy and destroy the Jenkins EKS environment.

## deploy.sh

Deploys the complete Jenkins platform by provisioning AWS infrastructure
with Terraform before configuring Kubernetes resources required for the
application.

### What it does

- Verifies required tools are installed.
- Verifies AWS authentication.
- Validates Terraform configuration.
- Creates and reviews a Terraform execution plan
- Applies the approved Terraform plan.
- Configures kubectl.
- Deploys Jenkins resources.
- Waits for workloads to become ready.
- Creates the Ingress.
- Verifies the deployment.

Run with:

```bash
./deploy.sh
```

---

## destroy.sh

Removes Kubernetes workloads before destroying the underlying AWS
infrastructure to ensure cloud resources are released cleanly.

### What it does

- Verifies required tools are installed
- Verifies AWS authentication
- Removes Kubernetes resources
- Waits for AWS resources to clean up
- Creates a Terraform destroy plan
- Destroys infrastructure
- Verifies AWS cleanup

Run with:

```bash
./destroy.sh
```

---

## Design Principles

Both scripts follow the same engineering principles:

- Validate prerequisites before making infrastructure changes.
- Require an execution plan before infrastructure changes.
- Fail fast on errors
- Group related operations into logical stages
- Verify successful completion
- Use reusable helper functions
- Centralise configurable values
- Infrastructure created by Terraform is destroyed by Terraform.
- Avoid manual intervention wherever possible.

## Expected Workflow

1. Configure AWS credentials.
2. Run `./deploy.sh`.
3. Verify Jenkins is accessible.
4. Run `./destroy.sh` when finished to minimise AWS costs.