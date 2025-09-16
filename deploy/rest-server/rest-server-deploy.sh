#!/bin/bash
set -e

# --- Deploy application secrets/config ---
echo "⏳ Applying secrets and configs..."
kubectl apply -f ../config/secrets.yaml
kubectl apply -f ../config/rest-server-config.yaml
export $(grep -v '^#' ../config/config.env | xargs)
echo "✅ Secrets and configs applied."

echo "DOMAIN_NAME=${DOMAIN_NAME}"

# --- Deploy MongoDB ---
echo "⏳ Deploying MongoDB..."
kubectl apply -f mongodb-deploy.yaml
kubectl wait --for=condition=Available --timeout=300s deploy/mongodb-deployment
echo "✅ MongoDB deployment is ready."

# --- Deploy REST server ---
echo "⏳ Deploying REST server..."
envsubst < rest-server-deploy.yaml | kubectl apply -f -
echo "✅ REST server deployment is queued."