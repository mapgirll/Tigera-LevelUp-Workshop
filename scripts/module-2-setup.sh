#!/bin/bash
kubectl create namespace hipstershop
kubectl apply -n hipstershop -f https://raw.githubusercontent.com/JosephYostos/test-repo/main/manifest/hipstershop-v0.3.8.yaml
kubectl run multitool --image=wbitt/network-multitool
kubectl run multitool -n hipstershop --image=wbitt/network-multitool
kubectl apply -n hipstershop -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/main/release/kubernetes-manifests.yaml