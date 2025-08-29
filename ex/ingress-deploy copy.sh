#!/bin/bash
set -e

# Load env vars
export $(grep -v '^#' config/config.env | xargs)
echo "DOMAIN_NAME=${DOMAIN_NAME}"
echo "PUBLIC_IP=${PUBLIC_IP}"

# Install MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.10/config/manifests/metallb-native.yaml

# Wait for MetalLB webhook
for i in {1..10}; do
  READY=$(kubectl get endpoints webhook-service -n metallb-system -o jsonpath='{.subsets[*].addresses[*].ip}')
  if [[ -n "$READY" ]]; then
    echo "✅ MetalLB webhook is ready."
    break
  fi
  echo "⏳ Attempt $i: Webhook not ready yet..."
  sleep 10
done

# Apply MetalLB config (IP pool)
envsubst < metallb-config.yaml | kubectl apply -f -

# Deploy NGINX Ingress Controller with LoadBalancer
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.externalTrafficPolicy=Local

# Wait for External IP
for i in {1..10}; do
  IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  if [[ -n "$IP" ]]; then
    echo "✅ External IP assigned: $IP"
    break
  fi
  echo "⏳ Attempt $i: External IP not yet assigned..."
  sleep 5
done
