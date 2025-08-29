#!/bin/bash
set -e

# Load environment variables (DOMAIN_NAME, LETSENCRYPT_EMAIL, etc.)
export $(grep -v '^#' config/config.env | xargs)
echo "✅ DOMAIN_NAME=${DOMAIN_NAME}"
echo "✅ LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}"

# --- Pre‑flight: scale down Traefik if present ---
if kubectl get deploy traefik -n kube-system &>/dev/null; then
  echo "▶ Scaling down Traefik to avoid port 80/443 conflicts…"
  kubectl -n kube-system scale deploy traefik --replicas=0
  echo "⏳ Waiting for Traefik pods to terminate…"
  kubectl -n kube-system wait --for=delete pod -l app=traefik --timeout=60s || true
fi

# --- Deploy application secrets/config ---
echo "✅ Applying secrets and configs..."
kubectl apply -f config/secrets.yaml
kubectl apply -f config/rest-server-config.yaml

# --- Deploy MongoDB ---
echo "⏳ Deploying MongoDB..."
kubectl apply -f manifest/mongodb-deploy.yaml
kubectl wait --for=condition=Available --timeout=300s deploy/mongodb-deployment
echo "✅ MongoDB deployment is ready."

# --- Deploy REST server ---
echo "⏳ Deploying REST server..."
kubectl apply -f manifest/rest-server-deploy.yaml
echo "✅ REST server deployment is queued."


# --- Ingress-nginx (bare-metal) ---
echo "⏳ Deploying ingress-nginx (bare-metal mode)..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.13.1/deploy/static/provider/baremetal/deploy.yaml

# Wait for ingress-nginx deployment to be ready
echo "⏳ Waiting for ingress-nginx to become ready..."
kubectl wait --for=condition=Available --timeout=300s -n ingress-nginx deploy/ingress-nginx-controller
echo "✅ ingress-nginx deployment is ready."

# Patch ingress-nginx to bind hostPorts 80 & 443
echo "🔧 Patching ingress-nginx for hostPorts..."
kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
  --type='json' \
  -p='[
    {"op": "add","path": "/spec/template/spec/containers/0/ports/0/hostPort","value": 80},
    {"op": "add","path": "/spec/template/spec/containers/0/ports/1/hostPort","value": 443}
  ]'

# Wait for the patched deployment to roll out and become ready again
kubectl wait --for=condition=Available --timeout=300s -n ingress-nginx deploy/ingress-nginx-controller
echo "✅ Ingress-nginx is now listening directly on ports 80 and 443."

# This is the most critical fix: wait for the admission webhook to be reachable
echo "⏳ Waiting for ingress-nginx admission webhook to be ready..."
for i in {1..60}; do
  if kubectl get endpoints -n ingress-nginx ingress-nginx-controller-admission | grep -q "443"; then
    echo "✅ Admission webhook endpoints are available."
    break
  fi
  echo "  still waiting... ($i/60)"
  sleep 5
  [[ $i -eq 60 ]] && { echo "❌ Timeout waiting for webhook endpoints."; exit 1; }
done

# --- cert-manager ---
echo "⏳ Deploying cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.18.2/cert-manager.yaml
kubectl wait --for=condition=Available --timeout=300s -n cert-manager deploy --all
echo "✅ Cert-manager is ready."

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

kubectl wait --for=condition=available --timeout=120s deployment/ingress-nginx-controller -n ingress-nginx
kubectl -n ingress-nginx get endpoints ingress-nginx-controller-admission


# --- TLS issuer & ingress ---
echo "✅ Applying TLS issuer..."
envsubst < manifest/cluster-issuer.yaml | kubectl apply -f -
echo "✅ Applying ingress..."
envsubst < manifest/rest-server-ingress.yaml | kubectl apply -f -

echo "🔍 Waiting for ACME challenge…"
for i in {1..30}; do
  challenge=$(kubectl get challenge -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [[ -n "$challenge" ]]; then
    echo "✅ Challenge detected: $challenge"
    break
  fi
  sleep 5
done

# --- Wait for certificate ---
echo "⏳ Waiting for certificate issuance..."
kubectl wait --for=condition=ready certificate/${DOMAIN_NAME} --timeout=300s
echo "✅ HTTPS is active at https://${DOMAIN_NAME}"
