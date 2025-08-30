#!/bin/bash
set -e

# Load env vars
export $(grep -v '^#' config/config.env | xargs)
echo "DOMAIN_NAME=${DOMAIN_NAME}"
echo "PUBLIC_IP=${PUBLIC_IP}"
echo "LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}"

# Scale down Traefik if running
if kubectl get deploy traefik -n kube-system &>/dev/null; then
  echo "▶ Scaling down Traefik to avoid port 80 conflicts…"
  kubectl -n kube-system scale deploy traefik --replicas=0
  
  echo "▶ Deleting old Traefik LoadBalancer service..."
  kubectl -n kube-system delete svc traefik --ignore-not-found
fi

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

# Apply MetalLB config
envsubst < metallb-config.yaml | kubectl apply -f -

# Deploy NGINX Ingress Controller
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.externalTrafficPolicy=Local \
    --set controller.config.strict-validate-path-type=false \
  --wait

# Wait for NGINX Ingress Controller deployment to be ready before proceeding
echo "⏳ Waiting for NGINX Ingress Controller deployment to be ready…"
kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx

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

# Install cert-manager
# Note: The last --set flag disables a feature that causes an ingress-nginx error, shold not be necessary in versions after 1.18.2
helm upgrade --install cert-manager cert-manager \
  --repo https://charts.jetstack.io \
  --namespace cert-manager \
  --create-namespace \
  --version v1.18.2 \
  --set installCRDs=true \
#  --set config.featureGates.ACMEHTTP01IngressPathTypeExact=false

# Wait for cert-manager pods
kubectl rollout status deployment cert-manager -n cert-manager
kubectl rollout status deployment cert-manager-webhook -n cert-manager
kubectl rollout status deployment cert-manager-cainjector -n cert-manager

# --- Wait for webhook CA injection ---
echo "⏳ Waiting for webhook CA bundle…"
for i in {1..30}; do
  ca_bundle=$(kubectl get mutatingwebhookconfiguration cert-manager-webhook \
    -o jsonpath='{.webhooks[0].clientConfig.caBundle}' 2>/dev/null || echo "")
  if [[ -n "$ca_bundle" ]]; then
    echo "✅ CA bundle ready."
    break
  fi
  echo "   still waiting… ($i/30)"
  sleep 10
  [[ $i -eq 30 ]] && { echo "❌ Timeout waiting for webhook CA bundle."; exit 1; }
done


# Apply Let's Encrypt ClusterIssuer
envsubst < cluster-issuer.yaml | kubectl apply -f -
echo "✅ ClusterIssuer letsencrypt-prod applied."

# Apply Ingress with TLS
envsubst < rest-server-ingress.yaml | kubectl apply -f -
echo "✅ Ingress applied."

# After applying Ingress
echo "🔍 Checking Certificate status…"
CERT_NS=default
CERT_NAME=rest-server-tls

# Ensure a Certificate exists (ingress-shim should create it)
for i in {1..12}; do
  if kubectl -n "$CERT_NS" get certificate "$CERT_NAME" &>/dev/null; then
    break
  fi
  echo "   waiting for Certificate to appear… ($i/12)"
  sleep 5
done

if kubectl -n "$CERT_NS" get certificate "$CERT_NAME" &>/dev/null; then
  ready=$(kubectl -n "$CERT_NS" get certificate "$CERT_NAME" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' || true)
  if [[ "$ready" == "True" ]]; then
    echo "✅ Certificate already Ready — skipping ACME challenge wait."
  else
    echo "🔍 Waiting for ACME challenge/orders while cert issues…"
    # Poll challenge briefly (they are short-lived)
    for i in {1..20}; do
      challenge=$(kubectl get challenges.acme.cert-manager.io -A -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
      if [[ -n "$challenge" ]]; then
        echo "✅ Challenge detected: $challenge"
        break
      fi
      sleep 5
    done

    echo "▶ Waiting for Certificate to be Ready…"
    for i in {1..30}; do
      ready=$(kubectl -n "$CERT_NS" get certificate "$CERT_NAME" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
      if [[ "$ready" == "True" ]]; then
        echo "✅ Certificate is Ready."
        break
      fi
      echo "   waiting… ($i/30)"
      sleep 5
    done
  fi
else
  echo "❌ Certificate resource did not appear. Check cert-manager logs."
  exit 1
fi

echo "✅ Deployment complete. Test at: https://${DOMAIN_NAME}/api"