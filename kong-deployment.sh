#!/bin/bash

set -Eeuo pipefail

# ==========================================
# Configuration
# ==========================================

OPERATOR_NAMESPACE="kong-system"
GATEWAY_NAMESPACE="kong"

OPERATOR_RELEASE="kong-operator"
OPERATOR_CHART="kong/kong-operator"

GATEWAY_IMAGE="kong/kong-gateway:3.9"

echo "=========================================="
echo " Starting Kong Operator deployment"
echo "=========================================="

# ==========================================
# 1. Check prerequisites
# ==========================================

for cmd in kubectl helm; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: $cmd is not installed."
        exit 1
    fi
done

echo "[INFO] Checking Kubernetes connection..."

kubectl cluster-info

# ==========================================
# 2. Add Kong Helm repository
# ==========================================

echo "[INFO] Adding Kong Helm repository..."

helm repo add kong https://charts.konghq.com
helm repo update

# ==========================================
# 3. Install Kong Operator
# ==========================================

echo "[INFO] Installing Kong Operator..."

helm upgrade --install "$OPERATOR_RELEASE" "$OPERATOR_CHART" \
    --namespace "$OPERATOR_NAMESPACE" \
    --create-namespace

echo "[INFO] Waiting for Kong Operator Deployment..."

kubectl rollout status deployment \
    -n "$OPERATOR_NAMESPACE" \
    -l app.kubernetes.io/instance="$OPERATOR_RELEASE" \
    --timeout=180s

# ==========================================
# 4. Wait for Kong Operator CRDs
# ==========================================

echo "[INFO] Waiting for GatewayConfiguration CRD..."

for i in {1..60}; do
    if kubectl get crd gatewayconfigurations.gateway-operator.konghq.com \
        >/dev/null 2>&1; then
        break
    fi

    sleep 5
done

if ! kubectl get crd gatewayconfigurations.gateway-operator.konghq.com \
    >/dev/null 2>&1; then
    echo "ERROR: GatewayConfiguration CRD was not installed."
    exit 1
fi

# ==========================================
# 5. Check Gateway API CRDs
# ==========================================

echo "[INFO] Checking Kubernetes Gateway API CRDs..."

if ! kubectl get crd gateways.gateway.networking.k8s.io \
    >/dev/null 2>&1; then
    echo "ERROR: Gateway API CRDs are missing."
    echo "Install the standard Gateway API CRDs before continuing."
    exit 1
fi

# ==========================================
# 6. Create Gateway namespace
# ==========================================

echo "[INFO] Creating Gateway namespace..."

kubectl create namespace "$GATEWAY_NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

# ==========================================
# 7. Create GatewayConfiguration
# ==========================================

echo "[INFO] Creating GatewayConfiguration..."

kubectl apply -f - <<EOF
apiVersion: gateway-operator.konghq.com/v2beta1
kind: GatewayConfiguration
metadata:
  name: kong-configuration
  namespace: ${GATEWAY_NAMESPACE}
spec:
  dataPlaneOptions:
    network:
      services:
        ingress:
          type: NodePort
    deployment:
      podTemplateSpec:
        spec:
          containers:
            - name: proxy
              image: ${GATEWAY_IMAGE}
EOF

# ==========================================
# 8. Create GatewayClass
# ==========================================

echo "[INFO] Creating GatewayClass..."

kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: kong
spec:
  controllerName: konghq.com/gateway-operator
  parametersRef:
    group: gateway-operator.konghq.com
    kind: GatewayConfiguration
    name: kong-configuration
    namespace: ${GATEWAY_NAMESPACE}
EOF

# ==========================================
# 9. Create Gateway
# ==========================================

echo "[INFO] Creating Gateway..."

kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: kong
  namespace: ${GATEWAY_NAMESPACE}
spec:
  gatewayClassName: kong
  listeners:
    - name: http
      protocol: HTTP
      port: 80
EOF

# ==========================================
# 10. Display deployment status
# ==========================================

echo ""
echo "=========================================="
echo " Kong deployment resources"
echo "=========================================="

echo ""
echo "GatewayClass:"
kubectl get gatewayclass kong

echo ""
echo "Gateway:"
kubectl get gateway -n "$GATEWAY_NAMESPACE"

echo ""
echo "ControlPlane:"
kubectl get controlplane -n "$GATEWAY_NAMESPACE"

echo ""
echo "DataPlane:"
kubectl get dataplane -n "$GATEWAY_NAMESPACE"

echo ""
echo "Deployments:"
kubectl get deployments -n "$GATEWAY_NAMESPACE"

echo ""
echo "Services:"
kubectl get services -n "$GATEWAY_NAMESPACE"

echo ""
echo "=========================================="
echo " Kong deployment script completed"
echo "=========================================="
