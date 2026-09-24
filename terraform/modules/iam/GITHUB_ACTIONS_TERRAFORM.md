cat > modules/iam/GITHUB_ACTIONS_TERRAFORM.md <<'EOF'
# GitHub Actions Terraform IAM Role

## Purpose

This file defines the dedicated IAM role and IAM policy document
used by GitHub Actions to run Terraform against AWS infrastructure.

The role is intentionally separate from the application CI role so
that application builds and infrastructure deployments have different
permission boundaries.

## Authentication

GitHub Actions does not use long-lived AWS access keys.

The intended authentication flow is:

GitHub Actions
↓
GitHub OIDC
↓
AWS IAM OIDC Provider
↓
github-actions-terraform-role

The role reuses the existing GitHub OIDC provider and trust policy
defined by the IAM module.

## Why this is separate from the application role

The existing `github-actions-oidc-role` is intentionally limited
to ECR operations for the application CI pipeline.

The Terraform role is separate because infrastructure deployment
requires broader AWS permissions.

This prevents the application CI role from automatically gaining
the permissions required to create, modify, or destroy AWS
infrastructure.

## EKS Access

The Terraform role is also granted Kubernetes access through the
EKS access configuration defined in `modules/eks/main.tf`.

The EKS configuration uses:

- `aws_eks_access_entry`
- EKS authentication mode `API_AND_CONFIG_MAP`
- `AmazonEKSClusterAdminPolicy`
- cluster-wide access scope

Cluster-wide Kubernetes access is required because Terraform manages
cluster-level platform resources, including Helm releases, CRDs,
RBAC resources, networking components, monitoring, and GitOps
components.

The EKS access configuration does not add the role to the Kubernetes
`system:masters` group. Instead, access is granted through the
Amazon EKS access-entry and access-policy mechanisms.

## Terraform State

Terraform uses the S3 backend:

- Bucket: `mudassir-tf-state-893061519920`
- State object: `jenkins/terraform.tfstate`
- Lock object: `jenkins/terraform.tfstate.tflock`

The role can:

- list the Terraform state bucket
- read the state object
- write the state object
- read the lock object
- create/update the lock object
- delete the lock object when releasing a Terraform lock

The role cannot delete the Terraform state object itself.

This protects the state file while still allowing normal Terraform
state management and lock handling.

## AWS Permissions

The policy document is divided into separate statements so that each
permission group has a clear purpose.

### TerraformStateBucket

Allows:

- `s3:ListBucket`

This is scoped to the Terraform state bucket.

### TerraformStateObjects

Allows:

- `s3:GetObject`
- `s3:PutObject`

This is scoped to the Terraform state object.

### TerraformStateLock

Allows:

- `s3:GetObject`
- `s3:PutObject`
- `s3:DeleteObject`

This is scoped only to the Terraform `.tflock` object.

Deleting the lock object is required when Terraform releases its
state lock. This does not grant permission to delete the state file.

### EKSAccess

Allows:

- `eks:DescribeCluster`
- `eks:AccessKubernetesApi`

These permissions allow the Terraform deployment role to discover
the EKS cluster and communicate with the Kubernetes API.

### PassEksServiceRoles

Allows:

- `iam:PassRole`

The permission is restricted to the EKS cluster and node-group
service roles:

- `jenkins-eks-cluster-role`
- `jenkins-node-group-role`

The role is therefore not granted unrestricted `iam:PassRole`.

### ManageEksInfrastructure

Provides permissions required to manage:

- EKS clusters
- managed node groups
- EKS add-ons
- EKS access entries
- EKS access-policy associations

The permissions are scoped to the `jenkins-eks` cluster and its
associated EKS resources where supported by the AWS API.

### ManageNetworking

Provides permissions required to manage the Terraform-managed
networking infrastructure, including:

- VPCs
- subnets
- internet gateways
- route tables
- NAT gateways
- Elastic IP addresses
- EC2 resource tags

The EC2 networking APIs in this statement use `"*"` resources because
the AWS API authorization model for these operations does not provide
useful resource-level scoping for every action.

## Current Implementation State

This file currently defines:

1. The `github-actions-terraform-role`
2. The IAM policy document containing the Terraform permissions

The IAM policy document is attached to the role through the
`aws_iam_role_policy_attachment.github_actions_terraform` resource.

The EKS access entry and EKS access-policy association are defined
separately in `modules/eks/main.tf`.

## Security Design

The design intentionally uses:

- GitHub OIDC instead of static AWS credentials
- separate application and infrastructure IAM roles
- resource-scoped permissions where practical
- a dedicated Terraform deployment role
- restricted `iam:PassRole`
- protected Terraform state
- EKS access policies instead of `system:masters`

The Terraform role does not use unrestricted
`AdministratorAccess`.

## Important Limitation

`terraform validate` verifies Terraform configuration syntax, but
does not prove that every AWS API action and resource combination
will be accepted by IAM or the AWS API.

The permissions therefore need to be verified with an actual
Terraform plan and, where appropriate, an apply.

The plan is particularly important for detecting AWS IAM
action/resource combinations that are syntactically valid Terraform
but invalid for the corresponding AWS API.

## Change Management

Changes to this role should be reviewed carefully because the role
controls infrastructure deployment.

When adding a new Terraform-managed AWS resource, its required IAM
permissions should be added deliberately rather than broadening the
role with unrestricted permissions.
EOF