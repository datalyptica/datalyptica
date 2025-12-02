# Secrets Management Guide

**Last Updated:** November 30, 2025  
**Phase:** Phase 2 - Security & High Availability  
**Status:** ✅ Complete - Docker Secrets Implemented

---

## 📋 **Overview**

This guide documents the secrets management implementation for the Datalyptica platform using Docker Secrets. All sensitive data (passwords, access keys) are now stored securely using Docker's built-in secrets mechanism.

---

## 🔐 **What Are Docker Secrets?**

Docker Secrets is a secure way to manage sensitive data in Docker environments:

- **Encrypted at rest** in Docker's internal database
- **Encrypted in transit** when transmitted to containers
- **Mounted as files** in `/run/secrets/` (in-memory tmpfs)
- **Never exposed** in environment variables or logs
- **Access controlled** per service

---

## ✅ **Implemented Secrets**

### **All Secrets (9 Total)**

| Secret Name | Used By | Purpose |
|-------------|---------|---------|
| `postgres_password` | PostgreSQL | Main database password |
| `datalyptica_password` | PostgreSQL | Datalyptica app database password |
| `minio_root_password` | MinIO | Root user password |
| `s3_access_key` | MinIO | S3 API access key |
| `s3_secret_key` | MinIO | S3 API secret key |
| `grafana_admin_password` | Grafana | Admin user password |
| `keycloak_admin_password` | Keycloak | Admin user password |
| `keycloak_db_password` | Keycloak | Database password |
| `clickhouse_password` | ClickHouse | Default user password |

---

## 📁 **Directory Structure**

```
secrets/
├── passwords/           # Docker Secrets directory
│   ├── postgres_password
│   ├── datalyptica_password
│   ├── minio_root_password
│   ├── s3_access_key
│   ├── s3_secret_key
│   ├── grafana_admin_password
│   ├── keycloak_admin_password
│   ├── keycloak_db_password
│   └── clickhouse_password
└── certificates/        # SSL/TLS certificates (separate)
    ├── ca/
    ├── grafana/
    ├── minio/
    └── ...
```

**Security:**
- All files in `secrets/` are in `.gitignore`
- File permissions: `600` (owner read/write only)
- Directory permissions: `700` (owner read/write/execute only)

---

## 🚀 **Generating Secrets**

### **Initial Generation**

```bash
cd /path/to/datalyptica
./scripts/generate-secrets.sh
```

**Output:**
```
✓ Created secret: postgres_password
✓ Created secret: datalyptica_password
✓ Created secret: minio_root_password
... (9 total)
✓ All secrets generated successfully!
```

### **Regenerate All Secrets (Force)**

```bash
FORCE=true ./scripts/generate-secrets.sh
```

### **Generate Single Secret**

```bash
# Generate a new password manually
openssl rand -base64 48 | tr -d "=+/" | cut -c1-32 > secrets/passwords/new_secret
chmod 600 secrets/passwords/new_secret
```

---

## 🔧 **How Secrets Are Used**

### **Docker Compose Configuration**

**Top-level secrets section:**
```yaml
secrets:
  postgres_password:
    file: ../secrets/passwords/postgres_password
  grafana_admin_password:
    file: ../secrets/passwords/grafana_admin_password
  # ... more secrets
```

**Service configuration:**
```yaml
services:
  postgresql:
    environment:
      - POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password
    secrets:
      - postgres_password
```

### **Environment Variable Naming**

Most Docker images support `*_FILE` variants:

- `POSTGRES_PASSWORD` → `POSTGRES_PASSWORD_FILE`
- `MINIO_ROOT_PASSWORD` → `MINIO_ROOT_PASSWORD_FILE`
- `GF_SECURITY_ADMIN_PASSWORD` → `GF_SECURITY_ADMIN_PASSWORD__FILE`

**Note:** Grafana uses double underscore `__FILE`

---

## 📊 **Service Configuration Details**

### **PostgreSQL**

```yaml
environment:
  - POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password
  - DATALYPTICA_PASSWORD_FILE=/run/secrets/datalyptica_password
secrets:
  - postgres_password
  - datalyptica_password
```

**Secrets mounted at:**
- `/run/secrets/postgres_password`
- `/run/secrets/datalyptica_password`

### **MinIO**

```yaml
environment:
  - MINIO_ROOT_PASSWORD_FILE=/run/secrets/minio_root_password
secrets:
  - minio_root_password
  - s3_access_key
  - s3_secret_key
```

**Secrets mounted at:**
- `/run/secrets/minio_root_password`
- `/run/secrets/s3_access_key`
- `/run/secrets/s3_secret_key`

### **Grafana**

```yaml
environment:
  - GF_SECURITY_ADMIN_PASSWORD__FILE=/run/secrets/grafana_admin_password
secrets:
  - grafana_admin_password
```

**Note:** Grafana uses `__FILE` (double underscore)

### **Keycloak**

```yaml
environment:
  - KEYCLOAK_ADMIN_PASSWORD_FILE=/run/secrets/keycloak_admin_password
  - KC_DB_PASSWORD_FILE=/run/secrets/keycloak_db_password
secrets:
  - keycloak_admin_password
  - keycloak_db_password
```

### **ClickHouse**

```yaml
environment:
  - CLICKHOUSE_PASSWORD_FILE=/run/secrets/clickhouse_password
secrets:
  - clickhouse_password
```

---

## 🔄 **Secret Rotation**

### **When to Rotate**

- **Regular schedule:** Every 90 days
- **Security incident:** Immediately
- **Personnel changes:** When team members leave
- **Compliance requirement:** As mandated

### **Rotation Procedure**

**1. Generate New Secrets**

```bash
# Backup old secrets
cp -r secrets/passwords secrets/passwords.backup.$(date +%Y%m%d)

# Generate new secrets
FORCE=true ./scripts/generate-secrets.sh
```

**2. Restart Services**

```bash
cd docker

# Restart services one by one (zero-downtime)
docker compose restart postgresql
docker compose restart minio
docker compose restart grafana
docker compose restart keycloak
docker compose restart clickhouse

# Or restart all
docker compose restart
```

**3. Verify Services**

```bash
# Check all services are healthy
docker ps --filter "name=docker-" --format "table {{.Names}}\t{{.Status}}"

# Test connections
curl -k https://localhost:3443/api/health  # Grafana
curl -k https://localhost:9443/minio/health/live  # MinIO
```

**4. Update Client Credentials**

Update any external applications or scripts that use the old credentials.

**5. Secure Old Secrets**

```bash
# Encrypt and archive old secrets
tar -czf secrets-archive-$(date +%Y%m%d).tar.gz secrets/passwords.backup.*
gpg --encrypt --recipient admin@datalyptica.local secrets-archive-*.tar.gz

# Remove plaintext backups
rm -rf secrets/passwords.backup.*
rm secrets-archive-*.tar.gz
```

---

## 🧪 **Testing Secrets**

### **Verify Secret Files Exist**

```bash
ls -la secrets/passwords/
```

**Expected output:**
```
-rw-------  1 user  staff  32 Nov 30 10:00 postgres_password
-rw-------  1 user  staff  32 Nov 30 10:00 datalyptica_password
-rw-------  1 user  staff  32 Nov 30 10:00 minio_root_password
...
```

### **Verify Secrets in Container**

```bash
# Check secret is mounted
docker exec docker-postgresql ls -la /run/secrets/

# Read secret (for testing only)
docker exec docker-postgresql cat /run/secrets/postgres_password
```

### **Test Database Connection**

```bash
# PostgreSQL
docker exec docker-postgresql psql -U postgres -c "SELECT version();"

# MinIO
docker exec docker-minio mc admin info local
```

---

## 🚨 **Troubleshooting**

### **Service Won't Start**

**Symptom:** Container fails to start with secret-related error

**Solutions:**

```bash
# 1. Verify secret file exists
ls -l secrets/passwords/postgres_password

# 2. Check file permissions
chmod 600 secrets/passwords/*

# 3. Verify docker-compose.yml syntax
cd docker
docker compose config | grep -A 5 secrets:

# 4. Check container logs
docker logs docker-postgresql
```

### **Authentication Failed**

**Symptom:** "authentication failed" or "access denied"

**Solutions:**

```bash
# 1. Verify secret is mounted in container
docker exec docker-postgresql ls -la /run/secrets/

# 2. Check secret content (not empty)
docker exec docker-postgresql wc -c /run/secrets/postgres_password

# 3. Regenerate secrets
FORCE=true ./scripts/generate-secrets.sh
docker compose restart
```

### **Secret File Not Found**

**Symptom:** `no such file or directory: ../secrets/passwords/...`

**Solutions:**

```bash
# 1. Generate secrets
./scripts/generate-secrets.sh

# 2. Check path in docker-compose.yml
cd docker
grep -A 2 "secrets:" docker-compose.yml
```

---

## 🔒 **Security Best Practices**

### **DO:**

✅ **Use Docker Secrets** for all passwords and keys  
✅ **Rotate secrets regularly** (every 90 days)  
✅ **Keep secrets directory** in `.gitignore`  
✅ **Use strong passwords** (32+ characters)  
✅ **Limit access** to secrets directory (chmod 700)  
✅ **Monitor secret access** via container logs  
✅ **Backup secrets securely** (encrypted)  
✅ **Use different secrets** per environment  

### **DON'T:**

❌ **Never commit secrets** to version control  
❌ **Never log secrets** in application logs  
❌ **Never expose secrets** in environment variables  
❌ **Never share secrets** via email/chat  
❌ **Never use default passwords** in production  
❌ **Never store secrets** in plaintext outside `/run/secrets/`  
❌ **Never reuse secrets** across environments  

---

## 📝 **Secret Backup & Recovery**

### **Backup Secrets**

```bash
# Create encrypted backup
tar -czf secrets-backup-$(date +%Y%m%d).tar.gz secrets/passwords/
gpg --encrypt --recipient admin@datalyptica.local secrets-backup-*.tar.gz

# Move to secure location
mv secrets-backup-*.tar.gz.gpg /secure/backup/location/

# Remove plaintext backup
rm secrets-backup-*.tar.gz
```

### **Restore Secrets**

```bash
# Decrypt backup
gpg --decrypt secrets-backup-20251130.tar.gz.gpg > secrets-backup.tar.gz

# Extract secrets
tar -xzf secrets-backup.tar.gz

# Set permissions
chmod 700 secrets/passwords
chmod 600 secrets/passwords/*

# Restart services
cd docker
docker compose restart
```

---

## 🔍 **Audit & Monitoring**

### **Access Logs**

```bash
# Check which containers have access to secrets
docker ps --format "{{.Names}}" | while read container; do
    echo "=== $container ==="
    docker exec $container ls -la /run/secrets/ 2>/dev/null || echo "No secrets"
done
```

### **Secret Usage**

```bash
# List all secrets in use
cd docker
docker compose config | grep -A 10 "^secrets:"

# List services using secrets
docker compose config | grep -B 5 "secrets:" | grep "^  [a-z]"
```

---

## 📚 **Additional Resources**

### **Docker Secrets Documentation**
- [Docker Secrets Official Docs](https://docs.docker.com/engine/swarm/secrets/)
- [Docker Compose Secrets](https://docs.docker.com/compose/compose-file/compose-file-v3/#secrets)

### **Related Datalyptica Docs**
- `docs/SSL_TLS_SETUP.md` - Certificate management
- `../DEPLOYMENT.md` - Deployment procedures
- `../TROUBLESHOOTING.md` - General troubleshooting

### **Security Standards**
- [OWASP Secrets Management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_CheatSheet.html)
- [NIST Password Guidelines](https://pages.nist.gov/800-63-3/sp800-63b.html)

---

## 📞 **Support**

### **Issues?**

1. Check logs: `docker logs <container-name>`
2. Verify secrets: `ls -la secrets/passwords/`
3. Check this guide's Troubleshooting section
4. Regenerate secrets: `FORCE=true ./scripts/generate-secrets.sh`

### **Need Help?**

- Check `TROUBLESHOOTING.md`
- Review Docker Compose logs: `docker compose logs`
- Contact platform team

---

**Document Status:** ✅ **Complete**  
**Last Updated:** November 30, 2025  
**Next Review:** February 28, 2026 (Secret Rotation Due)  
**Maintained By:** Phase 2 - Security & HA Team

