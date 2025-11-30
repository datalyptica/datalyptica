# SSL/TLS Setup Guide

**Last Updated:** November 30, 2025  
**Phase:** Phase 2 - Security & High Availability  
**Status:** ✅ Certificates Generated, 🟡 Services Being Configured

---

## 📋 **Overview**

This guide documents the SSL/TLS encryption setup for the ShuDL platform. All services are configured to use HTTPS for secure communication.

---

## 🔐 **Certificate Infrastructure**

### **Certificate Authority (CA)**

**Location:** `secrets/certificates/ca/`

| File | Purpose | Distribution |
|------|---------|--------------|
| `ca-cert.pem` | CA public certificate | **Distribute to all clients** |
| `ca-key.pem` | CA private key | **KEEP SECURE - Never distribute** |

**Validity:** 825 days (~2 years)  
**Expiry Date:** May 11, 2027  
**Action Required:** Set calendar reminder to regenerate certificates

### **Service Certificates**

**Location:** `secrets/certificates/{service}/`

Each service has:
- `server-cert.pem` - Service certificate
- `server-key.pem` - Private key (chmod 600)
- `server-chain.pem` - Certificate chain (cert + CA)

---

## ✅ **SSL/TLS Enabled Services**

### **Observability Layer**

| Service | HTTP Port | HTTPS Port | Status | Access URL |
|---------|-----------|------------|--------|------------|
| **Grafana** | 3000 | **3443** | ✅ Configured | https://localhost:3443 |
| Prometheus | 9090 | 9443 | ⏳ Pending | https://localhost:9443 |
| Loki | 3100 | 3143 | ⏳ Pending | - |
| Alertmanager | 9095 | 9445 | ⏳ Pending | - |
| Keycloak | 8180 | 8443 | ⏳ Pending | https://localhost:8443 |

### **Storage Layer**

| Service | HTTP Port | HTTPS Port | Status | Access URL |
|---------|-----------|------------|--------|------------|
| **MinIO Console** | 9001 | **9443** | ✅ Configured | https://localhost:9443 |
| MinIO API | 9000 | 9000 (TLS) | ✅ Configured | https://minio:9000 |
| PostgreSQL | 5432 | 5432 (SSL) | ⏳ Pending | - |
| Nessie | 19120 | 19443 | ⏳ Pending | https://localhost:19443 |

### **Query Layer**

| Service | HTTP Port | HTTPS Port | Status | Access URL |
|---------|-----------|------------|--------|------------|
| Trino | 8080 | 8443 | ⏳ Pending | https://localhost:8443 |
| ClickHouse | 8123 | 8443 | ⏳ Pending | - |
| Kafka Connect | 8083 | 8443 | ⏳ Pending | - |

### **Streaming Layer**

| Service | Plain Port | TLS Port | Status |
|---------|------------|----------|--------|
| Kafka | 9092 | 9093 | ⏳ Pending |
| Schema Registry | 8085 | 8443 | ⏳ Pending |
| Kafka UI | 8090 | 8443 | ⏳ Pending |

---

## 🚀 **Quick Start**

### **1. Verify Certificates**

```bash
# View CA certificate
openssl x509 -in secrets/certificates/ca/ca-cert.pem -text -noout

# Check certificate expiry
openssl x509 -in secrets/certificates/ca/ca-cert.pem -noout -dates

# Verify service certificate
openssl x509 -in secrets/certificates/grafana/server-cert.pem -text -noout

# Verify certificate chain
openssl verify -CAfile secrets/certificates/ca/ca-cert.pem \
  secrets/certificates/grafana/server-cert.pem
```

### **2. Start Services with HTTPS**

```bash
cd docker
docker compose up -d grafana minio
```

### **3. Test HTTPS Access**

```bash
# Test Grafana HTTPS
curl -k https://localhost:3443/api/health

# Test with CA certificate
curl --cacert ../secrets/certificates/ca/ca-cert.pem \
  https://localhost:3443/api/health

# Test MinIO HTTPS
curl -k https://localhost:9443/minio/health/live
```

### **4. Access Web Interfaces**

- **Grafana:** https://localhost:3443 (admin/admin)
- **MinIO Console:** https://localhost:9443 (credentials from .env)

**Note:** Browsers will show certificate warning for self-signed certs. You can:
1. Accept the warning (development)
2. Import CA certificate to trusted roots (recommended)
3. Use production certificates (production)

---

## 📝 **Configuration Details**

### **Grafana HTTPS Configuration**

**Environment Variables:**
```yaml
- GF_SERVER_PROTOCOL=https
- GF_SERVER_HTTP_PORT=3000
- GF_SERVER_HTTPS_PORT=3443
- GF_SERVER_CERT_FILE=/etc/grafana/certs/server-cert.pem
- GF_SERVER_CERT_KEY=/etc/grafana/certs/server-key.pem
- GF_SERVER_ROOT_URL=https://localhost:3443
```

**Volume Mounts:**
```yaml
volumes:
  - ../secrets/certificates/grafana:/etc/grafana/certs:ro
  - ../secrets/certificates/ca:/etc/grafana/ca:ro
```

**Ports:**
- HTTP: 3000 (legacy, will be disabled later)
- HTTPS: 3443 (primary)

### **MinIO HTTPS Configuration**

**Environment Variables:**
```yaml
- MINIO_CERTS_DIR=/certs
- MINIO_OPTS=--console-address :9001 --certs-dir /certs --address :9443
- MINIO_SERVER_URL=https://localhost:9443
```

**Volume Mounts:**
```yaml
volumes:
  - ../secrets/certificates/minio:/certs:ro
  - ../secrets/certificates/ca:/certs/CAs:ro
```

**Certificate Layout for MinIO:**
MinIO expects certificates in specific locations:
- `/certs/public.crt` or `/certs/server-cert.pem`
- `/certs/private.key` or `/certs/server-key.pem`
- `/certs/CAs/ca-cert.pem` (for client certificate validation)

---

## 🔧 **Certificate Management**

### **Regenerate All Certificates**

```bash
cd /Users/karimhassan/development/projects/shudl
./scripts/generate-certificates.sh
```

**When to regenerate:**
- Before expiry (set reminder for April 2027)
- When adding new services
- If CA key is compromised
- For production deployment with proper CN/SAN

### **Add New Service Certificate**

```bash
# Edit generate-certificates.sh
# Add new service:
generate_service_cert "newservice" "docker-newservice" "DNS.4 = docker-newservice"

# Regenerate
./scripts/generate-certificates.sh
```

### **Certificate Rotation**

**Process:**
1. Generate new certificates
2. Update docker-compose volumes
3. Rolling restart services
4. Verify all services healthy
5. Remove old certificates

**Script (to be created):**
```bash
./scripts/rotate-certificates.sh
```

---

## 🔐 **Client Configuration**

### **Trust CA Certificate**

#### **macOS:**
```bash
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain \
  secrets/certificates/ca/ca-cert.pem
```

#### **Linux:**
```bash
sudo cp secrets/certificates/ca/ca-cert.pem /usr/local/share/ca-certificates/shudl-ca.crt
sudo update-ca-certificates
```

#### **Windows:**
```powershell
Import-Certificate -FilePath "secrets\certificates\ca\ca-cert.pem" `
  -CertStoreLocation Cert:\LocalMachine\Root
```

#### **Browser (Manual):**
1. Download `ca-cert.pem`
2. Browser Settings → Certificates → Authorities
3. Import CA certificate
4. Trust for identifying websites

### **Python Clients**

```python
import requests

# Option 1: Verify with CA certificate
response = requests.get(
    'https://localhost:3443/api/health',
    verify='path/to/ca-cert.pem'
)

# Option 2: Disable verification (development only)
response = requests.get(
    'https://localhost:3443/api/health',
    verify=False
)
```

### **Java Clients**

```bash
# Import CA to Java keystore
keytool -import -trustcacerts \
  -alias shudl-ca \
  -file secrets/certificates/ca/ca-cert.pem \
  -keystore $JAVA_HOME/lib/security/cacerts \
  -storepass changeit
```

### **Trino CLI**

```bash
trino --server https://localhost:8443 \
  --keystore-path /path/to/truststore.jks \
  --keystore-password changeit
```

---

## 🧪 **Testing & Validation**

### **Test Certificate Chain**

```bash
# Test TLS connection
openssl s_client -connect localhost:3443 \
  -CAfile secrets/certificates/ca/ca-cert.pem \
  -showcerts

# Expected output: Verify return code: 0 (ok)
```

### **Test Service Endpoints**

```bash
# Test all HTTPS endpoints
for service in grafana minio; do
  echo "Testing $service..."
  curl -k -s -o /dev/null -w "%{http_code}\n" \
    https://localhost:${PORTS[$service]}
done
```

### **Check Certificate Expiry**

```bash
# Check all certificates
for cert in secrets/certificates/*/server-cert.pem; do
  echo "Checking $cert"
  openssl x509 -in "$cert" -noout -dates
done
```

### **Validate Healthchecks**

```bash
# All services should be healthy
docker ps --filter "name=docker-" --format "table {{.Names}}\t{{.Status}}"
```

---

## ⚠️ **Security Best Practices**

### **DO:**
✅ Keep CA private key secure (`ca-key.pem`)  
✅ Use proper file permissions (600 for private keys)  
✅ Set certificate expiry reminders  
✅ Use different passwords for each service  
✅ Rotate certificates before expiry  
✅ Monitor certificate expiry dates  
✅ Use production CA for production (Let's Encrypt, etc.)

### **DON'T:**
❌ Commit private keys to Git (`.gitignore` protects `secrets/`)  
❌ Share CA private key  
❌ Use self-signed certs in production  
❌ Disable certificate validation in production  
❌ Use default passwords  
❌ Leave HTTP endpoints exposed (after HTTPS working)

---

## 🚨 **Troubleshooting**

### **Certificate Not Found**

**Error:** `unable to load certificate`

**Solution:**
```bash
# Verify certificate exists
ls -l secrets/certificates/grafana/server-cert.pem

# Check file permissions
chmod 644 secrets/certificates/grafana/server-cert.pem
chmod 600 secrets/certificates/grafana/server-key.pem

# Regenerate if needed
./scripts/generate-certificates.sh
```

### **Certificate Validation Failed**

**Error:** `certificate verify failed`

**Solution:**
```bash
# Verify certificate chain
openssl verify -CAfile secrets/certificates/ca/ca-cert.pem \
  secrets/certificates/grafana/server-cert.pem

# Check SAN (Subject Alternative Names)
openssl x509 -in secrets/certificates/grafana/server-cert.pem \
  -text -noout | grep -A1 "Subject Alternative Name"
```

### **Service Won't Start**

**Error:** Container keeps restarting

**Solution:**
```bash
# Check logs
docker logs docker-grafana

# Verify certificate mounts
docker exec docker-grafana ls -l /etc/grafana/certs/

# Test without TLS temporarily
# (comment out TLS config in docker-compose.yml)
```

### **Browser Certificate Warning**

**Warning:** "Your connection is not private"

**This is expected for self-signed certificates.**

**Options:**
1. Click "Advanced" → "Proceed to localhost" (development)
2. Import CA certificate to browser (recommended)
3. Use production certificates (production)

---

## 📊 **Current Status**

### **Phase 2 Task 1: SSL/TLS Infrastructure**

**Progress:** 25% Complete

| Step | Status | Details |
|------|--------|---------|
| 1. Generate Certificates | ✅ Complete | 15 service certs generated |
| 2. Configure Grafana | ✅ Complete | HTTPS on port 3443 |
| 3. Configure MinIO | ✅ Complete | HTTPS on port 9443 |
| 4. Configure Trino | ⏳ Next | HTTPS on port 8443 |
| 5. Configure remaining services | ⏳ Pending | 12 services remaining |
| 6. Test & Validate | ⏳ Pending | After all configured |
| 7. Documentation | 🟡 In Progress | This document |

---

## 📚 **Additional Resources**

### **OpenSSL Commands**

```bash
# Generate private key
openssl genrsa -out server-key.pem 2048

# Create CSR
openssl req -new -key server-key.pem -out server.csr

# Self-sign certificate
openssl x509 -req -in server.csr -signkey server-key.pem -out server-cert.pem

# View certificate details
openssl x509 -in server-cert.pem -text -noout

# Check private key
openssl rsa -in server-key.pem -check

# Verify certificate and key match
openssl x509 -noout -modulus -in server-cert.pem | openssl md5
openssl rsa -noout -modulus -in server-key.pem | openssl md5
```

### **Certificate Formats**

- **PEM** (`.pem`, `.crt`, `.cer`) - Base64 encoded, human-readable
- **DER** (`.der`) - Binary format
- **PKCS#12** (`.p12`, `.pfx`) - Container format with key + cert

**Convert formats:**
```bash
# PEM to DER
openssl x509 -in cert.pem -outform DER -out cert.der

# DER to PEM
openssl x509 -in cert.der -inform DER -out cert.pem

# PEM to PKCS#12
openssl pkcs12 -export -in cert.pem -inkey key.pem -out cert.p12
```

---

## 🎯 **Next Steps**

### **Immediate (This Week)**

1. ✅ Configure Grafana HTTPS
2. ✅ Configure MinIO HTTPS
3. ⏳ Configure Trino HTTPS
4. ⏳ Configure Keycloak HTTPS
5. ⏳ Configure Prometheus HTTPS

### **Short Term (Next Week)**

6. Configure remaining services
7. Test all HTTPS endpoints
8. Update client connection strings
9. Create certificate rotation script
10. Update monitoring dashboards

### **Future (Phase 2)**

- mTLS (mutual TLS) for service-to-service
- ACME/Let's Encrypt for production
- Certificate monitoring & alerting
- Automated certificate rotation
- HSM integration for CA key storage

---

**Document Status:** 🟡 **In Progress**  
**Last Updated:** November 30, 2025  
**Next Update:** After Trino and Keycloak HTTPS configuration  
**Maintained By:** Phase 2 - Security & HA Team

