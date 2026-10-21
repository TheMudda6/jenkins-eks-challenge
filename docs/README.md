# Operational Documentation

This directory contains operational guides for managing application secrets and recovering persistent PostgreSQL storage in the EKS platform.

## Available Guides

### 1. Secrets Rotation

**Guide:** [secrets-rotation.md](secrets-rotation.md)

Documents how application secrets are managed through AWS Secrets Manager and synchronized into Kubernetes using External Secrets and IAM Roles for Service Accounts (IRSA).

Topics include:

- Secret rotation and synchronization flow.
- AWS Secrets Manager and KMS permissions.
- IRSA authentication without static AWS access keys.
- Validating ExternalSecret synchronization and workload health.
- Troubleshooting the External Secrets controller's AWS identity and KMS permissions.
- Security rules for handling exposed credentials.

The guide also records a deployment-validation issue involving the External Secrets controller and the subsequent correction to its IAM permissions.

**Use this guide when:** rotating application credentials, troubleshooting secret synchronization, or reviewing the platform's secrets-management practices.

### 2. Storage and PostgreSQL Restore

**Guide:** [storage-restore.md](storage-restore.md)

Documents persistent storage configuration and the PostgreSQL snapshot-and-restore workflow.

Topics include:

- EBS CSI driver and StorageClass configuration.
- PostgreSQL 16.9 and its 20 GiB `gp3-retain` persistent volume.
- EBS volume snapshots and restoration into a persistent volume claim.
- Validating restored data.
- Restore testing completed during project validation.
- Retained EBS volumes that may survive Kubernetes resource or EKS cluster destruction.

**Use this guide when:** recovering PostgreSQL data, validating a restore, or investigating persistent volumes that remain after infrastructure resources are removed.

## Operational Principles

- **Protect credentials:** never commit secret values to Git or place them directly in Kubernetes manifests.
- **Use least privilege:** restrict AWS permissions to the required resources and actions.
- **Validate synchronization:** verify ExternalSecret status and workload health after secret changes.
- **Test recovery:** the existence of a snapshot alone does not guarantee successful recovery.
- **Understand retention:** retained EBS volumes may outlive the Kubernetes resources or cluster that originally used them.
- **Review before deletion:** retained volumes may contain recoverable database data and should be assessed before removal.
- **Verify outcomes:** confirm that synchronization, restoration, and workload health checks succeed before considering a procedure complete.

## Scope

These guides cover secrets rotation and persistent storage recovery. They complement, rather than replace, the Terraform configuration, Kubernetes manifests, and deployment workflows that implement the platform.

For the overall architecture, deployment process, and CI/CD workflows, start with the [project README](../README.md).