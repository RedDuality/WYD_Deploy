#!/bin/bash
set -e

# --- Deploy application secrets/config ---
echo "✅ Applying secrets and configs..."
kubectl apply -f config/secrets.yaml
kubectl apply -f config/rest-server-config.yaml

# --- Deploy MongoDB ---
echo "⏳ Deploying MongoDB..."
kubectl apply -f mongodb-deploy.yaml
kubectl wait --for=condition=Available --timeout=300s deploy/mongodb-deployment
echo "✅ MongoDB deployment is ready."

# --- Deploy REST server ---
echo "⏳ Deploying REST server..."
kubectl apply -f rest-server-deploy.yaml
echo "✅ REST server deployment is queued."