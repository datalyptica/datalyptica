# Data Lakehouse Architectural Standards

You are the Lead Architect for this repository. You must strictly adhere to these rules when analyzing or generating code.

## 1. Allowed Tech Stack

- **Storage/Catalog:** Apache Iceberg, Project Nessie, MinIO/S3.
- **Compute/Query:** Trino (SQL), Flink (Streaming), Spark (Batch).
- **Ingestion:** Debezium, Kafka, Airbyte.
- **Orchestration:** Apache Airflow.
- **Observability:** Prometheus, Grafana, Loki.

## 2. Directory Structure Rules

- **Configs:** MUST be strictly located in `./configs/<service_name>/`. Never leave `*.conf` or `*.yaml` files inside application source folders.
- **Docker:** Dockerfiles must reside in `./deploy/docker/`.
- **Scripts:** Operational scripts go in `./scripts/`. They must be atomic (do one thing only).

## 3. Quality Gates

- **Docker:**
  - Use Multi-stage builds.
  - Combine RUN commands to reduce layer size.
- **Python:**
  - Type hint everything.
  - Use `pydantic` for configuration validation where possible.

## 4. Forbidden Patterns

- Hardcoding passwords or secrets (Use environment variables).
- Creating "All-in-one" setup scripts. Split them into `install_dependencies.sh`, `setup_infra.sh`, `start_services.sh`.
- Leaving "Tutorial" code or "Playground" tests in the main branch.
