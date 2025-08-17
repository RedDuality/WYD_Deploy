#!/bin/bash

# This script deletes all deployed Kubernetes resources.
echo "Deleting all resources..."

# Delete deployments
kubectl delete -f manifests/rest-server-deploy.yaml
kubectl delete -f manifests/mongodb-deploy.yaml

# Delete configuration and secrets
kubectl delete -f config/rest-server-config.yaml
kubectl delete -f config/secrets.yaml

# Delete ingress and cluster issuer
kubectl delete -f manifests/ingress.yaml
kubectl delete -f manifests/cluster-issuer.yaml

# Delete Cert-Manager
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

# Delete Nginx Ingress Controller
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

echo "All components deleted successfully! 🗑️"