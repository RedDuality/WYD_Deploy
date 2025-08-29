#!/bin/bash
set -e

# Load env vars
export $(grep -v '^#' config/config.env | xargs)

# Secrets & configs
kubectl apply -f config/secrets.yaml
kubectl apply -f config/rest-server-config.yaml

# MongoDB
kubectl apply -f manifest/mongodb-deploy.yaml
kubectl wait --for=condition=Available --timeout=300s deploy/mongodb-deployment

# REST server
kubectl apply -f manifest/rest-server-deploy.yaml

# Ingress controller - Using the baremetal version
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.13.1/deploy/static/provider/baremetal/deploy.yaml

  # Wait for ingress-nginx admission webhook to be ready
kubectl wait --for=condition=Available --timeout=300s -n ingress-nginx deploy/ingress-nginx-controller
sleep 10

# Patch ingress-nginx to expose ports 80 and 443 via hostPort
kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
  --type='json' \
  -p='[
    {
      "op": "add",
      "path": "/spec/template/spec/containers/0/ports/0/hostPort",
      "value": 80
    },
    {
      "op": "add",
      "path": "/spec/template/spec/containers/0/ports/1/hostPort",
      "value": 443
    }
  ]'

# After patching, the deployment will restart. Wait for it again.
kubectl wait --for=condition=Available --timeout=300s -n ingress-nginx deploy/ingress-nginx-controller
sleep 10



# Cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.18.2/cert-manager.yaml
kubectl wait --for=condition=Available --timeout=300s -n cert-manager deploy --all
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

# TLS issuer & ingress
envsubst < manifest/cluster-issuer.yaml | kubectl apply -f -

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


envsubst < manifest/rest-server-ingress.yaml | kubectl apply -f -

