# Storage and PostgreSQL Restore

## Overview

Persistent application data is stored using the AWS EBS CSI driver.

The platform provides:

- `gp3` StorageClass
- `gp3-retain` StorageClass
- EBS CSI driver
- VolumeSnapshotClass
- PostgreSQL snapshot manifests
- PostgreSQL restore manifests
- Restore test workflow

PostgreSQL uses a `20Gi` persistent volume with the `gp3-retain` StorageClass.

## PostgreSQL Storage

PostgreSQL is deployed as a StatefulSet using:

```text
PostgreSQL 16.9
20Gi PVC
gp3-retain
PGDATA=/var/lib/postgresql/data/pgdata
```

The `Retain` reclaim policy is intentional for the PostgreSQL data volume.

Deleting the Kubernetes PVC does not automatically mean that the underlying EBS volume should be discarded.

## Snapshot and Restore

The project contains Kubernetes manifests for PostgreSQL snapshot and restore operations.

The recovery workflow is:

```text
Running PostgreSQL
        |
        v
EBS VolumeSnapshot
        |
        v
Snapshot retained
        |
        v
Restore PVC from snapshot
        |
        v
PostgreSQL StatefulSet
        |
        v
Validate restored data
```

The snapshot and restore resources are managed as Kubernetes manifests so that the recovery process is repeatable.

## Restore Testing

PostgreSQL restore testing was completed during project validation.

The restore process was validated using the project's snapshot/restore resources and a test workload.

The test confirmed that PostgreSQL storage could be restored from the snapshot workflow rather than relying solely on an untested recovery procedure.

## Operational Considerations

The `gp3-retain` reclaim policy means retained EBS volumes can remain after Kubernetes resources or the EKS cluster are destroyed.

Infrastructure destruction therefore includes explicit verification for leftover AWS storage and other automatically created resources.

Retained volumes should be reviewed before deleting them because they may contain recoverable database data.

## Recovery Principle

The recovery process is based on:

```text
Snapshot
   |
   v
Restore
   |
   v
Validate
   |
   v
Return workload to service
```

The restore procedure should be tested periodically rather than assuming that the existence of a snapshot alone guarantees recovery.
