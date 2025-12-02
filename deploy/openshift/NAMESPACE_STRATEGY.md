# Namespace Strategy: Single vs Multiple Namespaces

**Last Updated:** December 1, 2025

---

## Overview

The Datalyptica platform can be deployed using either:

1. **Multiple Namespaces** (Current design - 5 namespaces)
2. **Single Namespace** (Simplified design - 1 namespace)

Both approaches are valid. Choose based on your requirements.

---

## Comparison

| Aspect                  | Multiple Namespaces      | Single Namespace         |
| ----------------------- | ------------------------ | ------------------------ |
| **Complexity**          | Higher                   | Lower                    |
| **Isolation**           | Strong (per tier)        | Weak (all together)      |
| **Security**            | Granular NetworkPolicies | Single policy            |
| **Resource Management** | Per-tier quotas          | Single quota             |
| **RBAC**                | Per-namespace roles      | Single namespace roles   |
| **Service Discovery**   | FQDN required            | Simple service names     |
| **Deployment Speed**    | Slower (more resources)  | Faster                   |
| **Multi-tenancy Ready** | ✅ Yes                   | ❌ No                    |
| **Best For**            | Production, large teams  | Development, small teams |

---

## Option 1: Multiple Namespaces (Current Design)

### Structure

```
datalyptica-operators    # Operators only
datalyptica-storage      # PostgreSQL, MinIO
datalyptica-control      # Kafka, Schema Registry
datalyptica-data         # Trino, Spark, Flink, Nessie
datalyptica-management   # Grafana, Prometheus, Keycloak
```

### Advantages

✅ **Security Isolation**

- NetworkPolicies can restrict access per tier
- Storage layer can be completely isolated
- Control plane separate from data processing

✅ **Resource Management**

- Different quotas per tier (storage needs more, management needs less)
- Prevents one tier from consuming all resources
- Better capacity planning

✅ **RBAC Granularity**

- Developers can access `datalyptica-data` but not `datalyptica-storage`
- Operators can manage `datalyptica-operators` only
- Security team can restrict `datalyptica-management`

✅ **Scalability**

- Scale tiers independently
- Upgrade tiers separately
- Better for large deployments

✅ **Multi-tenancy Ready**

- Can add tenant namespaces later
- Clear separation of concerns

### Disadvantages

❌ **Complexity**

- More namespaces to manage
- Cross-namespace service discovery requires FQDN
- More RBAC rules

❌ **Deployment Overhead**

- More resources to create
- More configuration files

### When to Use

- **Production environments**
- **Large teams** (different teams manage different tiers)
- **Strict security requirements**
- **Multi-tenant scenarios**
- **Enterprise deployments**

---

## Option 2: Single Namespace (Simplified)

### Structure

```
datalyptica              # Everything in one namespace
```

### Advantages

✅ **Simplicity**

- One namespace to manage
- Simple service discovery (`service-name` instead of `service-name.namespace.svc.cluster.local`)
- Easier to navigate in UI

✅ **Faster Deployment**

- Fewer resources to create
- Simpler scripts

✅ **Easier Development**

- Quick iteration
- Less configuration

✅ **Resource Sharing**

- All components share same quota
- Simpler resource management

### Disadvantages

❌ **Less Isolation**

- All components in same security boundary
- NetworkPolicies apply to everything
- Harder to restrict access per tier

❌ **Resource Competition**

- All components compete for same quota
- One component can starve others

❌ **RBAC Limitations**

- Harder to give granular permissions
- All-or-nothing access

❌ **Not Multi-tenant Ready**

- Would need refactoring later

### When to Use

- **Development/Testing environments**
- **Small teams** (single team manages everything)
- **Proof of concept**
- **Small deployments** (< 10 users)
- **Simplified operations**

---

## Recommendation

### For Production: **Multiple Namespaces** ✅

Reasons:

1. **Security**: Storage layer should be isolated
2. **Compliance**: Easier to meet regulatory requirements
3. **Scalability**: Can scale tiers independently
4. **Team Structure**: Different teams can own different tiers
5. **Future-proof**: Ready for multi-tenancy

### For Development: **Single Namespace** ✅

Reasons:

1. **Simplicity**: Faster to deploy and iterate
2. **Easier debugging**: All resources in one place
3. **Less overhead**: Fewer resources to manage

---

## Migration Path

You can start with **single namespace** and migrate to **multiple namespaces** later:

1. **Phase 1**: Deploy everything in `datalyptica` namespace
2. **Phase 2**: Split out `datalyptica-storage` (PostgreSQL, MinIO)
3. **Phase 3**: Split out `datalyptica-control` (Kafka)
4. **Phase 4**: Split out `datalyptica-management` (monitoring)
5. **Phase 5**: Keep `datalyptica-data` for compute

---

## Single Namespace Configuration

If you choose single namespace, here's the simplified structure:

### Namespace Definition

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: datalyptica
  labels:
    name: datalyptica
    platform: datalyptica
  annotations:
    openshift.io/description: "Datalyptica Platform"
    openshift.io/display-name: "Datalyptica"
```

### Resource Quota (Single)

```yaml
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: datalyptica-quota
  namespace: datalyptica
spec:
  hard:
    requests.cpu: "136" # Sum of all tiers
    requests.memory: "512Gi" # Sum of all tiers
    limits.cpu: "272" # Sum of all tiers
    limits.memory: "1024Gi" # Sum of all tiers
    persistentvolumeclaims: "120"
    requests.storage: "9Ti" # Sum of all tiers
```

### Service Discovery

**Multiple Namespaces:**

```yaml
# Trino connecting to Nessie
TRINO_CATALOG_ICEBERG_NESSIE_CATALOG_URI: "http://nessie.datalyptica-data.svc.cluster.local:19120/api/v2"
```

**Single Namespace:**

```yaml
# Trino connecting to Nessie
TRINO_CATALOG_ICEBERG_NESSIE_CATALOG_URI: "http://nessie:19120/api/v2"
```

Much simpler! ✅

---

## Implementation Guide

### Option A: Use Single Namespace (Simplified)

1. **Create single namespace:**

```bash
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: datalyptica
  labels:
    platform: datalyptica
EOF
```

2. **Update all manifests:**

   - Change `namespace: datalyptica-storage` → `namespace: datalyptica`
   - Change `namespace: datalyptica-control` → `namespace: datalyptica`
   - Change `namespace: datalyptica-data` → `namespace: datalyptica`
   - Change `namespace: datalyptica-management` → `namespace: datalyptica`

3. **Update service references:**

   - Remove `.datalyptica-*.svc.cluster.local` suffixes
   - Use simple service names: `postgresql-rw`, `kafka-bootstrap`, `nessie`

4. **Update scripts:**
   - All scripts reference single namespace: `datalyptica`

### Option B: Keep Multiple Namespaces (Current)

No changes needed - current design is production-ready.

---

## Hybrid Approach (Recommended for Flexibility)

You can use a **hybrid approach**:

```
datalyptica              # Main namespace (most components)
datalyptica-storage      # Only storage (PostgreSQL, MinIO) - isolated
```

**Benefits:**

- Storage layer isolated (security/compliance)
- Everything else together (simplicity)
- Best of both worlds

---

## Decision Matrix

| Requirement           | Single Namespace   | Multiple Namespaces |
| --------------------- | ------------------ | ------------------- |
| **Development**       | ✅ Recommended     | ⚠️ Overkill         |
| **Testing**           | ✅ Recommended     | ⚠️ Overkill         |
| **Small Production**  | ✅ Acceptable      | ✅ Better           |
| **Large Production**  | ❌ Not recommended | ✅ Required         |
| **Multi-tenant**      | ❌ Not possible    | ✅ Required         |
| **Strict Security**   | ❌ Limited         | ✅ Required         |
| **Team Separation**   | ❌ Difficult       | ✅ Easy             |
| **Simple Operations** | ✅ Easy            | ❌ Complex          |

---

## Conclusion

**For most use cases, single namespace is perfectly fine**, especially for:

- Development environments
- Small to medium deployments
- Single-team operations
- Proof of concepts

**Multiple namespaces are better for:**

- Large production deployments
- Multi-tenant scenarios
- Strict security/compliance requirements
- Large teams with role separation

**Recommendation:** Start with **single namespace** for simplicity, migrate to **multiple namespaces** when you need the additional isolation and control.

---

## Quick Switch Script

I can create a script to convert between single and multiple namespace deployments. Would you like me to create that?

---

**Last Updated:** December 1, 2025  
**Version:** 1.0.0
