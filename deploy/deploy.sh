#!/bin/bash
set -e

# Navigate and run the blobstorage deployment script
echo "⏳ Deploying Blob Storage..."
cd blobstorage
chmod +x blob-storage-deploy.sh
./blob-storage-deploy.sh
cd ..

# Navigate and run the rest-server deployment script
echo "⏳ Deploying server..."
cd rest-server
chmod +x rest-server-deploy.sh
./rest-server-deploy.sh
cd ..

# Navigate and run the nginx deployment script
echo "⏳ Initiating ingress..."
cd ingress
chmod +x ingress-deploy.sh
./ingress-deploy.sh
cd ..

