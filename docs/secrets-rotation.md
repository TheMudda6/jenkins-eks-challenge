# Secrets Rotation

## Overview

Application secrets are stored in **AWS Secrets Manager** rather than directly in Git.

The Kubernetes platform retrieves those secrets through **External Secrets**, which uses IRSA to authenticate to AWS.

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

## Rotation Flow

Secret rotation follows this process:

1. Update the secret value in AWS Secrets Manager.
2. External Secrets retrieves the updated value.
3. The corresponding Kubernetes Secret is updated.
4. Verify that the ExternalSecret reports a successful synchronization.
5. Verify that the affected workload is healthy.
6. Restart the affected workload if required by the application's secret-consumption model.

Secrets must not be committed to Git or placed directly into Kubernetes manifests.

## AWS Permissions

The External Secrets IAM role is restricted to the required AWS Secrets Manager operations.

The role also has `kms:Decrypt` permission for the KMS key used to encrypt the secrets.

IRSA provides the Kubernetes ServiceAccount with AWS credentials without requiring static AWS access keys.

## Validation

During live deployment validation, an External Secrets IRSA lifecycle issue was identified.

A newly created test pod using the External Secrets ServiceAccount received:

```text
AWS_ROLE_ARN
AWS_WEB_IDENTITY_TOKEN_FILE
aws-iam-token
```

This confirmed that the IRSA webhook was correctly injecting the AWS identity information into newly created pods.

The External Secrets controller was restarted and the IAM configuration was updated through Terraform to include the required KMS decrypt permission.

After the correction, the PostgreSQL ExternalSecret successfully synchronized and PostgreSQL became ready.

## Security Rules

- Never commit secret values to Git.
- Never place secret values directly in Kubernetes manifests.
- Use AWS Secrets Manager as the source of truth.
- Use IRSA rather than static AWS credentials.
- Restrict IAM permissions to the resources and actions required.
- Protect the KMS key used to encrypt secrets.
- Remove exposed credentials immediately if they appear in logs, screenshots, or command output.
