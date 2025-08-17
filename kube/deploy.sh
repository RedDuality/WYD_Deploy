#!/bin/bash

# Load environment variables from the new config folder
if [ -f "config/config.env" ]; then
  export $(cat config/config.env | xargs)
fi

# This script automates the deployment of your Kubernetes resources.

# Step 1: Install Nginx Ingress Controller
echo "Installing Nginx Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Step 2: Install Cert-Manager
echo "Installing Cert-Manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

# Step 3: Wait for Cert-Manager pods to be ready
echo "Waiting for cert-manager to be ready..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s

echo "Applying secrets..."
kubectl apply -f config/secrets.yaml

# Applying the ConfigMap before the Deployments that depend on it
echo "Applying application configuration..."
kubectl apply -f config/rest-server-config.yaml

echo "Applying MongoDB resources with initContainer..."
kubectl apply -f manifests/mongodb-deploy.yaml

echo "Waiting for MongoDB deployment to be ready..."
kubectl wait --for=condition=Available deployment/mongodb-deployment --timeout=300s

echo "Applying rest-server deployment..."
kubectl apply -f manifests/rest-server-deploy.yaml

# Step 4: Apply the Cert-Manager ClusterIssuer with the email from the env file.
echo "Applying Cert-Manager ClusterIssuer..."
sed "s|<LETSENCRYPT_EMAIL>|$LETSENCRYPT_EMAIL|g" manifests/cluster-issuer.yaml | kubectl apply -f -

# Step 5: Apply the Ingress with the domain from the env file.
echo "Applying Ingress with domain name..."
sed "s|<DOMAIN_NAME>|$DOMAIN_NAME|g" manifests/ingress.yaml | kubectl apply -f -

echo "All components deployed successfully! 🚀"