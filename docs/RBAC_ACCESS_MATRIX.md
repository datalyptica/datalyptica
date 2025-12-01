# Datalyptica Platform - RBAC & Access Control Framework

**Document Version:** 1.0.0  
**Date:** November 30, 2025  
**Classification:** Internal - Security Framework

---

## 1. Executive Summary

This document defines the Role-Based Access Control (RBAC) framework for the Datalyptica platform, implementing the principle of least privilege and defense-in-depth security model. The framework aligns with NIST Special Publication 800-53 (Security and Privacy Controls) and ISO/IEC 27001 (Information Security Management).

### Framework Principles

1. **Principle of Least Privilege**: Users receive minimum permissions necessary
2. **Separation of Duties**: Critical operations require multiple roles
3. **Defense in Depth**: Multiple security layers across the stack
4. **Audit Everything**: All access attempts logged
5. **Zero Trust**: Verify explicitly, assume breach

---

## 2. Role Taxonomy

### 2.1 Role Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                    PLATFORM ADMINISTRATOR                    │
│  - Full system access, user management, configuration       │
└──────────────────────┬───────────────────────────────────────┘
                       │
         ┌─────────────┼─────────────┬──────────────┐
         ▼             ▼             ▼              ▼
┌─────────────┐ ┌─────────────┐ ┌──────────┐ ┌──────────────┐
│   DevOps    │ │ Security    │ │  Data    │ │   Business   │
│  Engineer   │ │  Engineer   │ │ Engineer │ │    User      │
└─────────────┘ └─────────────┘ └──────────┘ └──────────────┘
       │               │             │              │
┌──────┴────────┐     │      ┌──────┴───────┐      │
│               │     │      │              │      │
▼               ▼     ▼      ▼              ▼      ▼
Developer   SRE/Ops  SOC   Data       Data      Analyst
                            Scientist  Analyst
```

### 2.2 Standard Roles

#### **R1: Platform Administrator**

- **Purpose:** Full platform management and emergency access
- **Count:** 2-3 people maximum
- **Access Level:** Unrestricted
- **Delegation:** Cannot delegate admin rights without approval

#### **R2: DevOps Engineer**

- **Purpose:** Deploy, configure, and maintain platform infrastructure
- **Count:** 5-10 people (scaling with platform size)
- **Access Level:** Infrastructure, deployments, monitoring
- **Delegation:** Can delegate to junior DevOps

#### **R3: Security Engineer**

- **Purpose:** Security monitoring, incident response, compliance
- **Count:** 2-5 people
- **Access Level:** Read-only on all systems, write on security tools
- **Delegation:** Cannot delegate

#### **R4: Data Engineer**

- **Purpose:** Build and maintain data pipelines, ETL jobs
- **Count:** 10-50 people (scaling with organization)
- **Access Level:** Data sources, pipelines, catalog, job management
- **Delegation:** Can delegate read-only access

#### **R5: Data Scientist**

- **Purpose:** Analyze data, build ML models, experimentation
- **Count:** 10-100 people (scaling with organization)
- **Access Level:** Read data, create temp tables, submit jobs
- **Delegation:** Cannot delegate

#### **R6: Data Analyst**

- **Purpose:** Business intelligence, reporting, ad-hoc queries
- **Count:** 50-500 people (scaling with organization)
- **Access Level:** Read-only on approved datasets
- **Delegation:** Cannot delegate

#### **R7: Business User**

- **Purpose:** Consume dashboards and reports
- **Count:** 100-10,000 people (scaling with organization)
- **Access Level:** Read-only dashboards and reports
- **Delegation:** Cannot delegate

#### **R8: External Auditor** (Optional)

- **Purpose:** Compliance audits, read-only everything
- **Count:** 1-5 people (temporary)
- **Access Level:** Read-only, time-limited
- **Delegation:** Cannot delegate

#### **R9: Service Account**

- **Purpose:** Automated systems, CI/CD, scheduled jobs
- **Count:** Unlimited (tracked)
- **Access Level:** Task-specific, scoped
- **Delegation:** N/A (machine identity)

---

## 3. Access Control Matrix

### 3.1 Component-Level Access

| Component           | Platform Admin | DevOps | Security | Data Engineer  |  Data Scientist  |   Data Analyst    |  Business User  |
| ------------------- | :------------: | :----: | :------: | :------------: | :--------------: | :---------------: | :-------------: |
| **Keycloak**        |       RW       |   R    |    R     |       -        |        -         |         -         |        -        |
| **PostgreSQL**      |       RW       |   RW   |    R     | RW (data only) |  R (data only)   | R (approved data) |        -        |
| **MinIO (S3)**      |       RW       |   RW   |    R     |       RW       | RW (own prefix)  |         R         |        -        |
| **Nessie Catalog**  |       RW       |   RW   |    R     |       RW       |  RW (branches)   |         R         |        -        |
| **Trino**           |       RW       |   RW   |    R     |       RW       | RW (own schemas) |         R         | R (via Grafana) |
| **Spark**           |       RW       |   RW   |    R     |       RW       |        RW        |         -         |        -        |
| **Flink**           |       RW       |   RW   |    R     |       RW       |        R         |         -         |        -        |
| **Kafka**           |       RW       |   RW   |    R     |       RW       |        R         |         -         |        -        |
| **Kafka Connect**   |       RW       |   RW   |    R     |       RW       |        -         |         -         |        -        |
| **Schema Registry** |       RW       |   RW   |    R     |       RW       |        R         |         -         |        -        |
| **ClickHouse**      |       RW       |   RW   |    R     |       RW       |        R         |         R         |        -        |
| **dbt**             |       RW       |   RW   |    R     |       RW       |        R         |         -         |        -        |
| **Prometheus**      |       RW       |   RW   |    R     |       R        |        R         |         R         |        R        |
| **Grafana**         |       RW       |   RW   |    R     |       RW       |        RW        |         R         |        R        |
| **Loki**            |       RW       |   RW   |    R     |       R        |        R         |         R         |        R        |
| **Alertmanager**    |       RW       |   RW   |    RW    |       R        |        -         |         -         |        -        |

**Legend:**

- **RW** = Read + Write + Execute
- **R** = Read-only
- **-** = No access

### 3.2 Data-Level Access

#### **Catalog Hierarchy**

```
iceberg                     # Catalog
├── production              # Namespace (PROD)
│   ├── sales              # Schema
│   │   ├── orders         # Table (PII, restricted)
│   │   └── products       # Table (public)
│   └── analytics          # Schema
│       ├── metrics        # Table (public)
│       └── user_behavior  # Table (anonymized)
├── staging                # Namespace (TEST)
└── development            # Namespace (DEV)
    └── experiments        # Schema (user-specific)
```

#### **Access Policies**

| Namespace            | Platform Admin | DevOps | Security |  Data Engineer   |  Data Scientist  | Data Analyst |  Business User  |
| -------------------- | :------------: | :----: | :------: | :--------------: | :--------------: | :----------: | :-------------: |
| **production.\***    |       RW       |   R    |    R     |        RW        |        R         | R (approved) | R (via reports) |
| **staging.\***       |       RW       |   RW   |    R     |        RW        |        RW        |      R       |        -        |
| **development.\***   |       RW       |   RW   |    R     | RW (own schemas) | RW (own schemas) |      -       |        -        |
| **sandbox.{user}\*** |       -        |   -    |    -     |     RW (own)     |     RW (own)     |      -       |        -        |

#### **Column-Level Security** (via Keycloak + Trino)

| Column Type          | Platform Admin | DevOps | Security |  Data Engineer   | Data Scientist | Data Analyst | Business User |
| -------------------- | :------------: | :----: | :------: | :--------------: | :------------: | :----------: | :-----------: |
| **Public**           |       ✅       |   ✅   |    ✅    |        ✅        |       ✅       |      ✅      |      ✅       |
| **Internal**         |       ✅       |   ✅   |    ✅    |        ✅        |       ✅       |      ✅      |      ❌       |
| **Confidential**     |       ✅       |   ❌   |    ✅    |        ✅        |   ⚠️ Masked    |      ❌      |      ❌       |
| **Restricted (PII)** |       ✅       |   ❌   |    ✅    | ⚠️ Approved only |       ❌       |      ❌      |      ❌       |
| **Secret**           |       ✅       |   ❌   |    ✅    |        ❌        |       ❌       |      ❌      |      ❌       |

**Masking Functions:**

- Email: `user@example.com` → `u***@e*****.com`
- Phone: `+1-555-1234` → `+1-***-***4`
- SSN: `123-45-6789` → `***-**-6789`
- Credit Card: `1234 5678 9012 3456` → `**** **** **** 3456`

### 3.3 Operation-Level Access

#### **Data Operations**

| Operation           | Platform Admin |     DevOps      | Security |  Data Engineer   |  Data Scientist  | Data Analyst  |  Business User   |
| ------------------- | :------------: | :-------------: | :------: | :--------------: | :--------------: | :-----------: | :--------------: |
| **CREATE DATABASE** |       ✅       |       ✅        |    ❌    |        ✅        |        ❌        |      ❌       |        ❌        |
| **DROP DATABASE**   |       ✅       | ⚠️ Staging only |    ❌    | ⚠️ Staging only  |        ❌        |      ❌       |        ❌        |
| **CREATE TABLE**    |       ✅       |       ✅        |    ❌    |        ✅        | ✅ (own schemas) |      ❌       |        ❌        |
| **DROP TABLE**      |       ✅       |   ⚠️ Non-prod   |    ❌    |   ⚠️ Non-prod    |  ⚠️ Own tables   |      ❌       |        ❌        |
| **ALTER TABLE**     |       ✅       |   ⚠️ Non-prod   |    ❌    |        ✅        |  ⚠️ Own tables   |      ❌       |        ❌        |
| **INSERT**          |       ✅       |   ⚠️ ETL only   |    ❌    |        ✅        | ✅ (own tables)  |      ❌       |        ❌        |
| **UPDATE**          |       ✅       |   ⚠️ ETL only   |    ❌    |        ✅        |  ⚠️ Own tables   |      ❌       |        ❌        |
| **DELETE**          |       ✅       |       ❌        |    ❌    | ⚠️ With approval |        ❌        |      ❌       |        ❌        |
| **SELECT**          |       ✅       |       ✅        |    ✅    |        ✅        |        ✅        | ✅ (approved) | ✅ (via reports) |
| **MERGE**           |       ✅       |   ⚠️ ETL only   |    ❌    |        ✅        |  ⚠️ Own tables   |      ❌       |        ❌        |

#### **Administrative Operations**

| Operation          | Platform Admin |   DevOps   | Security | Data Engineer  | Data Scientist | Data Analyst | Business User |
| ------------------ | :------------: | :--------: | :------: | :------------: | :------------: | :----------: | :-----------: |
| **CREATE USER**    |       ✅       |     ✅     |    ❌    |       ❌       |       ❌       |      ❌      |      ❌       |
| **DROP USER**      |       ✅       |     ❌     |    ❌    |       ❌       |       ❌       |      ❌      |      ❌       |
| **GRANT ROLE**     |       ✅       | ⚠️ Limited |    ❌    |       ❌       |       ❌       |      ❌      |      ❌       |
| **REVOKE ROLE**    |       ✅       |     ❌     |    ❌    |       ❌       |       ❌       |      ❌      |      ❌       |
| **VIEW LOGS**      |       ✅       |     ✅     |    ✅    |  ⚠️ Own jobs   |  ⚠️ Own jobs   |      ❌      |      ❌       |
| **KILL QUERY**     |       ✅       |     ✅     |    ❌    | ⚠️ Own queries | ⚠️ Own queries |      ❌      |      ❌       |
| **SYSTEM CONFIG**  |       ✅       |     ✅     |    ❌    |       ❌       |       ❌       |      ❌      |      ❌       |
| **BACKUP/RESTORE** |       ✅       |     ✅     |    ❌    |       ❌       |       ❌       |      ❌      |      ❌       |

#### **Streaming Operations**

| Operation                 | Platform Admin |   DevOps    | Security | Data Engineer | Data Scientist | Data Analyst | Business User |
| ------------------------- | :------------: | :---------: | :------: | :-----------: | :------------: | :----------: | :-----------: |
| **CREATE TOPIC**          |       ✅       |     ✅      |    ❌    |      ✅       |       ❌       |      ❌      |      ❌       |
| **DELETE TOPIC**          |       ✅       | ⚠️ Non-prod |    ❌    |  ⚠️ Non-prod  |       ❌       |      ❌      |      ❌       |
| **PRODUCE**               |       ✅       |     ✅      |    ❌    |      ✅       |   ⚠️ Limited   |      ❌      |      ❌       |
| **CONSUME**               |       ✅       |     ✅      |    ✅    |      ✅       |       ✅       | ⚠️ Approved  |      ❌       |
| **MANAGE CONSUMER GROUP** |       ✅       |     ✅      |    ❌    |      ✅       | ⚠️ Own groups  |      ❌      |      ❌       |
| **ALTER CONFIGS**         |       ✅       |     ✅      |    ❌    |      ❌       |       ❌       |      ❌      |      ❌       |

---

## 4. Authentication & Authorization

### 4.1 Authentication Methods

#### **Primary: Keycloak SSO (OpenID Connect)**

- **Users:** All human users
- **Protocol:** OAuth 2.0 / OIDC
- **MFA:** Required for Platform Admin, DevOps, Security
- **MFA:** Optional but recommended for Data Engineers
- **Session Timeout:** 8 hours (re-auth required)
- **Password Policy:**
  - Minimum 12 characters
  - Must include uppercase, lowercase, number, special char
  - Cannot reuse last 5 passwords
  - Expires every 90 days

#### **Secondary: Service Accounts (Client Credentials)**

- **Users:** CI/CD, automated jobs, service-to-service
- **Protocol:** OAuth 2.0 Client Credentials
- **Rotation:** Every 90 days (automated)
- **Scoping:** Minimal permissions per service

#### **Emergency: Break-Glass Account**

- **Users:** Break-glass emergency access
- **Count:** 1-2 accounts
- **Storage:** Sealed envelope in secure location
- **Usage:** Logged and reviewed (root cause analysis required)
- **Rotation:** Every 180 days

### 4.2 Authorization Flow

```
┌──────────────┐
│  User Login  │
└──────┬───────┘
       │
       ▼
┌──────────────────┐      ┌─────────────────┐
│  Keycloak IdP    │◀────▶│  LDAP/AD (Opt)  │
│  (Authentication)│      │  (Federation)    │
└──────┬───────────┘      └─────────────────┘
       │
       │ JWT Token with Claims
       ▼
┌──────────────────────────────────────────────┐
│         Service Authorization                │
├──────────────────────────────────────────────┤
│  Trino:      Validates JWT, checks ACLs      │
│  Nessie:     Validates JWT, checks branches  │
│  Kafka:      Validates JWT, checks topics    │
│  MinIO:      Validates JWT, checks buckets   │
│  Grafana:    Validates JWT, checks folders   │
└──────────────────────────────────────────────┘
       │
       ▼
┌──────────────────┐
│  Audit Log       │
│  (All Access)    │
└──────────────────┘
```

### 4.3 JWT Token Claims

```json
{
  "sub": "user@company.com",
  "preferred_username": "jdoe",
  "email": "jdoe@company.com",
  "email_verified": true,
  "name": "John Doe",
  "given_name": "John",
  "family_name": "Doe",
  "groups": ["/datalyptica/data-engineers", "/datalyptica/production-access"],
  "roles": ["data-engineer", "trino-user"],
  "realm_access": {
    "roles": ["user"]
  },
  "resource_access": {
    "trino": {
      "roles": ["query-user", "schema-creator"]
    },
    "nessie": {
      "roles": ["branch-creator", "committer"]
    }
  },
  "iat": 1701360000,
  "exp": 1701388800,
  "iss": "https://keycloak.company.com/realms/datalyptica",
  "aud": ["trino", "nessie", "grafana"]
}
```

---

## 5. Environment Segregation

### 5.1 Environment Tiers

| Environment                | Purpose                              | Access Control                  | Data                         | Uptime SLA |
| -------------------------- | ------------------------------------ | ------------------------------- | ---------------------------- | ---------- |
| **Development**            | Feature development, experimentation | Open (authenticated)            | Synthetic, anonymized        | None       |
| **Testing**                | Integration testing, QA              | Restricted (testers, engineers) | Synthetic, test fixtures     | None       |
| **Staging**                | Pre-production validation            | Restricted (limited approval)   | Production-like (anonymized) | 95%        |
| **Production**             | Live business operations             | Highly restricted (RBAC)        | Real production data         | 99.9%      |
| **DR (Disaster Recovery)** | Failover site                        | Same as production              | Production replica           | 99.5%      |
| **Sandbox**                | User experimentation                 | User-specific isolation         | User-generated only          | None       |

### 5.2 Cross-Environment Access

#### **Promotion Path**

```
Development → Testing → Staging → Production
                                      ↓
                                  DR Site
```

**Rules:**

1. ❌ No direct promotion Dev → Prod (must go through Staging)
2. ✅ Code promotion via CI/CD (automated tests required)
3. ✅ Data never flows backward (Prod → Staging allowed for testing)
4. ✅ Configuration as code (GitOps)
5. ✅ All promotions logged and audited

#### **Data Copying Rules**

| From → To          | Allowed | Condition           | Approval        |
| ------------------ | ------- | ------------------- | --------------- |
| **Prod → Staging** | ✅      | Anonymized/masked   | Automatic       |
| **Prod → Dev**     | ⚠️      | Anonymized, limited | Security review |
| **Prod → Sandbox** | ❌      | Never               | N/A             |
| **Staging → Prod** | ❌      | Never               | N/A             |
| **Dev → Staging**  | ✅      | Test data           | Automatic       |
| **Dev → Prod**     | ❌      | Never               | N/A             |

### 5.3 Network Isolation

#### **Development Environment**

- **Network:** 172.30.0.0/16
- **Internet:** Egress allowed (for package downloads)
- **Production:** No connectivity

#### **Staging Environment**

- **Network:** 172.31.0.0/16
- **Internet:** Egress allowed (limited)
- **Production:** Read-only data sync

#### **Production Environment**

- **Network:** 10.0.0.0/16
- **Internet:** Egress restricted (whitelist)
- **Internal:** Firewalled from dev/staging

---

## 6. Audit & Compliance

### 6.1 Audit Logging

#### **What to Log**

| Event Type                                   | Log Level | Retention | Storage             |
| -------------------------------------------- | --------- | --------- | ------------------- |
| **Authentication**                           | INFO      | 2 years   | Loki + SIEM         |
| **Authorization failure**                    | WARN      | 2 years   | Loki + SIEM         |
| **Data access (SELECT)**                     | INFO      | 1 year    | Loki                |
| **Data modification (INSERT/UPDATE/DELETE)** | WARN      | 7 years   | Loki + Archive      |
| **Admin operations**                         | WARN      | 7 years   | Loki + Archive      |
| **Schema changes**                           | WARN      | 7 years   | Loki + Archive      |
| **User management**                          | WARN      | 7 years   | Loki + Archive      |
| **Failed logins**                            | WARN      | 2 years   | Loki + SIEM         |
| **Privilege escalation**                     | CRITICAL  | 7 years   | Loki + SIEM + Alert |
| **Anomalous behavior**                       | CRITICAL  | 7 years   | SIEM + Alert        |

#### **Log Format (JSON)**

```json
{
  "timestamp": "2025-11-30T15:30:45.123Z",
  "event_type": "data_access",
  "user": "jdoe@company.com",
  "user_id": "uuid-1234",
  "role": "data-engineer",
  "client_ip": "10.1.2.3",
  "service": "trino",
  "resource": "iceberg.production.sales.orders",
  "operation": "SELECT",
  "result": "success",
  "rows_returned": 1000,
  "query_id": "20251130_153045_00123_abcde",
  "duration_ms": 1234,
  "session_id": "session-uuid-5678"
}
```

### 6.2 Compliance Requirements

#### **GDPR (General Data Protection Regulation)**

- ✅ Right to access: Query audit logs for user data
- ✅ Right to erasure: Hard delete via Iceberg row-level operations
- ✅ Data portability: Export via Trino/Spark
- ✅ Breach notification: Alertmanager + on-call
- ✅ Data minimization: Column-level access control
- ✅ Encryption: TLS in transit, at-rest via MinIO KMS

#### **HIPAA (Health Insurance Portability and Accountability Act)**

- ✅ Access controls: Keycloak RBAC
- ✅ Audit trails: 6-year retention
- ✅ Encryption: FIPS 140-2 compatible (with proper configuration)
- ✅ Unique user identification: Keycloak user IDs
- ✅ Emergency access: Break-glass accounts
- ⚠️ Automatic log-off: Configure session timeout (8 hours default)

#### **SOX (Sarbanes-Oxley Act)**

- ✅ Data integrity: ACID transactions (Iceberg)
- ✅ Audit trails: 7-year retention
- ✅ Access controls: Separation of duties
- ✅ Change management: GitOps + approval workflows

#### **PCI DSS (Payment Card Industry Data Security Standard)**

- ⚠️ Not currently certified (recommend separate environment if needed)
- ✅ Access control: RBAC implemented
- ✅ Encryption: Available (TLS + at-rest)
- ⚠️ Vulnerability scanning: Recommend Trivy for container scanning
- ⚠️ Penetration testing: Required before certification

### 6.3 Access Review Process

#### **Periodic Access Reviews**

| Review Type              | Frequency | Reviewers          | Action         |
| ------------------------ | --------- | ------------------ | -------------- |
| **User access rights**   | Quarterly | Manager + Security | Revoke unused  |
| **Role assignments**     | Annually  | CISO + Data Owner  | Revalidate     |
| **Service accounts**     | Quarterly | DevOps + Security  | Rotate/revoke  |
| **Admin accounts**       | Monthly   | CISO               | Audit activity |
| **Break-glass accounts** | Quarterly | Security           | Verify sealed  |

#### **Automated Reviews**

- **Unused accounts**: Auto-disabled after 90 days inactivity
- **Stale credentials**: Auto-expire after 90 days
- **Over-privileged users**: Alert if admin hasn't logged in 30 days
- **Anomaly detection**: ML-based behavioral analysis (via SIEM)

---

## 7. Implementation Guide

### 7.1 Keycloak Configuration

#### **Realm Setup**

```bash
# Create realm
kcadm.sh create realms -s realm=datalyptica -s enabled=true

# Create roles
kcadm.sh create roles -r datalyptica -s name=platform-admin
kcadm.sh create roles -r datalyptica -s name=devops-engineer
kcadm.sh create roles -r datalyptica -s name=data-engineer
kcadm.sh create roles -r datalyptica -s name=data-scientist
kcadm.sh create roles -r datalyptica -s name=data-analyst

# Create groups (for LDAP mapping)
kcadm.sh create groups -r datalyptica -s name=datalyptica-admins
kcadm.sh create groups -r datalyptica -s name=datalyptica-devops
kcadm.sh create groups -r datalyptica -s name=datalyptica-data-engineers
```

#### **Client Configuration (Trino Example)**

```json
{
  "clientId": "trino",
  "name": "Trino Query Engine",
  "protocol": "openid-connect",
  "enabled": true,
  "publicClient": false,
  "clientAuthenticatorType": "client-secret",
  "standardFlowEnabled": true,
  "implicitFlowEnabled": false,
  "directAccessGrantsEnabled": true,
  "serviceAccountsEnabled": true,
  "authorizationServicesEnabled": true,
  "redirectUris": ["https://trino.company.com/oauth2/callback"],
  "webOrigins": ["https://trino.company.com"],
  "defaultClientScopes": ["email", "profile", "roles"],
  "optionalClientScopes": ["groups"]
}
```

### 7.2 Trino Access Control

#### **File: `etc/access-control/rules.json`**

```json
{
  "catalogs": [
    {
      "catalog": "iceberg",
      "allow": ["data-engineer", "data-scientist", "data-analyst"]
    }
  ],
  "schemas": [
    {
      "catalog": "iceberg",
      "schema": "production.*",
      "owner": true,
      "allow": ["data-engineer"]
    },
    {
      "catalog": "iceberg",
      "schema": "production.*",
      "owner": false,
      "allow": ["data-scientist", "data-analyst"]
    }
  ],
  "tables": [
    {
      "catalog": "iceberg",
      "schema": "production.sales",
      "table": "orders",
      "privileges": ["SELECT", "INSERT"],
      "allow": ["data-engineer"]
    },
    {
      "catalog": "iceberg",
      "schema": "production.sales",
      "table": "orders",
      "privileges": ["SELECT"],
      "columns": ["order_id", "total", "date"],
      "allow": ["data-analyst"]
    }
  ],
  "sessionProperties": [
    {
      "property": "query_max_execution_time",
      "allow": ["platform-admin", "devops-engineer"]
    }
  ]
}
```

### 7.3 MinIO Policy Example

#### **Data Engineer Policy**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": ["arn:aws:s3:::lakehouse/*"]
    }
  ]
}
```

#### **Data Analyst Policy (Read-Only)**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": ["arn:aws:s3:::lakehouse/production/*"]
    }
  ]
}
```

### 7.4 Nessie Authorization

#### **Branch Protection Rules**

```yaml
# Protected branches (require approval)
protected:
  - main
  - production
  - release/*

# Auto-merge rules
auto_merge:
  - pattern: "dev/*"
    approvers: 1
  - pattern: "feature/*"
    approvers: 2

# Role permissions
roles:
  data-engineer:
    branches:
      create: ["dev/*", "feature/*", "staging/*"]
      delete: ["dev/*", "feature/*"]
      merge: ["dev/*", "feature/*", "staging/*"]
    tags:
      create: true

  data-scientist:
    branches:
      create: ["experiments/*"]
      delete: ["experiments/*"]
      merge: ["experiments/*"]
    tags:
      create: false
```

---

## 8. Incident Response

### 8.1 Security Incidents

#### **Severity Levels**

| Severity          | Description                                   | Response Time | Escalation              |
| ----------------- | --------------------------------------------- | ------------- | ----------------------- |
| **P0 - Critical** | Data breach, unauthorized admin access        | Immediate     | CISO, CTO               |
| **P1 - High**     | Privilege escalation, mass data exfiltration  | <15 min       | Security team, manager  |
| **P2 - Medium**   | Unauthorized access attempt, policy violation | <2 hours      | Security team           |
| **P3 - Low**      | Failed login attempts, anomaly                | <24 hours     | Review in daily standup |

#### **Incident Response Playbook**

**P0 - Data Breach:**

1. **Detect**: Alert triggered (SIEM, Alertmanager)
2. **Contain**:
   - Revoke compromised credentials (Keycloak)
   - Block source IP (firewall)
   - Isolate affected services
3. **Investigate**:
   - Review audit logs (Loki)
   - Identify scope (affected users, data)
   - Determine root cause
4. **Remediate**:
   - Patch vulnerabilities
   - Rotate all secrets
   - Reset affected user passwords
5. **Recover**:
   - Restore from clean backup if needed
   - Verify data integrity
6. **Post-Incident**:
   - Root cause analysis (RCA)
   - Update playbook
   - Compliance notification (if required)

### 8.2 Access Violation Procedures

#### **Detected Violations**

```bash
# Automatic response (via Alertmanager webhook)
# When: User attempts to access restricted data

1. Log event (HIGH severity)
2. Send alert to Security team
3. Block user session (optional, configurable)
4. Require re-authentication with MFA
5. Manager notification
6. Incident ticket created (Jira/ServiceNow)
```

#### **Investigation Workflow**

1. **Is it a false positive?**

   - Yes → Update detection rules
   - No → Proceed to step 2

2. **Was it intentional?**

   - No (user error) → Training + warning
   - Yes → Proceed to step 3

3. **Was it malicious?**
   - No (policy misunderstanding) → Policy review + training
   - Yes → Escalate to legal/HR, revoke access

---

## 9. Onboarding & Offboarding

### 9.1 User Onboarding Checklist

#### **New Employee**

**Day 1:**

- [ ] HR notification received
- [ ] Keycloak account created (email = username)
- [ ] Temporary password generated (must change on first login)
- [ ] Added to appropriate groups (via LDAP/AD sync)
- [ ] Welcome email sent (with links to documentation)

**Week 1:**

- [ ] Manager approves role assignment
- [ ] Security training completed
- [ ] Data privacy training completed
- [ ] Acceptable use policy signed
- [ ] Access granted (based on role)
- [ ] Onboarding checklist review meeting

#### **Role Change**

**Before change:**

- [ ] Manager approval for new role
- [ ] Security review (if increasing privileges)
- [ ] Training for new responsibilities

**During change:**

- [ ] Old roles revoked
- [ ] New roles assigned
- [ ] Access review conducted
- [ ] Documentation updated

**After change:**

- [ ] User verification (can access new resources)
- [ ] Audit log review (no unauthorized access)

### 9.2 User Offboarding Checklist

#### **Employee Departure**

**Day of notification:**

- [ ] HR notification received
- [ ] Disable Keycloak account (do not delete)
- [ ] Revoke all API keys/service accounts
- [ ] Transfer ownership of resources (tables, dashboards)
- [ ] Export user activity logs (for audit)

**Within 30 days:**

- [ ] Review all access logs
- [ ] Archive user data (if required)
- [ ] Delete sandboxes (after backup)
- [ ] Final compliance check

**After 90 days:**

- [ ] Delete Keycloak account (if no audit holds)
- [ ] Purge temporary data

#### **Contractor End of Engagement**

- [ ] Same as employee, but immediate (day of end date)
- [ ] No 30-day grace period
- [ ] Audit review required before next engagement

---

## 10. Monitoring & Alerting

### 10.1 Security Metrics

| Metric                            | Target | Alert Threshold | Action                    |
| --------------------------------- | ------ | --------------- | ------------------------- |
| **Failed logins (per user)**      | <5/day | >10/hour        | Lock account, investigate |
| **Privilege escalation attempts** | 0      | >1              | Immediate investigation   |
| **Unauthorized data access**      | 0      | >1              | Alert security team       |
| **Stale accounts (inactive)**     | <5%    | >10%            | Review and disable        |
| **Accounts without MFA**          | 0%     | >5%             | Enforce MFA               |
| **Secrets age (days)**            | <90    | >120            | Force rotation            |
| **Compliance violations**         | 0      | >1              | Incident response         |

### 10.2 Audit Reports

#### **Daily Reports**

- Failed authentication attempts
- Privilege changes
- High-value data access (PII, financial)

#### **Weekly Reports**

- User activity summary
- Anomaly detection results
- Policy violations

#### **Monthly Reports**

- Access review summary
- Compliance metrics
- Security incidents
- Training completion rates

#### **Quarterly Reports (for leadership)**

- Risk assessment
- Audit findings
- Compliance status
- Security roadmap updates

---

## 11. Training & Awareness

### 11.1 Required Training

| Role                | Training             | Frequency   | Duration |
| ------------------- | -------------------- | ----------- | -------- |
| **All Users**       | Security Awareness   | Annual      | 1 hour   |
| **All Users**       | Data Privacy (GDPR)  | Annual      | 30 min   |
| **Platform Admin**  | Incident Response    | Annual      | 4 hours  |
| **DevOps**          | Secure Configuration | Annual      | 2 hours  |
| **Data Engineers**  | Data Classification  | Semi-annual | 1 hour   |
| **Data Scientists** | Ethical AI/ML        | Annual      | 2 hours  |

### 11.2 Documentation

**Required Reading:**

- [ ] Acceptable Use Policy
- [ ] Data Classification Guide
- [ ] Incident Reporting Procedures
- [ ] Role-Specific Access Guide
- [ ] Emergency Contact List

**Recommended Reading:**

- [ ] OWASP Top 10
- [ ] CIS Benchmarks
- [ ] NIST Cybersecurity Framework
- [ ] Company Security Blog

---

## 12. Maintenance & Updates

### 12.1 Quarterly Reviews

**Access Control Matrix:**

- Review and update permissions
- Add new roles if needed
- Remove obsolete roles
- Validate with stakeholders

**Policy Documents:**

- Review for compliance changes
- Update based on incidents
- Incorporate lessons learned

### 12.2 Annual Reviews

**Complete RBAC Framework:**

- Comprehensive audit
- Penetration testing
- Compliance assessment
- Third-party security review

---

## Appendices

### A. Quick Reference Card

**Emergency Contacts:**

- Security Team: security@company.com
- CISO: ciso@company.com
- On-Call: +1-555-SEC-URITY

**Break-Glass Procedure:**

1. Open sealed envelope (witnessed)
2. Use credentials (logged automatically)
3. Complete incident form (within 24 hours)
4. Return envelope to security (re-seal)

**Common Tasks:**

- Request access: Submit Jira ticket to IT
- Report security issue: Email security@company.com
- Lost credentials: Self-service reset (or contact helpdesk)
- MFA issues: Contact helpdesk

### B. Glossary

- **RBAC**: Role-Based Access Control
- **SSO**: Single Sign-On
- **OIDC**: OpenID Connect
- **JWT**: JSON Web Token
- **MFA**: Multi-Factor Authentication
- **PII**: Personally Identifiable Information
- **SIEM**: Security Information and Event Management
- **RCA**: Root Cause Analysis

---

**Document Control:**

- **Version:** 1.0.0
- **Last Updated:** November 30, 2025
- **Next Review:** February 28, 2026
- **Owner:** Security & Compliance Team
- **Approvals:** CISO, DPO, Legal
