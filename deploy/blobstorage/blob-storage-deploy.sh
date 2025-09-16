#!/bin/bash
set -e

# --- Deploy application secrets/config ---
echo "⏳ Applying secrets and configs..."
kubectl apply -f ../config/secrets.yaml
export $(grep -v '^#' ../config/config.env | xargs)
echo "✅ Secrets and configs applied."

echo "DOMAIN_NAME=${DOMAIN_NAME}"

# Add and update the MinIO Helm repo
echo "⏳ Adding MinIO Helm repository..."
helm repo add minio https://charts.min.io/
helm repo update

# Deploy MinIO 
echo "⏳ Deploying MinIO..."
helm upgrade --install minio minio/minio -f minio-values.yaml --namespace default
echo "✅ MinIO deployed."

# Deploy MinIO initialization ConfigMap and Job
echo "⏳ Applying MinIO initialization resources..."
kubectl apply -f minio-init.yaml
echo "✅ MinIO initialization applied."