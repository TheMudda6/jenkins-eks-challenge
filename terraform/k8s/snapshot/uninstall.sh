echo "Removing VolumeSnapshotClass..."

kubectl delete -f k8s/storage/volumesnapshotclass.yaml \
  --ignore-not-found=true

echo "✓ VolumeSnapshotClass removed."

echo ""
echo "Removing Snapshot Controller..."

kubectl delete -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-8.2/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml \
  --ignore-not-found=true

echo "✓ Snapshot Controller removed."

echo ""
echo "Removing Snapshot Controller RBAC..."

kubectl delete -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-8.2/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml \
  --ignore-not-found=true

echo "✓ Snapshot Controller RBAC removed."

echo ""
echo "Removing Volume Snapshot CRDs..."

kubectl delete crd volumesnapshotclasses.snapshot.storage.k8s.io \
  --ignore-not-found=true

kubectl delete crd volumesnapshots.snapshot.storage.k8s.io \
  --ignore-not-found=true

kubectl delete crd volumesnapshotcontents.snapshot.storage.k8s.io \
  --ignore-not-found=true

echo "✓ Volume Snapshot CRDs removed."

echo ""
echo "Verifying snapshot infrastructure has been removed..."

echo ""
echo "VolumeSnapshotClasses:"
kubectl get volumesnapshotclass 2>/dev/null || echo "✓ No VolumeSnapshotClass resources found."

echo ""
echo "VolumeSnapshots:"
kubectl get volumesnapshot -A 2>/dev/null || echo "✓ No VolumeSnapshot resources found."

echo ""
echo "VolumeSnapshotContents:"
kubectl get volumesnapshotcontent 2>/dev/null || echo "✓ No VolumeSnapshotContent resources found."

echo ""
echo "Snapshot Controller:"
kubectl get deployment snapshot-controller -n kube-system 2>/dev/null || echo "✓ Snapshot Controller removed."

echo ""
echo "Snapshot CRDs:"
kubectl get crd | grep snapshot || echo "✓ No Snapshot CRDs found."

echo ""
echo "✓ Snapshot infrastructure successfully removed."