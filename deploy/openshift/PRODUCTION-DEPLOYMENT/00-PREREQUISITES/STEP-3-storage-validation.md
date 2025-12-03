# STEP 3: Storage Validation

**Time Required:** 5 minutes  
**Method:** OpenShift Web Console + CLI

---

## WHY VALIDATE STORAGE?

Before deploying databases and stateful applications, we must ensure:

- ✅ Storage classes are available
- ✅ Storage has sufficient capacity
- ✅ Storage supports the required access modes (RWO)

---

## STORAGE REQUIREMENTS

### For Core Infrastructure:

| Component            | Storage Type | Size                    | Access Mode   |
| -------------------- | ------------ | ----------------------- | ------------- |
| PostgreSQL (per pod) | RWO          | 10Gi (data) + 5Gi (WAL) | ReadWriteOnce |
| Redis (per pod)      | RWO          | 5Gi                     | ReadWriteOnce |
| etcd (per pod)       | RWO          | 5Gi                     | ReadWriteOnce |
| MinIO (per pod)      | RWO          | 50Gi                    | ReadWriteOnce |
| PostgreSQL Backups   | RWO          | 50Gi                    | ReadWriteOnce |

**Total Storage Required:** ~500Gi (with 3 replicas for each service)

---

## VALIDATION STEPS

### Step 1: Check Available Storage Classes

**Via Web Console:**

1. Navigate to **Storage** → **StorageClasses**
2. Review available storage classes
3. Note the name of a storage class that supports **RWO** (ReadWriteOnce)

**Via CLI:**

```bash
# List all storage classes
oc get storageclass

# Example output:
# NAME                          PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE
# gp2 (default)                 kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer
# gp3                           ebs.csi.aws.com         Delete          WaitForFirstConsumer
# standard                      kubernetes.io/rbd       Delete          Immediate
```

**Identify Your Storage Class:**

- Look for `(default)` annotation, or
- Choose one that's commonly used in your cluster
- **Write it down:** **********\_\_\_********** (you'll need this!)

---

### Step 2: Verify Storage Class Capabilities

**Via Web Console:**

1. Click on your chosen storage class
2. Verify it supports:
   - **Volume Mode:** Filesystem
   - **Access Modes:** ReadWriteOnce (RWO)
   - **Provisioner:** Should be cloud provider or Ceph/NFS

**Via CLI:**

```bash
# Get detailed info about storage class
oc describe storageclass <your-storage-class-name>

# Check for:
# - Provisioner: Should be valid (aws-ebs, csi.ceph.com, etc.)
# - Parameters: Should be configured
# - AllowVolumeExpansion: True (recommended)
```

---

### Step 3: Test Storage Provisioning (Optional but Recommended)

**Create a test PVC:**

```bash
# Create a test PVC
cat <<EOF | oc apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: storage-test
  namespace: datalyptica-infra
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: <YOUR-STORAGE-CLASS>  # Replace with your storage class
EOF

# Check if PVC gets bound
oc get pvc -n datalyptica-infra storage-test

# Expected output:
# NAME           STATUS   VOLUME          CAPACITY   ACCESS MODES   STORAGECLASS   AGE
# storage-test   Bound    pvc-xxxxx...    1Gi        RWO            gp2            10s
```

**If PVC is Bound - Success! ✅**

**Clean up test PVC:**

```bash
oc delete pvc -n datalyptica-infra storage-test
```

---

### Step 4: Check Cluster Storage Capacity

**Via CLI:**

```bash
# Check overall cluster capacity
oc get nodes -o custom-columns=NAME:.metadata.name,CAPACITY:.status.capacity.ephemeral-storage

# Check existing PVC usage
oc get pvc --all-namespaces

# Calculate available storage
# Ensure you have at least 500Gi available across nodes
```

---

## CONFIGURATION TASK

### Update Storage Class in YAML Files

You need to update the storage class name in all deployment YAML files.

**Your Storage Class Name:** **********\_\_\_**********

**Files to Update (do this before deploying each component):**

1. `01-CORE-INFRASTRUCTURE/postgresql-ha.yaml`
2. `01-CORE-INFRASTRUCTURE/redis-sentinel.yaml`
3. `01-CORE-INFRASTRUCTURE/etcd-cluster.yaml`
4. `01-CORE-INFRASTRUCTURE/minio-distributed.yaml`

**What to Change:**
Search for: `storageClassName: standard`
Replace with: `storageClassName: <YOUR-STORAGE-CLASS>`

**Example:**

```yaml
# BEFORE:
storageClassName: standard

# AFTER (if your storage class is 'gp3'):
storageClassName: gp3
```

---

## STORAGE CLASS RECOMMENDATIONS

### AWS EBS

- **Recommended:** `gp3` or `gp2`
- **Performance:** Good for databases
- **Cost:** Moderate

### Azure Disk

- **Recommended:** `managed-premium`
- **Performance:** SSD-backed, good for databases
- **Cost:** Higher but worth it for production

### Google Cloud

- **Recommended:** `pd-ssd`
- **Performance:** SSD, excellent for databases
- **Cost:** Moderate

### On-Premise (Ceph/Rook)

- **Recommended:** `rook-ceph-block` or `ceph-rbd`
- **Performance:** Depends on cluster setup
- **Cost:** Infrastructure cost

### NFS (Not Recommended for Databases)

- **Note:** NFS/RWX not recommended for PostgreSQL, Redis, etcd
- **Use Case:** Only for shared storage (logs, backups)

---

## TROUBLESHOOTING

### Issue: "No storage classes available"

**Solution:**

```bash
# Check if storage provisioner is installed
oc get pods -n kube-system | grep -E 'storage|provisioner|csi'

# If missing, contact cluster administrator to install storage provisioner
```

---

### Issue: "PVC stuck in Pending state"

**Possible Causes:**

- Storage class doesn't exist
- Insufficient storage capacity
- Storage provisioner not working

**Solution:**

```bash
# Check PVC events
oc describe pvc -n datalyptica-infra <pvc-name>

# Look for error messages in Events section
# Common errors:
# - "no persistent volumes available" → Need more storage capacity
# - "unknown storage class" → Storage class name incorrect
# - "failed to provision volume" → Storage provisioner issue
```

---

### Issue: "Storage class not default"

**Solution:**
You can manually set a default storage class:

```bash
# Remove default from existing class
oc patch storageclass <old-default-class> -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

# Set new default
oc patch storageclass <your-storage-class> -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

---

## VALIDATION CHECKLIST

Before proceeding, ensure:

- [ ] Storage class identified and noted: **********\_\_\_**********
- [ ] Storage class supports RWO access mode
- [ ] Storage class has provisioner configured
- [ ] Test PVC successfully bound (optional)
- [ ] Cluster has 500Gi+ available capacity
- [ ] You know how to update storageClassName in YAML files

---

## NEXT STEP

Once storage is validated and you have noted your storage class name:

✅ **Proceed to:** `../01-CORE-INFRASTRUCTURE/README.md`

---

**Status:** ☐ Completed  
**Completed On:** ******\_\_\_******  
**Storage Class Name:** **********\_\_\_**********  
**Storage Provisioner:** **********\_\_\_**********  
**Available Capacity:** **********\_\_\_**********

**Notes:**
