#!/bin/bash

# This script automates the deployment of your Kubernetes resources.

echo "Applying secrets..."
kubectl apply -f secrets.yaml

echo "Applying MongoDB resources with initContainer..."
kubectl apply -f mongodb-deploy.yaml

echo "Waiting for MongoDB deployment to be ready..."

kubectl wait --for=condition=Available deployment/mongodb-deployment --timeout=300s

echo "Applying rest-server deployment..."
kubectl apply -f rest-server-deploy.yaml

echo "All components deployed successfully! 🚀"