# Datalyptica Branding Standards

## Overview

This document defines the official branding standards for the **Datalyptica Data Platform**.

## Brand Identity

### Platform Name

- **Official Name:** Datalyptica Data Platform
- **Short Name:** Datalyptica
- **Tagline:** Enterprise-Grade Unified Data Architecture

### Domain & Contact Information

- **Primary Domain:** datalyptica.com
- **Technical Support:** support@datalyptica.com
- **DevOps Team:** devops@datalyptica.com
- **Operations Team:** ops@datalyptica.com

### Team Email Addresses

- **Database Team:** db-team@datalyptica.com
- **Storage Team:** storage-team@datalyptica.com
- **Query Team:** query-team@datalyptica.com
- **Alertmanager:** alertmanager@datalyptica.com

## Technical Standards

### GitHub Organization

- **Organization:** datalyptica
- **Repository:** datalyptica
- **Full URL:** https://github.com/datalyptica/datalyptica

### Docker Registry

- **Registry:** GitHub Container Registry (ghcr.io)
- **Base Path:** ghcr.io/datalyptica/datalyptica
- **Image Format:** ghcr.io/datalyptica/datalyptica/\<service\>:\<version\>

**Examples:**

```
ghcr.io/datalyptica/datalyptica/minio:v1.0.0
ghcr.io/datalyptica/datalyptica/postgresql:v1.0.0
ghcr.io/datalyptica/datalyptica/trino:v1.0.0
ghcr.io/datalyptica/datalyptica/spark:v1.0.0
```

### Environment Variables

- **Prefix:** DATALYPTICA\_\*
- **Version:** DATALYPTICA_VERSION
- **Database:** DATALYPTICA_DB
- **User:** DATALYPTICA_USER
- **Password File:** DATALYPTICA_PASSWORD_FILE

### Container Naming

- **Prefix:** datalyptica-\*
- **Format:** datalyptica-\<service\>

**Examples:**

```
datalyptica-minio
datalyptica-postgresql
datalyptica-trino-coordinator
datalyptica-spark-master
datalyptica-kafka-broker-1
```

### Database & Users

- **Database Name:** datalyptica
- **Application User:** datalyptica
- **Password Secret:** datalyptica_password

### Keycloak Configuration

- **Realm:** datalyptica
- **Client IDs:** datalyptica-api, datalyptica-ui
- **User Domain:** @datalyptica.local (for development)

### Compose Project

- **Project Name:** datalyptica
- **Environment Variable:** COMPOSE_PROJECT_NAME=datalyptica

## Docker Image Labels

All Dockerfiles MUST include these standardized labels:

```dockerfile
LABEL maintainer="devops@datalyptica.com"
LABEL org.opencontainers.image.source="https://github.com/datalyptica/datalyptica"
LABEL org.opencontainers.image.vendor="Datalyptica"
LABEL org.opencontainers.image.title="<Service Name>"
LABEL org.opencontainers.image.description="<Service description for Datalyptica data platform>"
```

## File Naming Conventions

### Secret Files

- Located in: `secrets/passwords/`
- Format: `<service>_password`
- Example: `datalyptica_password`, `postgres_password`

### Configuration Files

- Located in: `configs/<service>/`
- Use lowercase service names
- Example: `configs/spark/spark-defaults.conf`

### Script Files

- Located in: `scripts/`
- Use kebab-case: `init-dev-environment.sh`
- Atomic scripts: One responsibility per script

## Logging & Monitoring

### Loki Configuration

- **Job Name:** datalyptica
- **Log Paths:** /var/log/datalyptica/\*.log
- **Label:** {project="datalyptica"}

### Grafana Queries

- **Project Filter:** {project="datalyptica"}
- **Container Filter:** {container_name=~"datalyptica-.\*"}

### Prometheus Alerts

- **Runbook Base URL:** https://github.com/datalyptica/datalyptica/docs/operations/

## Documentation Standards

### Copyright Notice

```
Copyright © 2025 Datalyptica
```

### Footer

```
Made with ❤️ by the Datalyptica Team
```

### Support Links

- **Technical Support:** support@datalyptica.com
- **GitHub Issues:** https://github.com/datalyptica/datalyptica/issues

## Migration Notes

### Previous Names (Historical Reference Only)

The platform was previously known as:

1. **shudl** (original name)
2. **Aether** (first rename)
3. **Nexus** (second rename)
4. **Datalyptica** (current and final)

All references to previous names have been removed from the codebase as of the final branding update.

### Renaming History

- **Phase 1:** shudl → aether (November 2025)
- **Phase 2:** aether → nexus (November 2025)
- **Phase 3:** nexus → datalyptica (December 2025)

## Compliance Checklist

When adding new components or services, ensure:

- [ ] Docker image uses ghcr.io/datalyptica/datalyptica prefix
- [ ] All labels include maintainer="devops@datalyptica.com"
- [ ] GitHub source URL points to datalyptica organization
- [ ] Vendor label is "Datalyptica"
- [ ] Environment variables use DATALYPTICA\_\* prefix
- [ ] Container names use datalyptica-\* prefix
- [ ] Email addresses use @datalyptica.com domain
- [ ] Documentation references "Datalyptica Data Lakehouse"
- [ ] Copyright notice includes "Datalyptica"

## Version Information

- **Document Version:** 1.0.0
- **Last Updated:** December 1, 2025
- **Platform Version:** v1.0.0
- **Status:** Official Branding Standards

---

**© 2025 Datalyptica. All rights reserved.**
