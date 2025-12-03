# DATALYPTICA DEPLOYMENT VALIDATION CHECKLIST

Use this checklist to track your deployment progress and validate each component.

**Deployment Date:** ******\_\_\_******  
**Deployed By:** ******\_\_\_******  
**OpenShift Cluster:** ******\_\_\_******  
**Storage Class:** ******\_\_\_******

---

## PHASE 0: PREREQUISITES

### Cluster Access

- [ ] Can log into OpenShift Web Console
- [ ] Can execute `oc` commands from terminal
- [ ] Have cluster admin or project admin role
- [ ] OpenShift version 4.10 or higher

### Resource Availability

- [ ] 10+ worker nodes available
- [ ] 40+ CPU cores available
- [ ] 128Gi+ memory available
- [ ] 500Gi+ storage available

### Storage Configuration

- [ ] Storage class identified: ******\_\_\_******
- [ ] Storage class supports RWO access mode
- [ ] Test PVC successfully created and bound
- [ ] Storage class name updated in ALL YAML files:
  - [ ] `postgresql-ha.yaml`
  - [ ] `redis-sentinel.yaml`
  - [ ] `etcd-cluster.yaml`
  - [ ] `minio-distributed.yaml`

### Namespaces Created

- [ ] `datalyptica-infra` - Active
- [ ] `datalyptica-data` - Active
- [ ] `datalyptica-apps` - Active
- [ ] `datalyptica-monitoring` - Active

### Operators Installed

- [ ] Crunchy Postgres Operator - Status: Succeeded
- [ ] MinIO Operator - Status: Succeeded
- [ ] Strimzi Kafka Operator - Status: Succeeded

**Prerequisites Status:** ☐ Complete (Date: ****\_****)

---

## PHASE 1: CORE INFRASTRUCTURE

### PostgreSQL HA

**Deployment:**

- [ ] `postgresql-ha.yaml` - Storage class updated
- [ ] PostgresCluster created via operator
- [ ] Waited 10 minutes for cluster formation

**Validation:**

- [ ] 3 instance pods running (primary + 2 replicas)
- [ ] 1 repo-host pod running (backups)
- [ ] 2 pgbouncer pods running (connection pooling)
- [ ] PostgresCluster status shows "succeeded"
- [ ] Patroni shows 1 Leader + 2 Replicas
- [ ] All PVCs bound (data + WAL + backups)

**Connection Test:**

```bash
oc exec -n datalyptica-infra <pod-name> -- psql -U postgres -c "SELECT version();"
```

- [ ] Connection successful
- [ ] PostgreSQL 15.x running

**Credentials:**

- [ ] Admin password retrieved and stored
  ```bash
  oc get secret -n datalyptica-infra datalyptica-pg-pguser-postgres \
    -o jsonpath='{.data.password}' | base64 -d
  ```
- [ ] Password: ******\_\_\_******

**Application Databases Created:**

- [ ] Database: `nessie` - User: `nessie` - Password: ******\_\_\_******
- [ ] Database: `airflow` - User: `airflow` - Password: ******\_\_\_******
- [ ] Database: `superset` - User: `superset` - Password: ******\_\_\_******
- [ ] Database: `mlflow` - User: `mlflow` - Password: ******\_\_\_******

**PostgreSQL Status:** ☐ Complete (Date: ****\_****)

---

### Redis Sentinel

**Deployment:**

- [ ] `redis-sentinel.yaml` - Storage class updated
- [ ] Password updated in secret (not default)
- [ ] ConfigMap created
- [ ] StatefulSets created

**Validation:**

- [ ] 3 Redis pods running
- [ ] 3 Sentinel pods running
- [ ] All PVCs bound (3 for Redis data)
- [ ] Redis shows role:master + 2 slaves
- [ ] Sentinel monitoring master

**Connection Test:**

```bash
PASSWORD=$(oc get secret -n datalyptica-infra redis-auth -o jsonpath='{.data.password}' | base64 -d)
oc exec -n datalyptica-infra redis-0 -- redis-cli -a $PASSWORD PING
```

- [ ] Returns: PONG

**Credentials:**

- [ ] Password: ******\_\_\_******

**Redis Status:** ☐ Complete (Date: ****\_****)

---

### etcd Cluster

**Deployment:**

- [ ] `etcd-cluster.yaml` - Storage class updated
- [ ] StatefulSet created
- [ ] Services created (client + headless)

**Validation:**

- [ ] 3 etcd pods running
- [ ] All PVCs bound
- [ ] Cluster health check passes

**Connection Test:**

```bash
oc exec -n datalyptica-infra etcd-0 -- etcdctl \
  --endpoints=http://etcd-0.etcd-headless:2379,http://etcd-1.etcd-headless:2379,http://etcd-2.etcd-headless:2379 \
  endpoint health
```

- [ ] All 3 endpoints healthy

**etcd Status:** ☐ Complete (Date: ****\_****)

---

### MinIO Distributed

**Deployment:**

- [ ] `minio-distributed.yaml` - Storage class updated
- [ ] Root credentials updated (not default)
- [ ] Tenant created via operator
- [ ] Waited 15 minutes for tenant provisioning

**Validation:**

- [ ] 4 MinIO server pods running
- [ ] All PVCs bound (4 x 50Gi = 200Gi)
- [ ] Tenant status shows healthy
- [ ] Console service available

**Route Created:**

```bash
oc create route edge minio-console \
  --service=datalyptica-minio-console \
  --port=9090 \
  -n datalyptica-infra
```

- [ ] Route created
- [ ] Console URL: https://******\_\_\_******

**Console Access:**

- [ ] Can access console via browser
- [ ] Can log in with root credentials
- [ ] Root User: ******\_\_\_******
- [ ] Root Password: ******\_\_\_******

**Buckets Created:**

- [ ] `lakehouse`
- [ ] `warehouse`
- [ ] `bronze`
- [ ] `silver`
- [ ] `gold`
- [ ] `backups`

**MinIO Status:** ☐ Complete (Date: ****\_****)

---

### Phase 1 Summary

**Total Pods:** **\_** / 18
**Total PVCs:** **\_** / ~15 (Bound)
**Total Services:** **\_** / 10+

**Phase 1 Status:** ☐ Complete (Date: ****\_****)

---

## PHASE 2: DATA LAYER

### Nessie Data Catalog

**Deployment:**

- [ ] PostgreSQL nessie database created
- [ ] Password updated in `nessie-deployment.yaml`
- [ ] Connection string verified
- [ ] Deployment created

**Validation:**

- [ ] 2 Nessie pods running
- [ ] Service has ClusterIP
- [ ] API responds to health check

**Connection Test:**

```bash
oc port-forward -n datalyptica-data svc/nessie 19120:19120 &
curl http://localhost:19120/api/v2/config
```

- [ ] Returns JSON configuration

**Route Created (Optional):**

```bash
oc create route edge nessie-api \
  --service=nessie \
  --port=19120 \
  -n datalyptica-data
```

- [ ] Route created (if external access needed)
- [ ] External URL: https://******\_\_\_******

**Default Branch:**

```bash
curl -X POST http://localhost:19120/api/v2/trees \
  -H "Content-Type: application/json" \
  -d '{"name":"main","type":"BRANCH"}'
```

- [ ] "main" branch created
- [ ] Can list branches

**Connection Info:**

- [ ] Internal URL: `http://nessie.datalyptica-data.svc.cluster.local:19120/api/v2`
- [ ] External URL: ******\_\_\_******

**Nessie Status:** ☐ Complete (Date: ****\_****)

---

### Phase 2 Summary

**Total Pods:** **\_** / 2
**Total Services:** **\_** / 1

**Phase 2 Status:** ☐ Complete (Date: ****\_****)

---

## OVERALL DEPLOYMENT STATUS

### Total Resources

**Namespaces:** 4

- [x] datalyptica-infra
- [x] datalyptica-data
- [ ] datalyptica-apps (for future)
- [ ] datalyptica-monitoring (for future)

**Pods:** **\_** / 20 (18 infra + 2 data)

**Services:** **\_** / 11+

**PVCs:** **\_** / ~15

**Storage Used:** **\_** / 275Gi+

### Connectivity Matrix

Test connectivity between services:

| From     | To            | Test Command                                                        | Status |
| -------- | ------------- | ------------------------------------------------------------------- | ------ |
| Nessie   | PostgreSQL    | `psql -h datalyptica-pg-primary -U nessie -d nessie -c "SELECT 1;"` | ☐      |
| Any Pod  | Redis         | `redis-cli -h redis -a <password> PING`                             | ☐      |
| Any Pod  | etcd          | `etcdctl --endpoints=http://etcd:2379 endpoint health`              | ☐      |
| Any Pod  | MinIO         | `curl http://minio:80/minio/health/live`                            | ☐      |
| External | MinIO Console | Open browser to route URL                                           | ☐      |
| External | Nessie API    | `curl https://<route>/api/v2/config`                                | ☐      |

---

## HIGH AVAILABILITY VALIDATION

### PostgreSQL Failover Test

```bash
# Delete primary pod
oc delete pod -n datalyptica-infra <primary-pod-name>

# Watch failover (should take < 30 seconds)
watch oc exec -n datalyptica-infra <replica-pod> -- patronictl list
```

- [ ] Replica promoted to primary
- [ ] New primary accepting connections
- [ ] Deleted pod restarted as replica
- [ ] Failover time: **\_** seconds

### Redis Failover Test

```bash
# Get current master
MASTER=$(oc exec -n datalyptica-infra redis-sentinel-0 -- \
  redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster | head -1)

# Delete master pod
oc delete pod -n datalyptica-infra redis-0

# Watch Sentinel elect new master (should take < 20 seconds)
watch oc exec -n datalyptica-infra redis-sentinel-0 -- \
  redis-cli -p 26379 SENTINEL masters
```

- [ ] New master elected
- [ ] Sentinel updated configuration
- [ ] Deleted pod restarted as replica
- [ ] Failover time: **\_** seconds

### MinIO Node Failure Test

```bash
# Delete one MinIO pod
oc delete pod -n datalyptica-infra minio-pool-0-0

# MinIO should continue serving (no downtime)
# Upload test file
oc exec -n datalyptica-infra minio-pool-0-1 -- \
  mc cp /etc/hosts local/lakehouse/test.txt
```

- [ ] MinIO continues serving during pod deletion
- [ ] Pod restarts automatically
- [ ] Cluster rebuilds (if needed)
- [ ] Downtime: **\_** seconds (should be 0)

---

## CREDENTIALS SUMMARY

**Store these securely in a password manager!**

### PostgreSQL

- Host: `datalyptica-pg-pgbouncer.datalyptica-infra.svc.cluster.local:5432`
- Admin User: `postgres`
- Admin Password: ******\_\_\_******
- Nessie Password: ******\_\_\_******
- Airflow Password: ******\_\_\_******
- Superset Password: ******\_\_\_******
- MLflow Password: ******\_\_\_******

### Redis

- Host: `redis-sentinel.datalyptica-infra.svc.cluster.local:26379`
- Master Name: `mymaster`
- Password: ******\_\_\_******

### MinIO

- API Endpoint: `http://minio.datalyptica-infra.svc.cluster.local:80`
- Console URL: https://******\_\_\_******
- Root User: ******\_\_\_******
- Root Password: ******\_\_\_******

### Nessie

- Internal URL: `http://nessie.datalyptica-data.svc.cluster.local:19120/api/v2`
- External URL: https://******\_\_\_******

---

## ISSUES LOG

Document any issues encountered during deployment:

| Issue | Component | Date | Resolution | Status |
| ----- | --------- | ---- | ---------- | ------ |
|       |           |      |            |        |
|       |           |      |            |        |
|       |           |      |            |        |

---

## DEPLOYMENT COMPLETE ✅

**Total Deployment Time:** ******\_\_\_******

**Next Steps:**

1. [ ] Set up monitoring (Prometheus, Grafana)
2. [ ] Configure backup schedules
3. [ ] Deploy application services (Kafka, Trino, Flink, etc.)
4. [ ] Document runbooks for operations team
5. [ ] Train users on platform access

**Signed Off By:** ******\_\_\_******  
**Date:** ******\_\_\_******
