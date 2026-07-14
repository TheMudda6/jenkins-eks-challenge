# Deployment Scripts

This directory contains automation scripts used to deploy and destroy the Jenkins EKS environment.

## deploy.sh

Deploys the complete environment from scratch.

### What it does

- Verifies required tools are installed
- Verifies AWS authentication
- Validates Terraform configuration
- Creates a Terraform execution plan
- Applies the approved Terraform plan
- Configures kubectl
- Deploys Jenkins resources
- Waits for workloads to become ready
- Creates the Ingress
- Verifies the deployment

Run with:

```bash
./deploy.sh
```

---

## destroy.sh

Safely removes the complete environment.

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

- Validate before making changes
- Review Terraform plans before applying
- Fail fast on errors
- Group related operations into logical stages
- Verify successful completion
- Use reusable helper functions
- Centralise configurable values