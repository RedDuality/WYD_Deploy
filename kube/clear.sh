#!/bin/bash

kubectl delete -f mongodb-deploy.yaml
kubectl delete -f rest-server-deploy.yaml
kubectl delete -f secrets.yaml