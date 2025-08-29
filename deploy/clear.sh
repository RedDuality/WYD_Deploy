#!/bin/bash
set -e

echo "⏳ Deleting ingress-nginx resources (any variant)..."
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.13.1/deploy/static/provider/cloud/deploy.yaml --ignore-not-found=true || true
kubectl delete namespace ingress-nginx --ignore-not-found=true || true

echo "⏳ Deleting MetalLB resources if present..."
kubectl delete -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml --ignore-not-found=true || true
kubectl delete namespace metallb-system --ignore-not-found=true || true

echo "⏳ Waiting for namespaces to terminate..."
kubectl wait --for=delete namespace/ingress-nginx --timeout=180s || true
kubectl wait --for=delete namespace/metallb-system --timeout=180s || true
echo "✅ Ingress-nginx and MetalLB namespaces removed."

echo "⏳ Deleting REST server + MongoDB resources..."
#kubectl delete -f rest-server/rest-server-deploy.yaml --ignore-not-found=true || true
#kubectl delete -f rest-server/mongodb-deploy.yaml --ignore-not-found=true || true
#kubectl delete -f rest-server/config/secrets.yaml --ignore-not-found=true || true
#kubectl delete -f rest-server/config/rest-server-config.yaml --ignore-not-found=true || true
kubectl delete ingress rest-server-ingress --ignore-not-found=true || true
#kubectl delete svc rest-server-service --ignore-not-found=true || true
#kubectl delete deployment mongodb-deployment --ignore-not-found=true || true
#kubectl delete service mongodb-service --ignore-not-found=true || true

echo "✅ All application resources cleaned up."

echo "🧹 Cluster cleanup complete."
