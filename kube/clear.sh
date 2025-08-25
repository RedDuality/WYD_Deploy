#!/usr/bin/env bash
set -euo pipefail

echo "🗑️  Deleting all Kubernetes resources..."

# --- 1) Application workloads ---
echo "▶ Deleting application deployments..."
kubectl delete -f manifest/rest-server-deploy.yaml --ignore-not-found
kubectl delete -f manifest/mongodb-deploy.yaml --ignore-not-found

# --- 2) Configurations and secrets ---
echo "▶ Deleting configuration and secrets..."
kubectl delete -f config/rest-server-config.yaml --ignore-not-found
kubectl delete -f config/secrets.yaml --ignore-not-found

# --- 3) Ingress + ClusterIssuer (combined file) ---
echo "▶ Deleting Ingress and ClusterIssuer..."
kubectl delete -f manifest/clusterissuer-and-ingress.yaml --ignore-not-found

# --- 4) cert-manager ---
echo "▶ Deleting cert-manager..."
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml --ignore-not-found

# --- 5) NGINX Ingress Controller (bare metal provider) ---
echo "▶ Deleting NGINX Ingress Controller..."
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/baremetal/deploy.yaml --ignore-not-found

echo "✅ All components deleted (resources that didn’t exist were skipped)."
