#!/usr/bin/env bash
set -euo pipefail

# --- Preflight: load env and check tools ---
if [[ -f "config/config.env" ]]; then
  set -a
  source config/config.env
  set +a
else
  echo "❌ config/config.env not found"
  exit 1
fi

: "${DOMAIN_NAME:?DOMAIN_NAME not set in config.env}"
: "${LETSENCRYPT_EMAIL:?LETSENCRYPT_EMAIL not set in config.env}"

command -v kubectl >/dev/null || { echo "❌ kubectl not found"; exit 1; }
command -v envsubst >/dev/null || { echo "❌ envsubst not found (install gettext-base)"; exit 1; }

echo "✅ Using DOMAIN_NAME=${DOMAIN_NAME}"
echo "✅ Using LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}"
echo "ℹ️  Make sure Cloudflare is DNS Only (grey cloud) for ${DOMAIN_NAME} until the cert is issued."

# --- 1) Install/update NGINX Ingress Controller ---
echo "▶ Installing ingress-nginx (bare metal manifest)…"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/baremetal/deploy.yaml

echo "▶ Waiting for ingress-nginx-controller to be Available…"
kubectl wait --for=condition=Available --timeout=300s -n ingress-nginx deploy/ingress-nginx-controller

echo "▶ Patching ingress-nginx-controller for hostNetwork/hostPorts…"
# Use strategic merge so lists merge by name keys (safe re-run)
kubectl patch deploy/ingress-nginx-controller \
  -n ingress-nginx \
  --type=strategic \
  --patch "$(cat manifest/nginx-patch.yaml)" || true

# --- 2) Install/update cert-manager ---
echo "▶ Installing cert-manager…"
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml

echo "▶ Waiting for cert-manager deployments to be Available…"
kubectl wait --for=condition=Available --timeout=300s -n cert-manager deploy -l app.kubernetes.io/instance=cert-manager

echo "⏳ Allowing webhook CA injection to settle…"
sleep 20

# --- 3) Apply ClusterIssuer + Ingress with envsubst ---
echo "▶ Applying ClusterIssuer and Ingress…"
envsubst < manifest/clusterissuer-and-ingress.yaml | kubectl apply -f -

# --- 4) Wait for certificate, then enable HTTPS redirects ---
echo "▶ Waiting for Certificate to be Ready…"
kubectl wait \
  --for=jsonpath='{.status.conditions[?(@.type=="Ready")].status}'=True \
  certificate/rest-server-tls-secret \
  --timeout=300s || {
    echo "❌ Certificate not Ready in time. Check challenges: kubectl describe certificate/rest-server-tls-secret"
    exit 1
  }

echo "▶ Enabling SSL redirects on the Ingress…"
kubectl annotate ingress rest-server-ingress \
  nginx.ingress.kubernetes.io/ssl-redirect="true" \
  nginx.ingress.kubernetes.io/force-ssl-redirect="true" \
  --overwrite

echo "✅ HTTPS is enabled. Test: https://${DOMAIN_NAME}"
echo "ℹ️  You may now switch Cloudflare to Proxy (orange cloud) if desired."

kubectl apply -f config/secrets.yaml
kubectl apply -f config/rest-server-config.yaml

# --- Deploy MongoDB ---
kubectl apply -f manifest/mongodb-deploy.yaml
kubectl wait --for=condition=Available --timeout=300s deploy/mongodb-deployment

# --- Deploy REST server ---
kubectl apply -f manifest/rest-server-deploy.yaml

echo "✅ Deployment completed successfully."
