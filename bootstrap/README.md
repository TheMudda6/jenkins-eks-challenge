# Bootstrap Infrastructure

## Purpose

The `bootstrap/` directory contains Terraform configuration for establishing the AWS resources and permissions required by the project's Terraform and GitHub Actions workflows.

It has two main responsibilities:

1. **Terraform state storage** — provisions an S3 bucket for Terraform state with versioning, server-side encryption, and public-access protections.
2. **GitHub Actions authentication and permissions** — configures GitHub's OpenID Connect (OIDC) integration with AWS and defines the IAM role used by GitHub Actions for Terraform operations.

## Directory Structure

| File | Purpose |
|---|---|
| `main.tf` | Defines the Terraform state bucket, its security controls, and the S3 backend configuration. |
| `github_actions.tf` | Defines the GitHub OIDC provider, IAM trust policy, Terraform role, permissions policy, and policy attachment. |
| `providers.tf` | Configures the AWS provider to use `eu-west-2`. |
| `versions.tf` | Declares the Terraform version requirement and AWS provider version constraint. |
| `GITHUB_ACTIONS_TERRAFORM.md` | Documents the GitHub Actions Terraform IAM role, authentication, permissions, security design, and limitations. |

## Terraform State Storage

The configuration in `main.tf` manages the S3 bucket used for Terraform state.

| Setting | Configuration |
|---|---|
| Bucket name | `mudassir-tf-state-893061519920` |
| AWS region | `eu-west-2` |
| State key | `bootstrap/terraform.tfstate` |
| State locking | Native S3 lockfile (`use_lockfile = true`) |
| Versioning | Enabled |
| Server-side encryption | AES-256 |
| Public access | All four S3 public-access-block settings enabled |
| Object ownership | `BucketOwnerEnforced` |

These settings provide versioned state storage, encryption at rest, public-access restrictions, and native Terraform state locking.

**Important:** The S3 backend must already exist before Terraform can initialize against it. Bootstrap therefore requires careful handling during initial setup and recovery; do not assume the backend can create itself before it is available.

## GitHub Actions and AWS IAM

The configuration in `github_actions.tf` establishes the identity and permissions used by GitHub Actions to authenticate to AWS without relying on long-lived access keys.

The configuration includes:

- An AWS IAM OIDC identity provider for GitHub.
- An IAM assume-role policy document defining the trust relationship.
- An IAM role named `github_actions_terraform`.
- A permissions policy for Terraform operations.
- An attachment connecting the permissions policy to the role.

The exact trust conditions, AWS permissions, EKS access configuration, and documented limitations are covered in [GITHUB_ACTIONS_TERRAFORM.md](GITHUB_ACTIONS_TERRAFORM.md).

Review that guide alongside the Terraform configuration before changing the role's trust relationship or permissions.

## Prerequisites

The configuration declares the following requirements:

- Terraform `>= 1.5.0`.
- AWS provider `~> 5.0`.
- AWS access sufficient to create or manage the resources defined in this directory.
- The configured AWS region: `eu-west-2`.
- An existing S3 backend bucket before initializing Terraform with the configured backend.

The caller's AWS permissions must be sufficient for the resources being managed. The exact requirements depend on the operations being performed and are documented in the IAM guide.

## Working With This Configuration

Run Terraform commands from the `bootstrap/` directory.

Initialize the backend and providers:

terraform init

Format-check the configuration:

terraform fmt -check

Validate the configuration:

terraform validate

Before making changes, inspect the Terraform configuration and review the proposed changes with a plan. Do not apply changes until the plan has been reviewed and approved.

Because this directory manages foundational state storage and CI authentication, changes can affect other Terraform workflows. Treat backend, IAM trust, and permission changes as infrastructure changes requiring explicit review.

## State and Generated Files

Terraform can generate local working files and state-related artifacts while operating in this directory. These may contain sensitive infrastructure information or implementation details.

Do not commit local Terraform state files, backups, saved plans, or the `.terraform/` working directory to version control. Keep only the configuration, documentation, and deliberately maintained dependency lock file under source control.

## Related Documentation

- [GitHub Actions Terraform IAM Role](GITHUB_ACTIONS_TERRAFORM.md) — detailed authentication, role permissions, EKS access, state access, security considerations, and change management.