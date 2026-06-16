#!/bin/sh

install_traefik() {
  if kubectl_cmd get deployment -n traefik traefik >/dev/null 2>&1; then
    log_info "Traefik already installed; skip."
    return 0
  fi
  mkdir -p "$K8S_RESOURCE_DIR"
  manifest="$K8S_RESOURCE_DIR/traefik.yaml"
  render_traefik_manifest > "$manifest"
  run_cmd "09-traefik" kubectl_cmd apply -f "$manifest"
  run_cmd "09-traefik" kubectl_cmd -n traefik rollout status deployment/traefik --timeout=180s
}

render_traefik_manifest() {
  traefik_image=$(image_ref "docker.io/traefik:v3.0")
  cat <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: traefik
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: traefik
  namespace: traefik
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: traefik
rules:
  - apiGroups: [""]
    resources: ["services", "endpoints", "secrets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses", "ingressclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses/status"]
    verbs: ["update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: traefik
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: traefik
subjects:
  - kind: ServiceAccount
    name: traefik
    namespace: traefik
---
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: traefik
spec:
  controller: traefik.io/ingress-controller
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: traefik
  namespace: traefik
spec:
  replicas: 1
  selector:
    matchLabels:
      app: traefik
  template:
    metadata:
      labels:
        app: traefik
    spec:
      serviceAccountName: traefik
      containers:
        - name: traefik
          image: $traefik_image
          args:
            - --providers.kubernetesingress=true
            - --providers.kubernetesingress.ingressclass=traefik
            - --entrypoints.web.address=:80
            - --entrypoints.websecure.address=:443
            - --ping=true
            - --metrics.prometheus=true
          ports:
            - name: web
              containerPort: 80
            - name: websecure
              containerPort: 443
            - name: ping
              containerPort: 8080
          readinessProbe:
            httpGet:
              path: /ping
              port: 8080
          livenessProbe:
            httpGet:
              path: /ping
              port: 8080
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 500m
              memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: traefik
  namespace: traefik
spec:
  type: NodePort
  selector:
    app: traefik
  ports:
    - name: web
      port: 80
      targetPort: 80
      nodePort: $TRAEFIK_HTTP_NODEPORT
    - name: websecure
      port: 443
      targetPort: 443
      nodePort: $TRAEFIK_HTTPS_NODEPORT
EOF
}
