# ShuDL Image Strategy

## Decision: Use Custom Images

**Date**: November 26, 2025  
**Decision**: Continue using custom `ghcr.io/shugur-network/shudl/*` images instead of official upstream images.

## Background

An attempt was made to migrate from custom Docker images to official upstream images (e.g., `apache/spark`, `trinodb/trino`, `confluentinc/cp-kafka`, etc.) to leverage:

- No building required
- Regular security updates from upstream
- Better community support
- Proven stability

## Issues Encountered

### 1. **Platform Architecture Mismatch**

- Running on ARM64 (Apple Silicon)
- Several official images (Apache Flink, Apache Spark) are AMD64-only
- Results in platform warnings and potential performance issues with emulation

### 2. **Configuration Incompatibility**

- Official Apache Spark image expects different configuration format
- Custom environment variables (SPARK_MODE, etc.) not supported
- Would require significant docker-compose.yml restructuring

### 3. **Startup Command Differences**

- Official images use different entrypoints and startup commands
- Custom images have tailored initialization scripts
- Services failed to start with default official image commands

### 4. **Service Health Issues**

- Multiple services stuck in "Created" or "Restarting" states
- Schema Registry showed warnings (though functional)
- Spark Master continuously restarting
- 10/15 services not starting properly

## Services Tested with Official Images

| Service         | Official Image                              | Status      | Issue                  |
| --------------- | ------------------------------------------- | ----------- | ---------------------- |
| MinIO           | `minio/minio:RELEASE.2024-11-07T00-52-20Z`  | ✅ Working  | None                   |
| PostgreSQL      | `postgres:17-alpine`                        | ✅ Working  | None                   |
| Zookeeper       | `confluentinc/cp-zookeeper:7.5.0`           | ✅ Working  | None                   |
| Kafka           | `confluentinc/cp-kafka:7.5.0`               | ✅ Working  | None                   |
| Nessie          | `ghcr.io/projectnessie/nessie:0.104.3`      | ✅ Working  | None                   |
| Trino           | `trinodb/trino:476`                         | ✅ Working  | None                   |
| Schema Registry | `confluentinc/cp-schema-registry:7.5.0`     | ⚠️ Warnings | Non-critical warnings  |
| Spark           | `apache/spark:3.5.3`                        | ❌ Failed   | Config incompatibility |
| Flink           | `apache/flink:1.18`                         | ⚠️ Platform | ARM64/AMD64 mismatch   |
| ClickHouse      | `clickhouse/clickhouse-server:24.11-alpine` | ✅ Working  | None                   |
| DBT             | `python:3.11-alpine`                        | 🔄 Created  | Not started            |
| Kafka Connect   | `confluentinc/cp-kafka-connect:7.5.0`       | 🔄 Created  | Dependency issue       |
| Kafka UI        | `provectuslabs/kafka-ui:v0.7.2`             | 🔄 Created  | Dependency issue       |

## Rollback Performed

### Actions Taken:

1. ✅ Stopped all running containers
2. ✅ Restored docker-compose.yml to use custom images
3. ✅ Reverted VERSION file to SHUDL_VERSION=v1.0.0
4. ✅ Reverted .env.example to use SHUDL_VERSION
5. ✅ Cleaned up backup files
6. ✅ Validated docker-compose.yml syntax

### Final Configuration:

```yaml
# All services now use:
image: ghcr.io/shugur-network/shudl/<service>:${SHUDL_VERSION:-v1.0.0}

# Except:
image: provectuslabs/kafka-ui:${KAFKA_UI_VERSION:-v0.7.2}
```

## Custom Images Strategy

### Advantages:

1. **Platform Compatibility**: Built for both ARM64 and AMD64
2. **Tailored Configuration**: Custom environment variables and initialization
3. **Proven Stability**: Known working configuration
4. **Integrated Setup**: All services configured to work together
5. **Specialized Scripts**: Custom entrypoints for ShuDL-specific needs

### Requirements:

1. **Build Process**: Images must be built locally or in CI/CD
2. **Registry Access**: Requires authentication to ghcr.io/shugur-network
3. **Maintenance**: Security updates require rebuilding images
4. **Documentation**: Custom image behavior must be documented

## Building Custom Images

To build all custom images locally:

```bash
cd /Users/karimhassan/development/projects/shudl
./scripts/build/build-all-images.sh
```

Individual service builds:

```bash
cd docker/services/<service>
docker build -t ghcr.io/shugur-network/shudl/<service>:v1.0.0 .
```

## Future Considerations

### When to Reconsider Official Images:

1. Running on AMD64 infrastructure
2. Willing to refactor docker-compose.yml for official image conventions
3. Official images add native ARM64 support
4. Simplified deployment becomes higher priority than customization

### Hybrid Approach:

Consider using official images for services that work well:

- ✅ MinIO (working)
- ✅ PostgreSQL (working)
- ✅ Confluent Platform (Kafka, Zookeeper, Schema Registry - mostly working)
- ✅ Nessie (working)
- ❌ Spark (needs custom config)
- ❌ Flink (platform issues)

## Conclusion

**Custom images remain the recommended approach** for ShuDL due to:

- Platform architecture requirements (ARM64 support)
- Proven stability and integration
- Specialized configuration needs
- Lower effort to maintain current setup vs. migrating to official images

The attempt to use official images provided valuable insights but revealed that the complexity and compatibility issues outweigh the benefits for this particular deployment scenario.

---

**Maintainer Notes**:

- Keep this document updated if image strategy changes
- Document any new custom image requirements
- Track official image improvements for future reconsideration
