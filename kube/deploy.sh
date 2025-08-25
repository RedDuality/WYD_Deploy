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

# This script automates the deployment of your Kubernetes resources.

# Step 1: Install Nginx Ingress Controller (with patch)
echo "Installing Nginx Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/baremetal/deploy.yaml
echo "Done."

# Wait for the Deployment to exist before patching
echo "Waiting for Nginx Ingress Controller deployment to be created..."
kubectl wait --for=condition=Available --timeout=300s deployment/ingress-nginx-controller -n ingress-nginx

# Apply the patch to add hostNetwork and hostPort
echo "Patching Nginx Ingress Controller for bare-metal setup..."
kubectl patch deployment ingress-nginx-controller -n ingress-nginx --patch "$(cat manifest/nginx-patch.yaml)"
echo "Done."

# Step 2: Install Cert-Manager
echo "Installing Cert-Manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml
echo "Done."

# Step 3: Wait for foundational components to be ready
echo "Waiting for foundational components to be ready..."
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-webhook -n cert-manager
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
kubectl wait --for=condition=Available --timeout=300s deployment/ingress-nginx-controller -n ingress-nginx

echo "Adding a short delay to allow webhook CA injection..."
sleep 20

# Step 3.5: Wait for cert-manager-webhook certificate to be ready
echo "Waiting for Cert-Manager webhook to be ready..."
kubectl wait --for=jsonpath='{.data}' secret/cert-manager-webhook-ca --namespace=cert-manager --timeout=300s
echo "Webhook CA secret is ready."

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

# Step 6: Applying secrets and configuration
echo "Applying secrets and configuration..."
kubectl apply -f config/secrets.yaml
kubectl apply -f config/rest-server-config.yaml
echo "Done."

# Step 6.5: Wait for certificate to be issued and then enable SSL redirects
echo "Waiting for certificate to be ready before enabling SSL redirects..."
max_retries_cert=10
retry_count_cert=0
cert_ready=false

while [ $retry_count_cert -lt $max_retries_cert ]; do
    if kubectl get certificate rest-server-tls-secret -o=jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q "True"; then
        echo "Certificate is ready. Enabling SSL redirects."
        kubectl annotate ingress rest-server-ingress nginx.ingress.kubernetes.io/ssl-redirect="true" --overwrite
        kubectl annotate ingress rest-server-ingress nginx.ingress.kubernetes.io/force-ssl-redirect="true" --overwrite
        cert_ready=true
        break
    else
        echo "Certificate not ready yet. Attempt $((retry_count_cert + 1)) of $max_retries_cert. Retrying in 10 seconds..."
        sleep 10
        retry_count_cert=$((retry_count_cert + 1))
    fi
done

if [ "$cert_ready" = false ]; then
    echo "Certificate did not become ready after $max_retries_cert retries. Proceeding without SSL redirects."
fi
echo "Done."

# Step 7: Applying application resources
echo "Applying MongoDB resources with initContainer..."

# Delete PVC if exists to force reinitialization
#kubectl delete pvc mongodb-pvc --ignore-not-found

kubectl apply -f manifest/mongodb-deploy.yaml

echo "Waiting for MongoDB deployment to be ready..."
kubectl wait --for=condition=Available deployment/mongodb-deployment --timeout=300s

echo "Applying rest-server deployment..."
kubectl apply -f manifest/rest-server-deploy.yaml

echo "All components deployed successfully! 🚀"