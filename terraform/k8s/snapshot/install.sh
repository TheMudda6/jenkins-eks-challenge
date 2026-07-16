print_banner "Installing Snapshot Infrastructure"

echo "Installing Volume Snapshot CRDs..."

kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-8.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml

kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-8.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml

kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-8.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml

echo "✓ Volume Snapshot CRDs installed."

echo ""
echo "Waiting for Volume Snapshot CRDs to become available..."

kubectl wait \
  --for=condition=Established \
  crd/volumesnapshotclasses.snapshot.storage.k8s.io \
  --timeout=120s

kubectl wait \
  --for=condition=Established \
  crd/volumesnapshots.snapshot.storage.k8s.io \
  --timeout=120s

kubectl wait \
  --for=condition=Established \
  crd/volumesnapshotcontents.snapshot.storage.k8s.io \
  --timeout=120s

echo "✓ Volume Snapshot CRDs are ready."

echo ""
echo "Installing Snapshot Controller RBAC..."

kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-8.2/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml

echo "✓ Snapshot Controller RBAC installed."

echo ""
echo "Installing Snapshot Controller..."

kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-8.2/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml

echo "✓ Snapshot Controller installed."

echo ""
echo "Waiting for Snapshot Controller deployment..."

kubectl wait \
  --for=condition=Available \
  deployment/snapshot-controller \
  -n kube-system \
  --timeout=120s

echo "✓ Snapshot Controller is ready."

echo ""
echo "Creating VolumeSnapshotClass..."

kubectl apply -f k8s/storage/volumesnapshotclass.yaml

echo "✓ VolumeSnapshotClass created."

echo ""
echo "Verifying VolumeSnapshotClass..."

kubectl get volumesnapshotclass

echo "✓ Snapshot infrastructure installation complete."