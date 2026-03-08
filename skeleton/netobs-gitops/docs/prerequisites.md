# Network Observability & Logging — Prerequisites Guide

## Overview

This template provisions per-namespace Network Observability and Logging dashboards.
The following **cluster-wide** resources must be pre-installed by a cluster-admin.
Developers then self-serve via the Golden Path template.

**Object storage: ODF External Cluster + NooBaa S3**  
**Cluster:** `apps.cluster-cnhmj.dynamic.redhatworkshops.io`

---

## 1. Verify ODF External Cluster is Healthy

```bash
oc get storagecluster ocs-external-storagecluster -n openshift-storage
oc get noobaa -n openshift-storage
# Both should show: Phase = Ready
```

Available storage classes on this cluster:
- `ocs-external-storagecluster-ceph-rbd` (default, block)
- `ocs-external-storagecluster-ceph-rbd-immediate` (block, immediate binding)
- `ocs-external-storagecluster-cephfs` (file)
- `openshift-storage.noobaa.io` (OBC/object)

---

## 2. Install Required Operators (Cluster-Admin, once)

### 2a. Network Observability Operator

```bash
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: netobserv-operator
  namespace: openshift-operators
spec:
  channel: stable
  name: netobserv-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

oc get csv -n openshift-operators | grep netobserv
```

### 2b. Cluster Logging Operator

```bash
oc create namespace openshift-logging --dry-run=client -o yaml | oc apply -f -

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: cluster-logging
  namespace: openshift-logging
spec:
  channel: stable-5.9
  name: cluster-logging
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

oc get csv -n openshift-logging | grep logging
```

### 2c. Loki Operator

```bash
oc create namespace openshift-operators-redhat --dry-run=client -o yaml | oc apply -f -

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: loki-operator
  namespace: openshift-operators-redhat
spec:
  channel: stable-6.1
  name: loki-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

oc get csv -n openshift-operators-redhat | grep loki
```

### 2d. Grafana Operator (Community)

```bash
oc create namespace grafana --dry-run=client -o yaml | oc apply -f -

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: grafana-operator
  namespace: grafana
spec:
  channel: v5
  name: grafana-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
EOF

oc get csv -n grafana | grep grafana
```

---

## 3. Create Loki Object Storage via NooBaa OBC (Cluster-Admin, once)

### 3a. Create namespace and ObjectBucketClaim

```bash
oc create namespace netobserv --dry-run=client -o yaml | oc apply -f -

cat <<EOF | oc apply -f -
apiVersion: objectbucket.io/v1alpha1
kind: ObjectBucketClaim
metadata:
  name: loki-bucket
  namespace: netobserv
spec:
  generateBucketName: loki-nb-logs
  storageClassName: openshift-storage.noobaa.io
EOF

# Wait for Bound
oc get obc loki-bucket -n netobserv -w
```

### 3b. Extract NooBaa credentials and create LokiStack secret

NooBaa automatically creates a ConfigMap and Secret with bucket details:

```bash
BUCKET_NAME=$(oc get configmap loki-bucket -n netobserv \
  -o jsonpath='{.data.BUCKET_NAME}')

ACCESS_KEY=$(oc get secret loki-bucket -n netobserv \
  -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d)

SECRET_KEY=$(oc get secret loki-bucket -n netobserv \
  -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d)

# Use the NooBaa S3 route (reencrypt, cluster-stable)
NOOBAA_ENDPOINT="https://s3-openshift-storage.apps.cluster-cnhmj.dynamic.redhatworkshops.io"

echo "Bucket: ${BUCKET_NAME}"
echo "Endpoint: ${NOOBAA_ENDPOINT}"

oc create secret generic lokistack-s3 \
  -n netobserv \
  --from-literal=bucketnames="${BUCKET_NAME}" \
  --from-literal=endpoint="${NOOBAA_ENDPOINT}" \
  --from-literal=access_key_id="${ACCESS_KEY}" \
  --from-literal=access_key_secret="${SECRET_KEY}" \
  --dry-run=client -o yaml | oc apply -f -
```

### 3c. Extract NooBaa CA cert

```bash
# For external ODF the serving cert is in the s3 route secret
oc get secret \
  $(oc get route s3 -n openshift-storage \
    -o jsonpath='{.spec.tls.destinationCACertificate}' 2>/dev/null || \
  echo "noobaa-s3-serving-cert") \
  -n openshift-storage \
  -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/noobaa-ca.crt

# Fallback: extract from the route's CA
oc get secret router-certs-default \
  -n openshift-ingress \
  -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/noobaa-ca.crt

oc create configmap lokistack-s3-ca \
  -n netobserv \
  --from-file=service-ca.crt=/tmp/noobaa-ca.crt \
  --dry-run=client -o yaml | oc apply -f -
```

---

## 4. Deploy LokiStack (Cluster-Admin, once)

```bash
cat <<EOF | oc apply -f -
apiVersion: loki.grafana.com/v1
kind: LokiStack
metadata:
  name: lokistack
  namespace: netobserv
spec:
  size: 1x.small
  storage:
    schemas:
      - version: v13
        effectiveDate: "2024-01-01"
    secret:
      name: lokistack-s3
      type: s3
    tls:
      caName: lokistack-s3-ca
  storageClassName: ocs-external-storagecluster-ceph-rbd
  tenants:
    mode: openshift-logging
EOF

# Watch for Ready
oc get lokistack lokistack -n netobserv -w
```

---

## 5. Deploy FlowCollector (Cluster-Admin, once)

```bash
cat <<EOF | oc apply -f -
apiVersion: flows.netobserv.io/v1beta2
kind: FlowCollector
metadata:
  name: cluster
spec:
  namespace: netobserv
  deploymentModel: Direct
  agent:
    type: eBPF
    ebpf:
      sampling: 50
      features:
        - DNSTracking
        - FlowRTT
  loki:
    enable: true
    mode: LokiStack
    lokiStack:
      name: lokistack
      namespace: netobserv
  consolePlugin:
    enable: true
EOF

oc get flowcollector cluster
```

---

## 6. Deploy ClusterLogging (Cluster-Admin, once)

```bash
cat <<EOF | oc apply -f -
apiVersion: logging.openshift.io/v1
kind: ClusterLogging
metadata:
  name: instance
  namespace: openshift-logging
spec:
  managementState: Managed
  collection:
    type: vector
EOF
```

---

## 7. Deploy Grafana Instance (Cluster-Admin, once)

```bash
# Grant Grafana SA access to Prometheus
oc adm policy add-cluster-role-to-user \
  cluster-monitoring-view \
  -z grafana-serviceaccount \
  -n grafana

BEARER_TOKEN=$(oc create token grafana-serviceaccount \
  -n grafana --duration=8760h)

cat <<EOF | oc apply -f -
apiVersion: grafana.integreatly.org/v1beta1
kind: Grafana
metadata:
  name: grafana
  namespace: grafana
  labels:
    dashboards: grafana
spec:
  route:
    spec:
      tls:
        termination: edge
  config:
    security:
      admin_user: admin
      admin_password: admin
  datasources:
    - name: Loki
      type: loki
      uid: loki
      url: https://lokistack-gateway-http.netobserv.svc:8080
      access: proxy
      jsonData:
        httpHeaderName1: "X-Scope-OrgID"
        tlsSkipVerify: true
      secureJsonData:
        httpHeaderValue1: "application"
    - name: Prometheus
      type: prometheus
      uid: prometheus
      url: https://thanos-querier.openshift-monitoring.svc:9091
      access: proxy
      jsonData:
        tlsSkipVerify: true
        httpMethod: POST
        httpHeaderName1: "Authorization"
      secureJsonData:
        httpHeaderValue1: "Bearer ${BEARER_TOKEN}"
EOF
```

---

## 8. Full Verification Checklist

```bash
echo "=== ODF External ===" 
oc get storagecluster ocs-external-storagecluster -n openshift-storage \
  -o jsonpath='{.status.phase}' && echo

echo "=== NooBaa ==="
oc get noobaa noobaa -n openshift-storage \
  -o jsonpath='{.status.phase}' && echo
oc get obc loki-bucket -n netobserv \
  -o jsonpath='{.status.phase}' && echo

echo "=== Operators ==="
oc get csv -n openshift-operators | grep netobserv
oc get csv -n openshift-logging | grep logging
oc get csv -n openshift-operators-redhat | grep loki
oc get csv -n grafana | grep grafana

echo "=== LokiStack ==="
oc get lokistack lokistack -n netobserv

echo "=== FlowCollector ==="
oc get flowcollector cluster \
  -o jsonpath='{.status.conditions[*].type}' && echo

echo "=== Pods ==="
oc get pods -n netobserv | grep -v Completed
oc get pods -n openshift-logging | grep -v Completed
oc get pods -n grafana | grep -v Completed
```

---

## 9. What Each Scaffold Creates Per Namespace

| Resource | Namespace | Description |
|---|---|---|
| `ClusterLogForwarder` | `openshift-logging` | Routes namespace logs to Loki |
| `GrafanaDashboard` | `grafana` | Pre-built panels (configurable) |
| `Role` + `RoleBinding` | target namespace | Developer read access scoped to their ns |
| `ClusterRoleBinding` | cluster | NetObserv console plugin access |
| `NetworkPolicy` | target namespace | Allows NetObserv eBPF agent ingress |
| `FlowCollector` patch | cluster | Adds namespace to flow capture filter |
