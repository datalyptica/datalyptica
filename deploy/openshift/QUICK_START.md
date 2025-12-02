# Datalyptica OpenShift - Quick Start Guide

**Last Updated:** December 1, 2025  
**Deployment Location:** `deploy/openshift/`

---

## 🚀 Quick Deployment (30-60 minutes)

### Prerequisites

- ✅ OpenShift cluster 4.13+ with cluster-admin access
- ✅ `oc` CLI installed and authenticated
- ✅ Storage classes available (fast-ssd, standard)
- ✅ Minimum: 8 nodes (3 control, 5 workers), 136 CPU cores, 512GB RAM

### Step-by-Step Deployment

#### 1. Navigate to OpenShift Directory

```bash
cd deploy/openshift
```

#### 2. Generate Secrets

```bash
./scripts/01-generate-secrets.sh
```

**Output:** Creates `./openshift-secrets/` with all passwords and keys  
**⚠️ IMPORTANT:** Backup these secrets immediately!

#### 3. Login to OpenShift

```bash
oc login https://api.your-cluster.com:6443
oc whoami
oc cluster-info
```

#### 4. Deploy Complete Platform

```bash
./scripts/deploy-all.sh
```

This will:

- ✅ Create 5 namespaces
- ✅ Create all secrets
- ✅ Install operators (CloudNativePG, Strimzi, MinIO)
- ✅ Deploy storage layer (PostgreSQL, MinIO)
- ✅ Deploy control layer (Kafka, Schema Registry)
- ✅ Deploy data layer (Trino, Spark, Flink, Nessie, ClickHouse)
- ✅ Deploy management layer (monitoring, IAM)

**Time:** 30-60 minutes depending on cluster speed

#### 5. Validate Deployment

```bash
./scripts/validate-deployment.sh
```

**Expected:** All tests pass (50+ checks)

---

## 📊 Check Deployment Status

### View All Pods

```bash
oc get pods --all-namespaces -l platform=datalyptica
```

### View Services

```bash
for ns in datalyptica-storage datalyptica-control datalyptica-data datalyptica-management; do
  echo "=== $ns ==="
  oc get svc -n $ns
done
```

### View Routes (External Access)

```bash
oc get routes -n datalyptica-management
```

---

## 🔑 Get Credentials

### Grafana

```bash
echo "Username: $(cat ./openshift-secrets/grafana_admin_user)"
echo "Password: $(cat ./openshift-secrets/grafana_admin_password)"
```

### Keycloak

```bash
echo "Username: $(cat ./openshift-secrets/keycloak_admin_user)"
echo "Password: $(cat ./openshift-secrets/keycloak_admin_password)"
```

### PostgreSQL

```bash
echo "Username: postgres"
echo "Password: $(cat ./openshift-secrets/postgres_password)"
```

### MinIO

```bash
echo "Access Key: $(cat ./openshift-secrets/minio_access_key)"
echo "Secret Key: $(cat ./openshift-secrets/minio_secret_key)"
```

---

## 🌐 Access Services

### Get Grafana URL

```bash
echo "https://$(oc get route grafana -n datalyptica-management -o jsonpath='{.spec.host}')"
```

### Get Keycloak URL

```bash
echo "https://$(oc get route keycloak -n datalyptica-management -o jsonpath='{.spec.host}')"
```

---

## 📝 Common Operations

### Scale Workers

```bash
# Scale Trino workers
oc scale deployment trino-worker --replicas=5 -n datalyptica-data

# Scale Spark workers
oc scale deployment spark-worker --replicas=5 -n datalyptica-data

# Scale Flink TaskManagers
oc scale deployment flink-taskmanager --replicas=5 -n datalyptica-data
```

### View Logs

```bash
# Nessie logs
oc logs -f deployment/nessie -n datalyptica-data

# Trino coordinator logs
oc logs -f deployment/trino-coordinator -n datalyptica-data

# Kafka broker logs
oc logs -f datalyptica-kafka-kafka-0 -n datalyptica-control
```

### Check Resource Usage

```bash
# Pod resource usage
oc top pods -n datalyptica-data

# Node resource usage
oc top nodes

# Storage usage
oc get pvc --all-namespaces -l platform=datalyptica
```

---

## 🔧 Troubleshooting

### Issue: Pods Stuck in Pending

```bash
# Check events
oc get events -n <namespace> --sort-by='.lastTimestamp'

# Check resource quotas
oc describe resourcequota -n <namespace>

# Check storage
oc get pvc -n <namespace>
```

### Issue: Pod Not Starting

```bash
# Describe pod for details
oc describe pod <pod-name> -n <namespace>

# Check logs
oc logs <pod-name> -n <namespace>

# Check previous logs (if crashed)
oc logs <pod-name> -n <namespace> --previous
```

### Issue: Service Not Accessible

```bash
# Check service endpoints
oc get endpoints <service-name> -n <namespace>

# Test service connectivity
oc run test --rm -it --image=busybox --restart=Never -- wget -O- http://<service-name>.<namespace>:8080
```

---

## 🗑️ Uninstall

```bash
./scripts/uninstall.sh
```

**⚠️ WARNING:** This deletes ALL data, including PostgreSQL, MinIO, and Kafka data!

---

## 📚 Full Documentation

- **Complete Guide:** [../../docs/OPENSHIFT_DEPLOYMENT_GUIDE.md](../../docs/OPENSHIFT_DEPLOYMENT_GUIDE.md)
- **Part 2:** [../../docs/OPENSHIFT_DEPLOYMENT_GUIDE_PART2.md](../../docs/OPENSHIFT_DEPLOYMENT_GUIDE_PART2.md)
- **Summary:** [../../OPENSHIFT_DEPLOYMENT_SUMMARY.md](../../OPENSHIFT_DEPLOYMENT_SUMMARY.md)
- **Package Details:** [../../OPENSHIFT_DELIVERY_PACKAGE.md](../../OPENSHIFT_DELIVERY_PACKAGE.md)

---

## ✅ Success Criteria

Your deployment is successful when:

- ✅ `./scripts/validate-deployment.sh` passes all tests
- ✅ All pods are in `Running` state
- ✅ Routes are accessible via browser
- ✅ Can login to Grafana and Keycloak
- ✅ Monitoring dashboards show metrics
- ✅ Logs are visible in Grafana/Loki

---

## 🆘 Need Help?

1. Run validation: `./scripts/validate-deployment.sh`
2. Check logs: `oc logs -f <pod-name> -n <namespace>`
3. Check events: `oc get events -n <namespace>`
4. Review docs: `../../docs/OPENSHIFT_DEPLOYMENT_GUIDE.md`

---

**Quick Start Version:** 1.0  
**Location:** `deploy/openshift/`  
**Status:** ✅ Production Ready
