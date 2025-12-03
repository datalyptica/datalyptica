# STEP 2: Operator Installation

**Time Required:** 15-20 minutes  
**Method:** OpenShift Web Console - OperatorHub

---

## WHAT ARE OPERATORS?

Operators are Kubernetes extensions that automate complex application management:

- **Automatic installation** and configuration
- **Self-healing** - automatically restarts failed components
- **Automatic upgrades** - keeps software up-to-date
- **High Availability** - manages multi-node clusters

---

## OPERATORS TO INSTALL

We will install 3 operators for the core infrastructure:

| Operator                      | Purpose                          | Provider                 |
| ----------------------------- | -------------------------------- | ------------------------ |
| **Crunchy Postgres Operator** | PostgreSQL HA cluster management | Crunchy Data (Certified) |
| **MinIO Operator**            | Object storage management        | MinIO Inc (Certified)    |
| **Strimzi Kafka Operator**    | Kafka cluster management         | Red Hat (Community)      |

**Note:** Redis and etcd will be deployed without operators (using StatefulSets).

---

## INSTALLATION INSTRUCTIONS

### Operator 1: Crunchy Postgres Operator

1. **Open OperatorHub:**
   - In OpenShift Console, click **Operators** → **OperatorHub**
2. **Search for Operator:**
   - In search box, type: `postgres`
   - Look for **"Crunchy Postgres for Kubernetes"** or **"PostgreSQL"**
   - Ensure it shows **"Certified"** badge
3. **Install Operator:**
   - Click on the operator tile
   - Click **Install** button
   - Configure installation:
     - **Update channel:** Select `v5` (or latest stable)
     - **Installation mode:** Select `All namespaces on the cluster`
     - **Installed Namespace:** Select `openshift-operators`
     - **Update approval:** Select `Automatic`
   - Click **Install**
4. **Wait for Installation:**

   - Watch for "Installed operator - ready for use" message
   - This may take 2-5 minutes

5. **Verify Installation:**
   - Go to **Operators** → **Installed Operators**
   - Set Project to: `All Projects` (or `openshift-operators`)
   - Find **"Crunchy Postgres for Kubernetes"**
   - Status should show: **Succeeded** with green checkmark

---

### Operator 2: MinIO Operator

1. **Open OperatorHub:**
   - Click **Operators** → **OperatorHub**
2. **Search for Operator:**
   - In search box, type: `minio`
   - Look for **"MinIO Operator"**
   - Should show **"Certified"** or **"Community"** badge
3. **Install Operator:**
   - Click on the operator tile
   - Click **Install** button
   - Configure installation:
     - **Update channel:** Select `stable` (or latest)
     - **Installation mode:** Select `All namespaces on the cluster`
     - **Installed Namespace:** Select `openshift-operators`
     - **Update approval:** Select `Automatic`
   - Click **Install**
4. **Wait for Installation:**

   - Watch for "Installed operator - ready for use" message
   - This may take 2-5 minutes

5. **Verify Installation:**
   - Go to **Operators** → **Installed Operators**
   - Find **"MinIO Operator"**
   - Status should show: **Succeeded** with green checkmark

---

### Operator 3: Strimzi Kafka Operator

1. **Open OperatorHub:**
   - Click **Operators** → **OperatorHub**
2. **Search for Operator:**
   - In search box, type: `strimzi`
   - Look for **"Strimzi"** (Apache Kafka operator)
   - Should show **"Community"** or **"Red Hat"** badge
3. **Install Operator:**
   - Click on the operator tile
   - Click **Install** button
   - Configure installation:
     - **Update channel:** Select `stable` (or latest)
     - **Installation mode:** Select `All namespaces on the cluster`
     - **Installed Namespace:** Select `openshift-operators`
     - **Update approval:** Select `Automatic`
   - Click **Install**
4. **Wait for Installation:**

   - Watch for "Installed operator - ready for use" message
   - This may take 2-5 minutes

5. **Verify Installation:**
   - Go to **Operators** → **Installed Operators**
   - Find **"Strimzi"**
   - Status should show: **Succeeded** with green checkmark

---

## ALTERNATIVE: CLI INSTALLATION

If you prefer using the command line:

```bash
# Apply all operator subscriptions
cat <<EOF | oc apply -f -
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: postgresql-operator
  namespace: openshift-operators
spec:
  channel: v5
  name: postgresql
  source: certified-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: minio-operator
  namespace: openshift-operators
spec:
  channel: stable
  name: minio-operator
  source: certified-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: strimzi-kafka-operator
  namespace: openshift-operators
spec:
  channel: stable
  name: strimzi-kafka-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
EOF

# Watch operator installation
watch oc get csv -n openshift-operators
```

---

## VALIDATION

### Via Web Console:

1. Go to **Operators** → **Installed Operators**
2. Set Project filter to: **All Projects** or **openshift-operators**
3. Verify you see all 3 operators with **Succeeded** status:

   ```
   ✅ Crunchy Postgres for Kubernetes    v5.x.x    Succeeded
   ✅ MinIO Operator                     v5.x.x    Succeeded
   ✅ Strimzi                            0.x.x     Succeeded
   ```

### Via CLI:

```bash
# Check operator CSV (ClusterServiceVersion)
oc get csv -n openshift-operators

# Should show all 3 operators with "Succeeded" in PHASE column
```

---

## TROUBLESHOOTING

### Issue: "Cannot find operator in OperatorHub"

**Possible Causes:**

- OperatorHub not enabled
- Catalog sources not synced

**Solution:**

```bash
# Check if OperatorHub is available
oc get operatorhubs

# Check catalog sources
oc get catalogsource -n openshift-marketplace

# If catalogs show "READY" but operators not visible, wait 5-10 minutes for sync
```

---

### Issue: "Operator stuck in 'Installing' state"

**Possible Causes:**

- Network issues pulling images
- Resource constraints

**Solution:**

```bash
# Check operator pod logs
oc get pods -n openshift-operators
oc logs -n openshift-operators <operator-pod-name>

# Check install plan
oc get installplan -n openshift-operators
oc describe installplan -n openshift-operators <plan-name>

# Wait up to 10-15 minutes for installation to complete
```

---

### Issue: "Operator shows 'Failed' status"

**Possible Causes:**

- Incompatible OpenShift version
- Missing permissions

**Solution:**

```bash
# Delete the failed operator
oc delete csv -n openshift-operators <csv-name>

# Delete subscription
oc delete subscription -n openshift-operators <subscription-name>

# Try alternative operator or check operator documentation for version compatibility
```

---

## WHAT THESE OPERATORS PROVIDE

### Crunchy Postgres Operator

**Custom Resources:**

- `PostgresCluster` - Creates a HA PostgreSQL cluster
- Automatic: Patroni setup, replication, backups, monitoring

### MinIO Operator

**Custom Resources:**

- `Tenant` - Creates a MinIO distributed cluster
- Automatic: Multi-node setup, erasure coding, console

### Strimzi Kafka Operator

**Custom Resources:**

- `Kafka` - Creates a Kafka cluster
- `KafkaTopic` - Manages topics
- `KafkaUser` - Manages users and ACLs

---

## NEXT STEP

Once all 3 operators show **Succeeded** status:

✅ **Proceed to:** `STEP-3-storage-validation.md`

---

**Status:** ☐ Completed  
**Completed On:** ******\_\_\_******  
**Operators Installed:**

- ☐ Crunchy Postgres Operator
- ☐ MinIO Operator
- ☐ Strimzi Kafka Operator

**Notes:**
