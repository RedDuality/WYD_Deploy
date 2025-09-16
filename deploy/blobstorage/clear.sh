#!/bin/bash
set -e

echo "🧹 Cleaning up MinIO deployment and related resources..."

# 1. Uninstall the MinIO Helm release
if helm status minio --namespace default >/dev/null 2>&1; then
  echo "⏳ Uninstalling MinIO Helm release..."
  helm uninstall minio --namespace default
  echo "✅ MinIO release removed."
else
  echo "ℹ️ No MinIO release found in 'default' namespace."
fi

# 2. Remove PersistentVolumeClaims created by MinIO
PVCs=$(kubectl get pvc --namespace default -o name | grep minio || true)

if [ -n "$PVCs" ]; then
  echo "⚠️  The following PVCs were found:"
  echo "$PVCs"
  read -p "Are you sure you want to delete these PVCs? [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "⏳ Deleting MinIO PVCs..."
    kubectl delete $PVCs --namespace default
    echo "✅ PVCs removed."
  else
    echo "❌ Deletion aborted by user."
  fi
else
  echo "ℹ️ No MinIO PVCs found."
fi