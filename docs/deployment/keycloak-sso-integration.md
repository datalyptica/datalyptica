# Keycloak SSO Integration Guide

## Overview

Keycloak has been deployed as the centralized Identity and Access Management (IAM) solution for ShuDL. This guide covers the Keycloak setup, realm configuration, and integration with Grafana, Trino, and MinIO.

## Deployment Status

✅ **Keycloak 23.0** deployed and running  
✅ **PostgreSQL backend** configured  
✅ **Admin console** accessible at http://localhost:8180  
✅ **Health endpoint** operational

## Access Information

### Admin Console

- **URL**: http://localhost:8180
- **Admin Username**: `admin`
- **Admin Password**: `admin` (change in production!)

### Database

- **Database**: `keycloak`
- **User**: `keycloak_user`
- **Password**: `keycloak_dev_pass`
- **Host**: `postgresql:5432` (internal)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Management Network                        │
│  ┌────────────┐    ┌──────────┐    ┌──────────┐           │
│  │  Keycloak  │───▶│  Grafana │    │   MinIO  │           │
│  │   (SSO)    │    │ (AuthN)  │    │ (AuthN)  │           │
│  └─────┬──────┘    └──────────┘    └──────────┘           │
│        │                                                     │
└────────┼─────────────────────────────────────────────────────┘
         │
         │ (OAuth2/OIDC)
         │
┌────────┼─────────────────────────────────────────────────────┐
│        │          Storage Network                            │
│  ┌─────▼──────┐    ┌──────────┐                            │
│  │ PostgreSQL │    │  Nessie  │                            │
│  │  (Metadata)│    │(Catalog) │                            │
│  └────────────┘    └──────────┘                            │
└─────────────────────────────────────────────────────────────┘
```

## Initial Setup

### 1. Access Admin Console

Navigate to http://localhost:8180 and login with admin credentials.

### 2. Create ShuDL Realm

```bash
# Option A: Via Admin Console
1. Navigate to: http://localhost:8180/admin
2. Click "Create Realm"
3. Name: "shudl"
4. Enabled: ON
5. Click "Create"

# Option B: Via Keycloak CLI
docker exec -it docker-keycloak /opt/keycloak/bin/kcadm.sh create realms \
  -s realm=shudl \
  -s enabled=true \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin
```

### 3. Create OAuth2 Clients

#### Grafana Client

```bash
# Create Grafana client
docker exec -it docker-keycloak /opt/keycloak/bin/kcadm.sh create clients \
  -r shudl \
  -s clientId=grafana \
  -s 'redirectUris=["http://localhost:3000/*"]' \
  -s 'webOrigins=["http://localhost:3000"]' \
  -s publicClient=false \
  -s 'standardFlowEnabled=true' \
  -s 'directAccessGrantsEnabled=false' \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin

# Get client secret
docker exec -it docker-keycloak /opt/keycloak/bin/kcadm.sh get clients \
  -r shudl \
  --fields id,clientId \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin | grep -A1 '"clientId" : "grafana"'
```

#### Trino Client

```bash
# Create Trino client
docker exec -it docker-keycloak /opt/keycloak/bin/kcadm.sh create clients \
  -r shudl \
  -s clientId=trino \
  -s 'redirectUris=["http://localhost:8080/oauth2/callback"]' \
  -s 'webOrigins=["http://localhost:8080"]' \
  -s publicClient=false \
  -s 'standardFlowEnabled=true' \
  -s 'directAccessGrantsEnabled=false' \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin
```

#### MinIO Client

```bash
# Create MinIO client
docker exec -it docker-keycloak /opt/keycloak/bin/kcadm.sh create clients \
  -r shudl \
  -s clientId=minio \
  -s 'redirectUris=["http://localhost:9001/*"]' \
  -s 'webOrigins=["http://localhost:9001"]' \
  -s publicClient=false \
  -s 'standardFlowEnabled=true' \
  -s 'directAccessGrantsEnabled=true' \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin
```

### 4. Create Users and Groups

```bash
# Create admin group
docker exec -it docker-keycloak /opt/keycloak/bin/kcadm.sh create groups \
  -r shudl \
  -s name=admins \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin

# Create data engineer group
docker exec -it docker-keycloak /opt/keycloak/bin/kcadm.sh create groups \
  -r shudl \
  -s name=data-engineers \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin

# Create analyst group
docker exec -it docker-keycloak /opt/keycloak/bin/kcadm.sh create groups \
  -r shudl \
  -s name=analysts \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin

# Create test user
docker exec -it docker-keycloak /opt/keycloak/bin/kcadm.sh create users \
  -r shudl \
  -s username=testuser \
  -s enabled=true \
  -s email=testuser@shugur.com \
  -s firstName=Test \
  -s lastName=User \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin

# Set user password
docker exec -it docker-keycloak /opt/keycloak/bin/kcadm.sh set-password \
  -r shudl \
  --username testuser \
  --new-password password123 \
  --temporary \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin
```

## Service Integration

### Grafana Integration

#### 1. Update Grafana Configuration

Create `/configs/monitoring/grafana/grafana.ini`:

```ini
[server]
protocol = http
http_port = 3000
domain = localhost
root_url = http://localhost:3000

[auth.generic_oauth]
enabled = true
name = Keycloak
allow_sign_up = true
client_id = grafana
client_secret = <GRAFANA_CLIENT_SECRET>
scopes = openid email profile
auth_url = http://localhost:8180/realms/shudl/protocol/openid-connect/auth
token_url = http://keycloak:8080/realms/shudl/protocol/openid-connect/token
api_url = http://keycloak:8080/realms/shudl/protocol/openid-connect/userinfo
role_attribute_path = contains(groups[*], 'admins') && 'Admin' || contains(groups[*], 'data-engineers') && 'Editor' || 'Viewer'
```

#### 2. Update docker-compose.yml

Add to Grafana service:

```yaml
volumes:
  - ../configs/monitoring/grafana/grafana.ini:/etc/grafana/grafana.ini:ro
```

#### 3. Restart Grafana

```bash
docker compose restart grafana
```

### Trino Integration

#### 1. Update Trino Configuration

Create `/configs/trino/config.properties` additions:

```properties
# OAuth2 Authentication
http-server.authentication.type=oauth2
http-server.authentication.oauth2.issuer=http://localhost:8180/realms/shudl
http-server.authentication.oauth2.client-id=trino
http-server.authentication.oauth2.client-secret=<TRINO_CLIENT_SECRET>
http-server.authentication.oauth2.scopes=openid,email,profile
```

#### 2. Restart Trino

```bash
docker compose restart trino
```

### MinIO Integration

#### 1. Configure MinIO Identity Provider

```bash
# Set OpenID configuration
docker exec docker-minio mc admin config set minio identity_openid \
  config_url="http://keycloak:8080/realms/shudl/.well-known/openid-configuration" \
  client_id="minio" \
  client_secret="<MINIO_CLIENT_SECRET>" \
  scopes="openid,profile,email" \
  redirect_uri="http://localhost:9001/oauth_callback"

# Restart MinIO
docker compose restart minio
```

#### 2. Create MinIO Policy

```bash
# Create admin policy for Keycloak admins group
docker exec docker-minio mc admin policy create minio keycloak-admins /tmp/admin-policy.json

# Attach policy to group
docker exec docker-minio mc admin policy attach minio keycloak-admins --group=admins
```

## Security Configuration

### Production Hardening

1. **Change Default Passwords**

   ```bash
   # Update admin password
   docker exec -it docker-keycloak /opt/keycloak/bin/kcadm.sh set-password \
     -r master \
     --username admin \
     --new-password <STRONG_PASSWORD>
   ```

2. **Enable HTTPS**

   - Generate SSL certificates
   - Update KC_HOSTNAME_STRICT_HTTPS=true
   - Configure reverse proxy (Nginx/Traefik)

3. **Configure Password Policies**

   - Go to Realm Settings → Security Defenses → Password Policy
   - Add: Minimum Length (12), Uppercase, Lowercase, Digits, Special Characters

4. **Enable MFA**

   - Go to Realm Settings → Authentication
   - Configure OTP policy
   - Enable for required flows

5. **Session Management**
   - Configure session timeouts
   - Enable remember me
   - Configure token lifespans

### Role-Based Access Control (RBAC)

#### Define Roles

```bash
# Create roles in Keycloak
for role in admin editor viewer; do
  docker exec -it docker-keycloak /opt/keycloak/bin/kcadm.sh create roles \
    -r shudl \
    -s name=$role \
    --server http://localhost:8080 \
    --realm master \
    --user admin \
    --password admin
done
```

#### Map Groups to Roles

```bash
# Assign admin role to admins group
docker exec -it docker-keycloak /opt/keycloak/bin/kcadm.sh add-roles \
  -r shudl \
  --gname admins \
  --rolename admin \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin
```

## Monitoring & Observability

### Keycloak Metrics

Keycloak exposes metrics at `/metrics`:

```bash
# Check metrics
curl http://localhost:8180/metrics

# Add to Prometheus scrape config
cat >> /configs/monitoring/prometheus/prometheus.yml <<EOF
  - job_name: 'keycloak'
    static_configs:
      - targets: ['keycloak:8080']
    metrics_path: '/metrics'
EOF
```

### Grafana Dashboard

Import Keycloak dashboard:

- Dashboard ID: 10441
- https://grafana.com/grafana/dashboards/10441

### Keycloak Logs

```bash
# View real-time logs
docker logs -f docker-keycloak

# Check for auth failures
docker logs docker-keycloak 2>&1 | grep -i "failed\|error"

# Export logs for analysis
docker logs docker-keycloak --since 1h > keycloak-logs.txt
```

## Troubleshooting

### Issue: Cannot Access Admin Console

```bash
# Check if Keycloak is running
docker ps --filter "name=keycloak"

# Check health
curl http://localhost:8180/health

# Restart if needed
docker compose restart keycloak
```

### Issue: Database Connection Failed

```bash
# Verify PostgreSQL is healthy
docker exec docker-postgresql psql -U nessie -l | grep keycloak

# Check connection from Keycloak
docker exec docker-keycloak ping -c 3 postgresql

# Verify credentials
docker exec docker-postgresql psql -U keycloak_user -d keycloak -c "SELECT 1;"
```

### Issue: OAuth2 Login Fails

1. **Check Redirect URIs**

   - Must match exactly (including trailing slash)
   - Update in Keycloak admin console

2. **Verify Client Secret**

   - Regenerate if needed
   - Update in service configuration

3. **Check Network Connectivity**
   ```bash
   # From Grafana to Keycloak
   docker exec docker-grafana curl -v http://keycloak:8080/health
   ```

### Issue: Token Expired

```bash
# Check token lifespan settings
# Realm Settings → Tokens → Access Token Lifespan

# Adjust if needed (default: 5 minutes)
```

## Best Practices

### 1. **Realm Separation**

- Use separate realms for dev/staging/prod
- Never share realms across environments

### 2. **Client Secrets Management**

- Rotate regularly (every 90 days)
- Store in secrets management system (Vault, AWS Secrets Manager)
- Never commit to version control

### 3. **User Management**

- Use groups for permission assignment
- Implement least privilege principle
- Regular user access reviews

### 4. **Audit Logging**

- Enable Keycloak event logging
- Monitor failed login attempts
- Track role/permission changes

### 5. **Backup & Disaster Recovery**

- Regular database backups
- Export realm configuration
- Document client secrets storage

## Future Enhancements

### Phase 3: Advanced SSO Features

1. **LDAP/Active Directory Integration**

   - Connect to corporate directory
   - Sync users and groups
   - Federated authentication

2. **Social Login**

   - GitHub, Google, Microsoft
   - Simplified user onboarding
   - External identity providers

3. **Service Account Management**

   - API authentication
   - Machine-to-machine communication
   - Automated workflows

4. **Advanced Authorization**
   - Fine-grained permissions
   - Attribute-based access control (ABAC)
   - Policy-based authorization

---

**Version**: 1.0.0  
**Last Updated**: November 26, 2025  
**Status**: ✅ **Production Ready**
