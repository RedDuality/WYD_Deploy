#!/bin/bash
set -e

# Load env vars (optional but good practice)
export $(grep -v '^#' config/config.env | xargs)

# ---- APPLICATION RESOURCES ----
echo "⏳ Deleting application resources..."
# Delete the ingress first as it depends on the controller
kubectl delete ingress rest-server-ingress --ignore-not-found=true || true
# Delete services and deployments using the original manifest files
kubectl delete -f rest-server/mongodb-deploy.yaml --ignore-not-found=true || true
kubectl delete -f rest-server/rest-server-deploy.yaml --ignore-not-found=true || true
# Delete configs and secrets
kubectl delete -f rest-server/config/secrets.yaml --ignore-not-found=true || true
kubectl delete -f rest-server/config/rest-server-config.yaml --ignore-not-found=true || true
echo "✅ Application resources removed."