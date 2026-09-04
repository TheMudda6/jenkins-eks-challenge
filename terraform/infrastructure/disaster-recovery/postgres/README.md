# PostgreSQL Disaster Recovery Runbook

## Purpose
Document the EBS CSI VolumeSnapshot restore procedure for PostgreSQL.

## Snapshot
Confirm the production PVC:
`kubectl -n jenkins get pvc postgres-data-postgres-0`

Create and wait for the snapshot:
`kubectl apply -f snapshot.yaml`
`kubectl -n jenkins wait --for=jsonpath="{.status.readyToUse}"=true volumesnapshot/postgres-snapshot --timeout=10m`

## Restore
Create the restored PVC:
`kubectl apply -f restore-pvc.yaml`
`kubectl -n jenkins wait --for=jsonpath="{.status.phase}"=Bound pvc/postgres-data-restore --timeout=10m`

Mount it with the restore test pod:
`kubectl apply -f restore-test-pod.yaml`

Verify the restored volume is mounted and test PostgreSQL data integrity using a known test record.

## Evidence
Capture the VolumeSnapshot status, restored PVC status, restore pod status, PostgreSQL version, and the known record before and after restoration.

## Cleanup
Delete only the restore test pod, restored PVC, and test snapshot. Never delete the production PostgreSQL PVC.

## Recovery objective
Measure actual recovery time and data-loss results during the DR test rather than assuming RTO/RPO values.
