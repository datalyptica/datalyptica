# Datalyptica OpenShift - Namespace Reference

**Platform Name:** Datalyptica (not ShuDL)  
**Namespace Prefix:** `datalyptica-`

---

## Namespace Overview

All Datalyptica platform components are deployed across **5 namespaces**:

| Namespace                  | Purpose             | Components                                        |
| -------------------------- | ------------------- | ------------------------------------------------- |
| **datalyptica-operators**  | Platform operators  | CloudNativePG, Strimzi, MinIO operators           |
| **datalyptica-storage**    | Storage layer       | PostgreSQL (3 replicas), MinIO (4+ nodes)         |
| **datalyptica-control**    | Streaming/messaging | Kafka (3 brokers), Schema Registry, Connect       |
| **datalyptica-data**       | Data processing     | Trino, Spark, Flink, Nessie, ClickHouse, dbt      |
| **datalyptica-management** | Monitoring/IAM      | Grafana, Prometheus, Loki, Keycloak, Alertmanager |

---

## Labels and Selectors

All resources are labeled with:

```yaml
labels:
  platform: datalyptica
  tier: <operators|storage|control|data|management>
```

Use these labels to query resources:

```bash
# Get all Datalyptica namespaces
oc get namespaces -l platform=datalyptica

# Get all pods in platform
oc get pods --all-namespaces -l platform=datalyptica

# Get all services in platform
oc get svc --all-namespaces -l platform=datalyptica
```

---

## Service DNS Names

### Within Same Namespace

```
<service-name>
Example: postgresql-rw
```

### Cross-Namespace

```
<service-name>.<namespace>.svc.cluster.local
Examples:
  postgresql-rw.datalyptica-storage.svc.cluster.local
  nessie.datalyptica-data.svc.cluster.local
  minio.datalyptica-storage.svc.cluster.local:9000
  datalyptica-kafka-kafka-bootstrap.datalyptica-control.svc.cluster.local:9092
```

---

## Resource Quotas

| Namespace                  | CPU Request | Memory Request | CPU Limit | Memory Limit | Storage |
| -------------------------- | ----------- | -------------- | --------- | ------------ | ------- |
| **datalyptica-storage**    | 32 cores    | 128 GiB        | 64 cores  | 256 GiB      | 5 TiB   |
| **datalyptica-control**    | 24 cores    | 64 GiB         | 48 cores  | 128 GiB      | 2 TiB   |
| **datalyptica-data**       | 64 cores    | 256 GiB        | 128 cores | 512 GiB      | 1 TiB   |
| **datalyptica-management** | 16 cores    | 64 GiB         | 32 cores  | 128 GiB      | 1 TiB   |
| **datalyptica-operators**  | N/A         | N/A            | N/A       | N/A          | N/A     |

---

## Correct Naming Convention

✅ **Correct:**

- `datalyptica-storage`
- `datalyptica-control`
- `datalyptica-data`
- `datalyptica-management`
- `datalyptica-operators`
- Labels: `platform: datalyptica`

❌ **Incorrect (old naming):**

- ~~`shudl-storage`~~
- ~~`shudl-control`~~
- ~~`shudl-data`~~
- ~~`shudl-management`~~
- ~~Labels: `platform: shudl`~~

---

## Quick Reference Commands

```bash
# List all namespaces
oc get namespaces -l platform=datalyptica

# Check quota usage
oc describe resourcequota -n datalyptica-storage
oc describe resourcequota -n datalyptica-control
oc describe resourcequota -n datalyptica-data
oc describe resourcequota -n datalyptica-management

# View all resources in a namespace
oc get all -n datalyptica-storage
oc get all -n datalyptica-control
oc get all -n datalyptica-data
oc get all -n datalyptica-management

# Check pods across all namespaces
oc get pods --all-namespaces -l platform=datalyptica
```

---

**Last Updated:** December 1, 2025  
**Version:** 1.0.0 (Corrected Naming)
