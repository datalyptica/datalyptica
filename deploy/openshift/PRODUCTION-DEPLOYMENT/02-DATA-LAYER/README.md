# PHASE 2: DATA LAYER DEPLOYMENT

**Time Required:** 15 minutes  
**Components:** Nessie (Data Catalog)

---

## 📋 OVERVIEW

In this phase, you will deploy Nessie, the data catalog service that provides:

- **Git-like version control** for data tables
- **Table metadata management**
- **Iceberg catalog** for data lakehouse
- **Multi-table transactions**

| Service    | Purpose                   | HA Mode    | Pods | Storage         |
| ---------- | ------------------------- | ---------- | ---- | --------------- |
| **Nessie** | Data catalog & versioning | 2 replicas | 2    | Uses PostgreSQL |

---

## 🔗 DEPENDENCIES

**IMPORTANT:** Before deploying Nessie, ensure:

- [ ] **Phase 1 Complete** - All core infrastructure running
- [ ] **PostgreSQL Running** - Nessie requires PostgreSQL backend
- [ ] **Nessie Database Created** - Database and user created in PostgreSQL
- [ ] **PostgreSQL Connection Tested** - Can connect from within cluster

---

## 📝 PRE-DEPLOYMENT CHECKLIST

### Verify PostgreSQL is Ready

```bash
# Check PostgreSQL pods
oc get pods -n datalyptica-infra -l postgres-operator.crunchydata.com/cluster=datalyptica-pg

# All pods should be Running
```

### Create Nessie Database (if not already done)

```bash
# Get PostgreSQL primary pod
POD=$(oc get pods -n datalyptica-infra \
  -l postgres-operator.crunchydata.com/cluster=datalyptica-pg \
  -l postgres-operator.crunchydata.com/role=master \
  -o name | head -1)

# Create database and user
oc exec -n datalyptica-infra $POD -- psql -U postgres <<EOF
CREATE DATABASE nessie;
CREATE USER nessie WITH ENCRYPTED PASSWORD 'nessie-secure-password-123';
GRANT ALL PRIVILEGES ON DATABASE nessie TO nessie;
EOF

# Verify database created
oc exec -n datalyptica-infra $POD -- psql -U postgres -c "\l" | grep nessie
```

**IMPORTANT:** Remember the password you set! You'll need it in the YAML.

---

## 🚀 DEPLOYMENT STEPS

### Deploy Nessie

**Steps:**

1. **Open `nessie-deployment.yaml` in text editor**

2. **Update PostgreSQL Password:**

   - Find the line: `password: "nessie-secure-password-123"`
   - Replace with the password you set when creating the database

3. **Update PostgreSQL Connection String (if needed):**

   - Default: `jdbc:postgresql://datalyptica-pg-primary.datalyptica-infra.svc.cluster.local:5432/nessie`
   - Only change if you modified PostgreSQL service name

4. **Save the file**

5. **In OpenShift Console:**

   - Click **+** (plus icon) in top-right corner
   - Switch to project: `datalyptica-data`
   - Paste entire contents of `nessie-deployment.yaml`
   - Click **Create**

6. **Wait for deployment** (2-3 minutes)

7. **Validate** (see validation section below)

---

## ✅ VALIDATION

### Check Pods

```bash
# Should see 2 Nessie pods running
oc get pods -n datalyptica-data -l app=nessie

# Expected output:
# NAME                      READY   STATUS    RESTARTS   AGE
# nessie-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
# nessie-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
```

### Check Service

```bash
# Check Nessie service
oc get svc -n datalyptica-data nessie

# Should show ClusterIP assigned
```

### Test Nessie API

```bash
# Port forward to access locally
oc port-forward -n datalyptica-data svc/nessie 19120:19120 &

# Test API (in another terminal)
curl http://localhost:19120/api/v2/config

# Should return JSON with Nessie configuration

# Kill port forward when done
kill %1
```

### Create Default Branch

```bash
# Port forward if not already done
oc port-forward -n datalyptica-data svc/nessie 19120:19120 &

# Create main branch
curl -X POST http://localhost:19120/api/v2/trees \
  -H "Content-Type: application/json" \
  -d '{"name":"main","type":"BRANCH"}'

# List branches
curl http://localhost:19120/api/v2/trees

# Should show "main" branch

# Kill port forward
kill %1
```

---

## 🌐 CREATE ROUTE (For External Access)

If you need to access Nessie API from outside the cluster:

```bash
# Create OpenShift route
oc create route edge nessie-api \
  --service=nessie \
  --port=19120 \
  -n datalyptica-data

# Get route URL
NESSIE_URL=$(oc get route -n datalyptica-data nessie-api -o jsonpath='{.spec.host}')
echo "Nessie API URL: https://$NESSIE_URL"

# Test external access
curl https://$NESSIE_URL/api/v2/config
```

---

## 📊 NESSIE CONNECTION INFO

For applications that need to connect to Nessie:

**Internal (from within OpenShift cluster):**

```
URL: http://nessie.datalyptica-data.svc.cluster.local:19120/api/v2
Protocol: HTTP
```

**External (if route created):**

```
URL: https://<route-host>/api/v2
Protocol: HTTPS (TLS)
```

**For Spark/Trino Configuration:**

```properties
# Nessie catalog configuration
nessie.uri=http://nessie.datalyptica-data.svc.cluster.local:19120/api/v2
nessie.ref=main
nessie.authentication.type=NONE
```

---

## 🆘 TROUBLESHOOTING

### Pods CrashLooping

**Check logs:**

```bash
oc logs -n datalyptica-data -l app=nessie --tail=50
```

**Common Issues:**

1. **"Connection refused to PostgreSQL"**

   - **Solution:** Verify PostgreSQL is running and accessible

   ```bash
   oc get pods -n datalyptica-infra | grep postgres
   ```

2. **"Authentication failed for user nessie"**

   - **Solution:** Password mismatch between secret and PostgreSQL

   ```bash
   # Check secret
   oc get secret -n datalyptica-data nessie-postgres-secret -o yaml

   # Reset password in PostgreSQL
   POD=$(oc get pods -n datalyptica-infra -l postgres-operator.crunchydata.com/role=master -o name | head -1)
   oc exec -n datalyptica-infra $POD -- psql -U postgres -c "ALTER USER nessie WITH PASSWORD 'new-password';"

   # Update secret
   oc delete secret -n datalyptica-data nessie-postgres-secret
   # Redeploy with correct password
   ```

3. **"Database nessie does not exist"**
   - **Solution:** Create the database (see pre-deployment checklist)

### API Not Responding

**Check service endpoints:**

```bash
# Check if service has endpoints
oc get endpoints -n datalyptica-data nessie

# If no endpoints, pods might not be ready
oc describe pods -n datalyptica-data -l app=nessie
```

### Readiness Probe Failing

**Check Nessie startup:**

```bash
# Watch logs for startup
oc logs -n datalyptica-data -l app=nessie -f

# Look for:
# - Database connection established
# - "Nessie server started"
# - Port 19120 listening
```

---

## 🧪 TESTING NESSIE

### Create Test Namespace

```bash
# Port forward
oc port-forward -n datalyptica-data svc/nessie 19120:19120 &

# Create test branch
curl -X POST http://localhost:19120/api/v2/trees \
  -H "Content-Type: application/json" \
  -d '{"name":"test-branch","type":"BRANCH","hash":"<main-hash>"}'

# List all branches
curl http://localhost:19120/api/v2/trees

# Delete test branch
curl -X DELETE http://localhost:19120/api/v2/trees/test-branch

# Kill port forward
kill %1
```

### Verify Database Connection

```bash
# Connect to PostgreSQL
POD=$(oc get pods -n datalyptica-infra -l postgres-operator.crunchydata.com/role=master -o name | head -1)

# Check Nessie tables
oc exec -n datalyptica-infra $POD -- psql -U postgres -d nessie -c "\dt"

# Should show Nessie internal tables
```

---

## 📈 MONITORING

### Check Resource Usage

```bash
# Pod resource usage
oc adm top pods -n datalyptica-data

# Expected:
# CPU: 50-200m per pod
# Memory: 500Mi-1Gi per pod
```

### Check Logs

```bash
# View logs
oc logs -n datalyptica-data -l app=nessie --tail=100

# Follow logs
oc logs -n datalyptica-data -l app=nessie -f

# Logs from specific pod
oc logs -n datalyptica-data <pod-name>
```

---

## 🎯 SUCCESS CRITERIA

Phase 2 is complete when:

- [ ] 2 Nessie pods running in `datalyptica-data` namespace
- [ ] Nessie service has ClusterIP assigned
- [ ] Can access Nessie API (returns JSON response)
- [ ] Default "main" branch created
- [ ] Connection info documented
- [ ] Route created (if external access needed)

---

## 📝 POST-DEPLOYMENT TASKS

### Document Connection Details

**Record the following:**

1. **Internal URL:** `http://nessie.datalyptica-data.svc.cluster.local:19120/api/v2`
2. **External URL (if route created):** `https://<route-host>/api/v2`
3. **PostgreSQL Database:** `nessie` on `datalyptica-pg-primary`
4. **Default Branch:** `main`

### Configure Applications

Update your Spark, Trino, and Flink configurations to use Nessie:

**Spark:**

```properties
spark.sql.catalog.nessie=org.apache.iceberg.spark.SparkCatalog
spark.sql.catalog.nessie.catalog-impl=org.apache.iceberg.nessie.NessieCatalog
spark.sql.catalog.nessie.uri=http://nessie.datalyptica-data.svc.cluster.local:19120/api/v2
spark.sql.catalog.nessie.ref=main
spark.sql.catalog.nessie.warehouse=s3a://lakehouse/
```

**Trino:**

```properties
connector.name=iceberg
iceberg.catalog.type=nessie
iceberg.nessie-catalog.uri=http://nessie.datalyptica-data.svc.cluster.local:19120/api/v2
iceberg.nessie-catalog.ref=main
```

---

## ➡️ NEXT STEPS

Congratulations! You've completed the core infrastructure and data layer deployment.

**What's Next:**

1. ✅ **Verify HA** - Test failover scenarios for PostgreSQL and Redis
2. ✅ **Configure Backups** - Set up backup schedules
3. ✅ **Deploy Monitoring** - Add Prometheus and Grafana (optional)
4. ➡️ **Deploy Application Services** - Kafka, Trino, Flink, Spark, etc.

---

**Status:** ☐ Completed  
**Completed On:** ******\_\_\_******  
**Deployment Time:** ******\_\_\_******

**Components Status:**

- ☐ Nessie - 2 pods running
- ☐ Default branch created
- ☐ Route created (if needed)
- ☐ Connection info documented

**Notes:**
