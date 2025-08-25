#!/bin/bash
set -e

# Load environment variables from config.env
echo "Loading environment variables from config.env..."
if [ -f "config/config.env" ]; then
  set -a # Automatically export all variables
  source config/config.env
  set +a # Stop automatically exporting
else
    echo "Error: config/config.env not found!"
    exit 1
fi
# Step 1: Install Nginx Ingress Controller
echo "Installing Nginx Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
echo "Done."

# Step 2: Install Cert-Manager
echo "Installing Cert-Manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml
echo "Done."

# Step 3: Wait for Cert-Manager and Nginx pods to be ready
echo "Waiting for foundational components to be ready..."
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-webhook -n cert-manager
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
kubectl wait --for=condition=Available --timeout=300s deployment/ingress-nginx-controller -n ingress-nginx

echo "Adding a short delay to allow webhook CA injection..."
sleep 30 # Adjust as needed, 10-20 seconds is a good starting point

# Step 4: Apply the Cert-Manager ClusterIssuer with the email from the env file.
echo "Applying Cert-Manager ClusterIssuer with a retry loop..."
max_retries=10
retry_count=0
success=false

while [ $retry_count -lt $max_retries ]; do
    if sed "s|<LETSENCRYPT_EMAIL>|$LETSENCRYPT_EMAIL|g" manifest/cluster-issuer.yaml | kubectl apply -f -; then
        echo "ClusterIssuer applied successfully."
        success=true
        break
    else
        echo "Attempt $((retry_count + 1)) failed. Retrying in 10 seconds..."
        sleep 10
        retry_count=$((retry_count + 1))
    fi
done

if [ "$success" = false ]; then
    echo "Failed to apply ClusterIssuer after $max_retries retries. Exiting."
    exit 1
fi
echo "Done."

# Step 5: Apply the Ingress with the domain from the env file.
echo "Applying Ingress with domain name..."
sed "s|<DOMAIN_NAME>|$DOMAIN_NAME|g" manifest/ingress.yaml | kubectl apply -f -
echo "Done."

echo "All components deployed successfully! 🚀"