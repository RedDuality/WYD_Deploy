#!/bin/bash
set -e

# Load env vars (optional but good practice)
export $(grep -v '^#' config/config.env | xargs)

# ---- TRAEFIK RESOURCES ----
echo "⏳ Deleting Traefik resources..."
# Clean up any leftover Traefik pods or services from the previous state
kubectl -n kube-system delete deploy traefik --ignore-not-found=true || true
kubectl -n kube-system delete svc traefik --ignore-not-found=true || true
echo "✅ Traefik resources removed."

# ---- INGRESS-NGINX RESOURCES ----
echo "⏳ Deleting ingress-nginx resources..."
# Use Helm to uninstall the release
helm uninstall ingress-nginx --namespace ingress-nginx --ignore-not-found || true
# A small delay to ensure resources are cleaned up before removing the namespace
sleep 5
kubectl delete namespace ingress-nginx --ignore-not-found=true || true
echo "✅ ingress-nginx resources removed."

# ---- CERT-MANAGER RESOURCES ----
echo "⏳ Deleting cert-manager resources..."
# Remove the cluster-scoped resources first
kubectl delete clusterissuer letsencrypt-prod --ignore-not-found=true || true
# Use Helm to uninstall cert-manager and its associated resources
helm uninstall cert-manager --namespace cert-manager --ignore-not-found || true
# A small delay to ensure resources are cleaned up before removing the namespace
sleep 5
kubectl delete namespace cert-manager --ignore-not-found=true || true
echo "✅ cert-manager resources removed."

# ---- METAL-LB RESOURCES ----
echo "⏳ Deleting MetalLB resources..."
# Delete the custom IP address pool and advertisement
envsubst < metallb-config.yaml | kubectl delete -f - --ignore-not-found=true || true
# Use the original manifest to clean up the MetalLB installation
kubectl delete -f https://raw.githubusercontent.com/metallb/metallb/v0.13.10/config/manifests/metallb-native.yaml --ignore-not-found=true || true
echo "✅ MetalLB resources removed."