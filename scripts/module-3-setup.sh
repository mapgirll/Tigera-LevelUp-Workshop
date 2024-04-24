#!/bin/bash
kubectl apply -f -<<EOF
apiVersion: projectcalico.org/v3
kind: Tier
metadata:
  name: app-hipstershop
spec:
  order: 400
---
apiVersion: projectcalico.org/v3
kind: Tier
metadata:
  name: platform
spec:
  order: 300
---
apiVersion: projectcalico.org/v3
kind: Tier
metadata:
  name: security
spec:
  order: 200
---
apiVersion: projectcalico.org/v3
kind: Tier
metadata:
  name: namespace-isolation
spec:
  order: 350
EOF
kubectl apply -f https://raw.githubusercontent.com/mapgirll/Tigera-LevelUp-Workshop/main/hipstershop/pass-dns-default-deny-policy.yaml
kubectl apply -f https://raw.githubusercontent.com/mapgirll/Tigera-LevelUp-Workshop/main/hipstershop/default-egress-policy.yaml
kubectl patch felixconfigurations default --type merge -p '{"spec":{"flowLogsFlushInterval":"1s"}}'
kubectl apply -f - <<EOF
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: namespace-isolation.namespace-isolation-default-pass
spec:
  tier: namespace-isolation
  order: 150
  selector: ""
  namespaceSelector: ""
  serviceAccountSelector: ""
  ingress:
    - action: Pass
      source: {}
      destination: {}
  egress:
    - action: Pass
      source: {}
      destination: {}
  doNotTrack: false
  applyOnForward: false
  preDNAT: false
  types:
    - Ingress
    - Egress
EOF
kubectl apply -f - <<EOF
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: namespace-isolation.namespace-isolation-default-pass
spec:
  tier: namespace-isolation
  order: 150
  selector: ""
  namespaceSelector: ""
  serviceAccountSelector: ""
  ingress:
    - action: Pass
      source: {}
      destination: {}
  egress:
    - action: Pass
      source: {}
      destination: {}
  doNotTrack: false
  applyOnForward: false
  preDNAT: false
  types:
    - Ingress
    - Egress
EOF

kubectl delete -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: adservice
spec:
  selector:
    matchLabels:
      app: adservice
  template:
    metadata:
      labels:
        app: adservice
    spec:
      serviceAccountName: default
      terminationGracePeriodSeconds: 5
      containers:
      - name: server
        image: gcr.io/google-samples/microservices-demo/adservice:v0.3.8
        ports:
        - containerPort: 9555
        env:
        - name: PORT
          value: "9555"
        - name: DISABLE_STATS
          value: "1"
        - name: DISABLE_TRACING
          value: "1"
        # - name: JAEGER_SERVICE_ADDR
        #   value: "jaeger-collector:14268"
        resources:
          requests:
            cpu: 200m
            memory: 180Mi
          limits:
            cpu: 300m
            memory: 300Mi
        readinessProbe:
          initialDelaySeconds: 20
          periodSeconds: 15
          exec:
            command: ["/bin/grpc_health_probe", "-addr=:9555"]
        livenessProbe:
          initialDelaySeconds: 20
          periodSeconds: 15
          exec:
            command: ["/bin/grpc_health_probe", "-addr=:9555"]
EOF


kubectl -n hipstershop apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: adservice-test
spec:
  selector:
    matchLabels:
      app: adservice
  template:
    metadata:
      labels:
        app: adservice
    spec:
      serviceAccountName: default
      terminationGracePeriodSeconds: 5
      securityContext:
        fsGroup: 1000
        runAsGroup: 1000
        runAsNonRoot: true
        runAsUser: 1000
      containers:
      - name: server
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
              - ALL
          privileged: false
          readOnlyRootFilesystem: true
        image: gcr.io/google-samples/microservices-demo/adservice:v0.9.0
        ports:
        - containerPort: 9555
        env:
        - name: PORT
          value: "9555"
        resources:
          requests:
            cpu: 200m
            memory: 180Mi
          limits:
            cpu: 300m
            memory: 300Mi
        readinessProbe:
          initialDelaySeconds: 20
          periodSeconds: 15
          grpc:
            port: 9555
        livenessProbe:
          initialDelaySeconds: 20
          periodSeconds: 15
          grpc:
            port: 9555
EOF