# Datalyptica OpenShift Deployment - Pre-Requisites

**Date**: December 5, 2025  
**Cluster**: virocp-poc.efinance.com.eg  
**OpenShift Version**: 4.19.19  
**Kubernetes Version**: v1.32.9  
**Deployment Model**: Single Project Architecture

---

## Table of Contents

1. [Environment Validation](#environment-validation)
2. [Project Creation](#project-creation)
3. [Security Configuration](#security-configuration)
4. [Storage Configuration](#storage-configuration)
5. [Secrets Management](#secrets-management)
6. [Operator Group Setup](#operator-group-setup)
7. [Validation Steps](#validation-steps)
8. [Next Steps](#next-steps)

---

## Environment Validation

### Cluster Access Verification

**Objective**: Verify OpenShift CLI access and cluster connectivity

**Commands Executed**:
```bash
# Check oc CLI version
oc version

# Output:
# Client Version: 4.18.12
# Kustomize Version: v5.4.2
# Server Version: 4.19.19
# Kubernetes Version: v1.32.9
```

**Login Process**:
```bash
# Initiate web-based login
oc login https://api.virocp-poc.efinance.com.eg:6443 --web

# Verify authentication
oc whoami
# Output: CN=Karim Hassan,OU=Database,OU=Systems,OU=IT,OU=EFinance,DC=EFinance,DC=com,DC=eg
```

**Cluster Information**:
```bash
# Get cluster info
oc cluster-info
# Output: Kubernetes control plane is running at https://api.virocp-poc.efinance.com.eg:6443

# Get node information
oc get nodes
```

**Cluster Topology Verified**:
| Node Type      | Name         | Status | Role                  | Age  |
| -------------- | ------------ | ------ | --------------------- | ---- |
| Control Plane  | master1-poc  | Ready  | control-plane,master  | 10d  |
| Control Plane  | master2-poc  | Ready  | control-plane,master  | 10d  |
| Control Plane  | master3-poc  | Ready  | control-plane,master  | 10d  |
| Worker         | worker1-poc  | Ready  | worker                | 10d  |
| Worker         | worker2-poc  | Ready  | worker                | 10d  |
| Worker         | worker3-poc  | Ready  | worker                | 10d  |

**Validation Result**: ✅ All nodes healthy, cluster accessible

---

## Project Creation

### Create Datalyptica Project

**Objective**: Create a single unified project for all Datalyptica components

**Command Executed**:
```bash
oc new-project datalyptica \
  --description="Datalyptica Data Platform - Unified Deployment" \
  --display-name="Datalyptica Data Platform"
```

**Output**:
```
Now using project "datalyptica" on server "https://api.virocp-poc.efinance.com.eg:6443".
```

**Validation**:
```bash
# Verify project creation
oc project
# Output: Using project "datalyptica" on server "https://api.virocp-poc.efinance.com.eg:6443".

# Check project details
oc get project datalyptica -o yaml | grep -E "name:|phase:|displayName:"
```

**Project Metadata**:
- **Name**: `datalyptica`
- **Display Name**: `Datalyptica Data Platform`
- **Description**: `Datalyptica Data Platform - Unified Deployment`
- **Status**: `Active`

**Validation Result**: ✅ Project created successfully

---

## Security Configuration

### Security Context Constraints (SCC)

**Objective**: Define security policies for Datalyptica workloads

**File Created**: `deploy/openshift/scc-datalyptica.yaml`

**SCC Configuration**:
```yaml
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: datalyptica-scc
  annotations:
    kubernetes.io/description: "Security Context Constraints for Datalyptica Data Platform"
allowHostDirVolumePlugin: false
allowHostIPC: false
allowHostNetwork: false
allowHostPID: false
allowHostPorts: false
allowPrivilegedContainer: false
allowedCapabilities:
  - NET_BIND_SERVICE
defaultAddCapabilities: []
fsGroup:
  type: MustRunAs
  ranges:
    - min: 1000
      max: 65535
groups: []
priority: 10
readOnlyRootFilesystem: false
requiredDropCapabilities:
  - KILL
  - MKNOD
  - SETUID
  - SETGID
runAsUser:
  type: MustRunAsRange
  uidRangeMin: 1000
  uidRangeMax: 65535
seLinuxContext:
  type: MustRunAs
supplementalGroups:
  type: RunAsAny
users: []
volumes:
  - configMap
  - downwardAPI
  - emptyDir
  - persistentVolumeClaim
  - projected
  - secret
```

**Commands Executed**:
```bash
# Apply SCC
oc apply -f deploy/openshift/scc-datalyptica.yaml
# Output: securitycontextconstraints.security.openshift.io/datalyptica-scc created

# Grant SCC to default service account
oc adm policy add-scc-to-user datalyptica-scc system:serviceaccount:datalyptica:default
# Output: clusterrole.rbac.authorization.k8s.io/system:openshift:scc:datalyptica-scc added: "default"

# Grant SCC to all service accounts in project
oc adm policy add-scc-to-group datalyptica-scc system:serviceaccounts:datalyptica
# Output: clusterrole.rbac.authorization.k8s.io/system:openshift:scc:datalyptica-scc added: "system:serviceaccounts:datalyptica"
```

**Security Features Configured**:
- ✅ Non-privileged containers only
- ✅ UID/GID range: 1000-65535
- ✅ NET_BIND_SERVICE capability allowed (for binding to ports < 1024)
- ✅ Dropped dangerous capabilities (KILL, MKNOD, SETUID, SETGID)
- ✅ Volume types restricted to safe options

**Validation Result**: ✅ SCC created and applied successfully

---

## Storage Configuration

### Storage Class Selection

**Objective**: Identify and use existing storage class for persistent volumes

**Available Storage Classes**:
```bash
oc get storageclass
```

| Storage Class Name                   | Provisioner       | Reclaim Policy | Binding Mode | Expansion |
| ------------------------------------ | ----------------- | -------------- | ------------ | --------- |
| **9500-storageclass** (Selected)     | block.csi.ibm.com | Delete         | Immediate    | true      |
| px-csi-db                            | pxd.portworx.com  | Delete         | Immediate    | true      |
| px-csi-replicated                    | pxd.portworx.com  | Delete         | Immediate    | true      |
| px-rwx-block-kubevirt                | pxd.portworx.com  | Delete         | WaitForFirstConsumer | true |
| px-rwx-file-kubevirt                 | pxd.portworx.com  | Delete         | WaitForFirstConsumer | true |

**Decision**: Use existing `9500-storageclass` (IBM Block Storage)

**Storage Class Details**:
- **Provisioner**: `block.csi.ibm.com` (IBM Block CSI Driver)
- **Reclaim Policy**: Delete
- **Volume Binding Mode**: Immediate
- **Allow Volume Expansion**: Yes
- **Features**: Enterprise-grade block storage with CSI driver

**Validation Result**: ✅ Storage class validated and ready for use

---

## Secrets Management

### Generate Passwords

**Objective**: Create secure random passwords for all platform components

**Commands Executed**:
```powershell
# Generate random 32-character password function
function New-SecurePassword { -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_}) }

# Storage Layer
$postgresPassword = New-SecurePassword
$minioPassword = New-SecurePassword
$redisPassword = New-SecurePassword

# Catalog & Identity
$nessiePassword = New-SecurePassword
$keycloakPassword = New-SecurePassword

# Analytics & Orchestration
$airflowPassword = New-SecurePassword
$jupyterhubPassword = New-SecurePassword
$supersetPassword = New-SecurePassword

# ML & Experimentation
$mlflowPassword = New-SecurePassword
```

### Create Kubernetes Secrets

**Commands Executed**:
```powershell
# 1. Storage Layer Secrets
# PostgreSQL admin credentials (for administrative access only)
# Note: CrunchyData operator automatically creates application database users and secrets
oc create secret generic postgres-credentials -n datalyptica `
  --from-literal=username=postgres `
  --from-literal=password=$postgresPassword

# MinIO root credentials
oc create secret generic minio-credentials -n datalyptica `
  --from-literal=root-user=minio `
  --from-literal=root-password=$minioPassword

# Redis authentication
oc create secret generic redis-credentials -n datalyptica `
  --from-literal=password=$redisPassword

# 2. Catalog Layer Secrets
# Nessie MinIO access credentials (database credentials auto-generated by PostgreSQL operator)
oc create secret generic nessie-minio-credentials -n datalyptica `
  --from-literal=access-key=minio `
  --from-literal=secret-key=$minioPassword

# 3. Identity & Access Management Secrets
# Keycloak admin credentials (database credentials auto-generated by PostgreSQL operator)
oc create secret generic keycloak-admin-credentials -n datalyptica `
  --from-literal=admin-user=admin `
  --from-literal=admin-password=$keycloakPassword

# 4. Analytics & Orchestration Secrets
# Airflow MinIO access credentials (database credentials auto-generated by PostgreSQL operator)
oc create secret generic airflow-minio-credentials -n datalyptica `
  --from-literal=access-key=minio `
  --from-literal=secret-key=$minioPassword

# Note: Superset and JupyterHub database credentials are auto-generated by PostgreSQL operator

# 5. ML & Experimentation Secrets
# MLflow database credentials
oc create secret generic mlflow-db-credentials -n datalyptica `
  --from-literal=username=mlflow `
  --from-literal=password=$mlflowPassword

# MLflow MinIO access credentials
oc create secret generic mlflow-minio-credentials -n datalyptica `
  --from-literal=access-key=minio `
  --from-literal=secret-key=$minioPassword
```

**Validation**:
```powershell
# Verify all secrets created
oc get secrets -n datalyptica | Select-String "credentials"
```

**Secrets Summary**:
| Secret Name                  | Type   | Data Keys                  | Purpose                                      |
| ---------------------------- | ------ | -------------------------- | -------------------------------------------- |
| postgres-credentials         | Opaque | username, password         | PostgreSQL admin (manual access only)        |
| minio-credentials            | Opaque | root-user, root-password   | MinIO root access                            |
| redis-credentials            | Opaque | password                   | Redis authentication                         |
| nessie-minio-credentials     | Opaque | access-key, secret-key     | Nessie S3 access                             |
| keycloak-admin-credentials   | Opaque | admin-user, admin-password | Keycloak admin console                       |
| airflow-minio-credentials    | Opaque | access-key, secret-key     | Airflow S3 access                            |
| mlflow-minio-credentials     | Opaque | access-key, secret-key     | MLflow S3 artifacts access                   |

**Note**: Database user credentials (nessie, keycloak, airflow, superset, jupyterhub, mlflow) are **automatically generated** by the CrunchyData PostgreSQL operator during cluster deployment. These secrets are created with the naming pattern `datalyptica-postgres-pguser-<username>` and include full connection details (host, port, dbname, user, password, uri, jdbc-uri).

**Total Secrets Count**:
- **Manual Secrets**: 8 (created in prerequisites)
- **Auto-generated Secrets**: 6 (created by PostgreSQL operator during deployment)
- **Total**: 14 secrets

**Security Notes**:
- ✅ Manual passwords are 32 characters with mixed alphanumeric
- ✅ Auto-generated passwords use PostgreSQL operator's secure random generation
- ✅ All passwords stored securely in Kubernetes secrets
- ✅ Local password files in `secrets/passwords/` (added to .gitignore)
- ✅ Secrets scoped to datalyptica namespace only
- ✅ Database credentials never stored in Git or configuration files

**Validation Result**: ✅ All 8 manual secrets created successfully (6 database secrets created automatically during PostgreSQL deployment)

---

## Operator Group Setup

### Create OperatorGroup

**Objective**: Configure operator management for the datalyptica project

**File Created**: `deploy/openshift/operator-group.yaml`

**Configuration**:
```yaml
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: datalyptica-operators
  namespace: datalyptica
spec:
  targetNamespaces:
    - datalyptica
```

**Command Executed**:
```bash
oc apply -f deploy/openshift/operator-group.yaml
# Output: operatorgroup.operators.coreos.com/datalyptica-operators created
```

**OperatorGroup Details**:
- **Name**: `datalyptica-operators`
- **Target Namespace**: `datalyptica` (single project)
- **Purpose**: Manages operator installations and upgrades within the project

**Validation**:
```bash
oc get operatorgroup -n datalyptica
```

**Validation Result**: ✅ OperatorGroup created successfully

---

## Validation Steps

### Complete Pre-Deployment Checklist

Run the following commands to verify all pre-requisites are in place:

```bash
# 1. Verify project exists and is active
oc project datalyptica
# Expected: Using project "datalyptica"...

# 2. Verify SCC is created
oc get scc datalyptica-scc
# Expected: NAME              PRIV  CAPS               SELINUX     ...

# 3. Verify SCC is applied to service accounts
oc get clusterrolebinding | grep datalyptica-scc
# Expected: system:openshift:scc:datalyptica-scc entries

# 4. Verify storage class is available
oc get storageclass 9500-storageclass
# Expected: NAME                 PROVISIONER         ...

# 5. Verify all secrets exist
oc get secrets -n datalyptica | grep -E "postgres-credentials|minio-credentials|keycloak-credentials|redis-credentials"
# Expected: 4 secrets listed

# 6. Verify OperatorGroup exists
oc get operatorgroup -n datalyptica
# Expected: datalyptica-operators listed

# 7. Check project resource quota (if any)
oc get resourcequota -n datalyptica
# Expected: No resource quotas (or list existing ones)

# 8. Verify nodes are ready
oc get nodes
# Expected: All nodes in Ready state

# 9. Check available operators in marketplace
oc get packagemanifests -n openshift-marketplace | grep -E "strimzi|postgres|keycloak|prometheus"
# Expected: List of available operators
```

### Pre-Requisites Summary

| Component                  | Status | Notes                                      |
| -------------------------- | ------ | ------------------------------------------ |
| OpenShift Access           | ✅      | User authenticated, cluster accessible     |
| Project Creation           | ✅      | `datalyptica` project active               |
| Security Context           | ✅      | SCC created and applied                    |
| Storage Configuration      | ✅      | Using 9500-storageclass (IBM Block)        |
| Secrets                    | ✅      | 4 secrets created for components           |
| OperatorGroup              | ✅      | Configured for single-project deployment   |
| Cluster Health             | ✅      | 6 nodes (3 masters, 3 workers) all Ready   |
| OpenShift Version          | ✅      | 4.19.19 (exceeds requirement 4.17+)        |
| Kubernetes Version         | ✅      | v1.32.9 (exceeds requirement 1.30+)        |

**All Pre-Requisites Met**: ✅

---

## Next Steps

With all pre-requisites completed, proceed to:

1. **Operator Installation** (See: `DEPLOYMENT-02-OPERATORS.md`)
   - Strimzi Kafka Operator
   - PostgreSQL Operator (Crunchy or Cloud Native)
   - Keycloak Operator
   - Prometheus Operator
   - Grafana Operator

2. **Storage Layer Deployment** (See: `DEPLOYMENT-03-STORAGE.md`)
   - MinIO (Object Storage)
   - PostgreSQL (Relational Database)
   - Redis (Cache & Message Broker)

3. **Catalog Layer Deployment** (See: `DEPLOYMENT-04-CATALOG.md`)
   - Nessie Catalog Service

4. **Streaming Layer Deployment** (See: `DEPLOYMENT-05-STREAMING.md`)
   - Apache Kafka Cluster
   - Schema Registry
   - Kafka Connect

---

## Important Notes

### Single-Project Architecture Benefits

This deployment uses a **single OpenShift project** approach:
- ✅ Simplified RBAC and security management
- ✅ Easier service-to-service communication
- ✅ Reduced operational complexity
- ✅ Faster troubleshooting and debugging
- ✅ All components in one namespace with logical separation via labels

### Labeling Strategy

All resources will be labeled with:
```yaml
labels:
  app.kubernetes.io/part-of: datalyptica
  datalyptica.io/tier: storage|catalog|streaming|processing|query|analytics|iam|monitoring
  datalyptica.io/component: <component-name>
```

### Storage Considerations

- **9500-storageclass** provides IBM Block Storage via CSI
- Volume expansion is supported
- Immediate binding mode (volumes bound immediately on creation)
- Suitable for databases and stateful workloads

### Security Considerations

- All components run as non-root users (UID 1000-65535)
- Passwords are randomly generated and stored in Kubernetes secrets
- SCC restricts dangerous capabilities
- Service accounts have minimal required permissions

---

## Troubleshooting

### Common Issues

**Issue**: Unable to create project
```bash
# Check permissions
oc auth can-i create projects
```

**Issue**: SCC not applied
```bash
# Verify SCC exists
oc get scc datalyptica-scc

# Check service account permissions
oc describe serviceaccount default -n datalyptica
```

**Issue**: Secrets not accessible
```bash
# Verify secrets exist
oc get secrets -n datalyptica

# Check secret contents (keys only)
oc describe secret postgres-credentials -n datalyptica
```

---

**Document Version**: 1.0  
**Last Updated**: December 5, 2025  
**Author**: Datalyptica Deployment Team  
**Cluster**: virocp-poc.efinance.com.eg
