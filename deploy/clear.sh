#!/bin/bash
set -e

# Make sure all sub-scripts are executable
chmod +x rest-server/clear.sh
chmod +x ingress/clear.sh

# Navigate and run the rest-server clear script
cd rest-server
./clear.sh
cd ..

# Navigate and run the nginx clear script
cd ingress
./clear.sh
cd ..