# -----------------------------------------------------------------------------
# PostgreSQL Infrastructure
#
# Purpose:
# Documents the PostgreSQL Kubernetes resources used by the e-commerce platform.
#
# PostgreSQL runs as a StatefulSet with persistent Amazon EBS-backed storage
# and is exposed internally through a Kubernetes headless Service.
# -----------------------------------------------------------------------------

## Persistent Storage

PostgreSQL uses a 20Gi PVC backed by the `gp3-retain` StorageClass.

The PostgreSQL container mounts the EBS-backed volume at:

`/var/lib/postgresql/data`

and sets:

`PGDATA=/var/lib/postgresql/data/pgdata`

The nested `pgdata` directory is therefore the PostgreSQL data directory stored on
the persistent EBS volume. When the PostgreSQL pod is recreated, Kubernetes
reattaches the PVC and PostgreSQL continues using the same persistent data
directory.
