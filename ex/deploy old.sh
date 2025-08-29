#!/usr/bin/env bash
set -euo pipefail

# ==============================
# 0) Preflight / defaults
# ==============================
CONFIG_FILE="config/config.env"
if [[ -f "$CONFIG_FILE" ]]; then
  set -a
  source "$CONFIG_FILE"
  set +a
else
  echo "⚠️  $CONFIG_FILE not found — using defaults."
fi

: "${DOMAIN_NAME:=example.com}"
: "${LETSENCRYPT_EMAIL:=admin@example.com}"

command -v kubectl >/dev/null || { echo "❌ kubectl not found"; exit 1; }
command -v envsubst >/dev/null || { echo "❌ envsubst not found"; exit 1; }

echo "✅ DOMAIN_NAME=${DOMAIN_NAME}"
echo "✅ LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}"
echo "ℹ️  Ensure DNS (Cloudflare) is set to DNS‑Only for ${DOMAIN_NAME} until issuance."

# ==============================
# 1) Ensure Traefik is stopped
# ==============================
if kubectl get deploy traefik -n kube-system &>/dev/null; then
  echo "▶ Scaling down Traefik to avoid port 80 conflicts…"
  kubectl -n kube-system scale deploy traefik --replicas=0
fi

# ==============================
# 2) Install NGINX Ingress
# ==============================
echo "▶ Installing ingress-nginx (bare metal)…"
kubectl apply -f \
  https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/baremetal/deploy.yaml
echo "▶ Patching ingress-nginx to use host network…"

echo "▶ Patching ingress-nginx to use host network…"
# Patch 1: Use the host's network to listen on ports 80/443 directly.
kubectl -n ingress-nginx patch deployment ingress-nginx-controller --type='json' -p='[{"op": "add", "path": "/spec/template/spec/hostNetwork", "value": true}]'

# Patch 2: Fix DNS resolution for pods using hostNetwork.
kubectl -n ingress-nginx patch deployment ingress-nginx-controller --type='json' -p='[{"op": "add", "path": "/spec/template/spec/dnsPolicy", "value": "ClusterFirstWithHostNet"}]'



kubectl wait --for=condition=Available --timeout=300s -n ingress-nginx deploy/ingress-nginx-controller

# ==============================
# 3) Install cert-manager
# ==============================
echo "▶ Installing cert-manager…"
kubectl apply -f \
  https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml
kubectl wait --for=condition=Available --timeout=300s -n cert-manager deploy/cert-manager
kubectl wait --for=condition=Available --timeout=300s -n cert-manager deploy/cert-manager-cainjector
kubectl wait --for=condition=Available --timeout=300s -n cert-manager deploy/cert-manager-webhook

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

# ==============================
# 4) Apply ClusterIssuer + Ingress
# ==============================
echo "▶ Applying ClusterIssuer + Ingress…"
envsubst < manifest/clusterissuer-and-ingress.yaml | kubectl apply -f -

# ==============================
# 5) Wait for Challenge, verify
# ==============================
echo "🔍 Waiting for ACME challenge…"
for i in {1..30}; do
  challenge=$(kubectl get challenge -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [[ -n "$challenge" ]]; then
    echo "✅ Challenge detected: $challenge"
    break
  fi
  sleep 5
done

if [[ -n "${challenge:-}" ]]; then
  token=$(kubectl get challenge "$challenge" -o jsonpath='{.spec.token}')
  echo "ℹ️  Test this outside the cluster:"
  echo "    curl http://${DOMAIN_NAME}/.well-known/acme-challenge/${token}"
fi

# ==============================
# 6) Wait for Certificate
# ==============================
echo "▶ Waiting for Certificate to be Ready…"
for i in {1..10}; do
  ready=$(kubectl get certificate rest-server-tls-secret \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
  if [[ "$ready" == "True" ]]; then
    echo "✅ Certificate is Ready."
    break
  fi
  echo "   waiting… ($i/10)"
  sleep 10
  [[ $i -eq 10 ]] && { echo "❌ Cert timed out"; exit 1; }
done

# ==============================
# 7) Enable HTTPS redirect
# ==============================
kubectl annotate ingress rest-server-ingress \
  nginx.ingress.kubernetes.io/ssl-redirect="true" \
  nginx.ingress.kubernetes.io/force-ssl-redirect="true" \
  --overwrite

# ==============================
# 8) Deploy configs + workloads
# ==============================
kubectl apply -f config/secrets.yaml
kubectl apply -f config/rest-server-config.yaml
kubectl apply -f manifest/mongodb-deploy.yaml
kubectl wait --for=condition=Available --timeout=300s deploy/mongodb-deployment
kubectl apply -f manifest/rest-server-deploy.yaml

echo "✅ Deployment complete. Test at: https://${DOMAIN_NAME}"
