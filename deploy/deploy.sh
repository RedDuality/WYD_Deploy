#!/bin/bash
set -e

# Make sure all sub-scripts are executable
chmod +x rest-server/rest-server-deploy.sh
chmod +x ingress/ingress-deploy.sh

# Navigate and run the rest-server deployment script
cd rest-server
./rest-server-deploy.sh
cd ..

# Navigate and run the nginx deployment script
cd ingress
./ingress-deploy.sh
cd ..