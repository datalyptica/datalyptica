# Great Expectations Integration - Datalyptica Data Quality

## Overview

Great Expectations is integrated into the Datalyptica platform to provide comprehensive data quality validation and documentation for your data platform.

## Features

- **Data Validation**: Validate data quality across PostgreSQL, Trino/Iceberg, and S3/MinIO
- **Expectation Suites**: Define reusable data quality rules
- **Automated Checkpoints**: Schedule validation runs
- **Data Documentation**: Auto-generate data quality reports
- **JupyterLab Interface**: Interactive development environment
- **Multi-Engine Support**: Validate data across Trino, Spark, PostgreSQL

## Quick Start

### 1. Build the Image

```bash
./scripts/build/build-great-expectations.sh
```

### 2. Start the Service

```bash
cd docker
docker compose up -d great-expectations
```

### 3. Access JupyterLab

Open your browser to: http://localhost:8888

**Token**: Use the value from `GE_JUPYTER_TOKEN` in `.env` (default: `datalyptica-ge-token`)

### 4. Open Getting Started Notebook

Navigate to: `config/notebooks/01_getting_started.ipynb`

## Architecture

### Datasources Configured

1. **PostgreSQL**: Direct connection to PostgreSQL databases
   - Connection: `postgresql://datalyptica:***@postgresql:5432/datalyptica`
2. **Trino**: Query Iceberg tables via Trino
   - Connection: `trino://trino:8080/iceberg`
3. **S3/MinIO**: Validate Parquet files in object storage
   - Endpoint: `http://minio:9000`
   - Bucket: `lakehouse`
4. **Spark**: PySpark DataFrame validation
   - Master: `spark://spark-master:7077`

### Storage Backends

- **Expectations Store**: `/opt/great_expectations/expectations/`
- **Validations Store**: `/opt/great_expectations/uncommitted/validations/`
- **Data Docs**:
  - Local: `/opt/great_expectations/uncommitted/data_docs/local_site/`
  - S3: `s3://lakehouse/data_docs/`

## Usage Examples

### Example 1: Validate PostgreSQL Table

```python
import great_expectations as gx

context = gx.get_context()

# Create expectation suite
suite = context.create_expectation_suite("postgres_customers", overwrite_existing=True)

# Add expectations
suite.add_expectation({
    "expectation_type": "expect_column_values_to_not_be_null",
    "kwargs": {"column": "id"}
})

suite.add_expectation({
    "expectation_type": "expect_column_values_to_be_unique",
    "kwargs": {"column": "email"}
})

context.save_expectation_suite(suite)
```

### Example 2: Validate Iceberg Table via Trino

```python
from great_expectations.core.batch import RuntimeBatchRequest

batch_request = RuntimeBatchRequest(
    datasource_name="trino_datasource",
    data_connector_name="default_runtime_data_connector_name",
    data_asset_name="iceberg.analytics.orders",
    runtime_parameters={"query": "SELECT * FROM iceberg.analytics.orders"},
    batch_identifiers={"default_identifier_name": "orders_batch"}
)

validator = context.get_validator(
    batch_request=batch_request,
    expectation_suite_name="postgres_customers"
)

results = validator.validate()
print(results)
```

### Example 3: Create Automated Checkpoint

```python
checkpoint_config = {
    "name": "daily_validation",
    "config_version": 1.0,
    "class_name": "SimpleCheckpoint",
    "validations": [
        {
            "batch_request": {
                "datasource_name": "trino_datasource",
                "data_connector_name": "default_inferred_data_connector_name",
                "data_asset_name": "analytics.customers",
            },
            "expectation_suite_name": "customers_quality_suite"
        }
    ],
}

context.add_checkpoint(**checkpoint_config)

# Run checkpoint
results = context.run_checkpoint(checkpoint_name="daily_validation")
```

### Example 4: Generate Data Documentation

```python
# Build data docs
context.build_data_docs()

# Open in browser (within container)
context.open_data_docs()

# Access via browser at:
# http://localhost:8888/files/uncommitted/data_docs/local_site/index.html
```

## Common Expectation Types

### Column-Level Expectations

- `expect_column_to_exist`: Column must exist in dataset
- `expect_column_values_to_not_be_null`: No null values
- `expect_column_values_to_be_unique`: All values unique
- `expect_column_values_to_be_in_set`: Values from allowed list
- `expect_column_values_to_match_regex`: Pattern matching
- `expect_column_values_to_be_between`: Numeric range validation

### Table-Level Expectations

- `expect_table_row_count_to_be_between`: Row count validation
- `expect_table_columns_to_match_ordered_list`: Schema validation
- `expect_table_column_count_to_equal`: Column count check

### Statistical Expectations

- `expect_column_mean_to_be_between`: Mean value validation
- `expect_column_median_to_be_between`: Median value validation
- `expect_column_stdev_to_be_between`: Standard deviation check

## Configuration Files

### Main Configuration

- `/opt/great_expectations/great_expectations.yml` - Main GE config
- `/opt/great_expectations/config/great_expectations.yml.template` - Template

### Connection Configuration

- `/opt/great_expectations/connections.yaml` - Database connections

### Example Files

- `/opt/great_expectations/config/example_expectations.py` - Python examples
- `/opt/great_expectations/config/notebooks/01_getting_started.ipynb` - Jupyter notebook

## Environment Variables

Configure in `docker/.env`:

```bash
# JupyterLab
GE_JUPYTER_PORT=8888
GE_JUPYTER_TOKEN=datalyptica-ge-token

# Great Expectations
GE_HOME=/opt/great_expectations
GE_DISABLE_ANALYTICS=true

# Connections (inherited from main .env)
POSTGRES_HOST=postgresql
TRINO_HOST=trino
S3_ENDPOINT=http://minio:9000
```

## Integration with CI/CD

### Airflow DAG Example

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
import great_expectations as gx

def run_ge_validation():
    context = gx.get_context()
    results = context.run_checkpoint(checkpoint_name="daily_validation")
    if not results["success"]:
        raise ValueError("Data quality validation failed!")

with DAG('data_quality_check', schedule_interval='@daily') as dag:
    validate_task = PythonOperator(
        task_id='validate_data_quality',
        python_callable=run_ge_validation
    )
```

## Troubleshooting

### Cannot connect to PostgreSQL

```bash
# Check PostgreSQL is healthy
docker exec docker-postgresql pg_isready

# Test connection
docker exec docker-great-expectations psql -h postgresql -U datalyptica -d datalyptica -c "SELECT 1"
```

### Cannot connect to Trino

```bash
# Check Trino is healthy
docker exec docker-trino curl http://localhost:8080/v1/info

# Test from GE container
docker exec docker-great-expectations curl http://trino:8080/v1/info
```

### JupyterLab token issues

```bash
# Get Jupyter token
docker logs docker-great-expectations | grep token

# Or set custom token in .env
GE_JUPYTER_TOKEN=your-custom-token
```

## Performance Considerations

- **Sampling**: For large tables, use `LIMIT` or `TABLESAMPLE` in Trino queries
- **Batch Size**: Configure appropriate batch sizes for validation
- **Parallel Execution**: Enable parallel checkpoint execution for multiple tables
- **Caching**: Use Trino metadata caching for better performance

## Data Docs Deployment

### Local Access

Data docs are available at:

- Within container: `/opt/great_expectations/uncommitted/data_docs/local_site/index.html`
- Via JupyterLab: http://localhost:8888/files/uncommitted/data_docs/local_site/index.html

### S3/MinIO Deployment

Data docs are automatically synced to MinIO:

- Location: `s3://lakehouse/data_docs/`
- Access via MinIO Console: http://localhost:9001

## Best Practices

1. **Start Simple**: Begin with basic expectations (not null, unique)
2. **Use Profilers**: Auto-generate expectations from existing data
3. **Version Control**: Store expectation suites in Git
4. **Document Assumptions**: Add notes to expectations explaining business rules
5. **Monitor Trends**: Track validation results over time
6. **Alert on Failures**: Integrate with Alertmanager for notifications
7. **Regular Reviews**: Update expectations as data evolves

## Resources

- [Great Expectations Docs](https://docs.greatexpectations.io/)
- [Expectation Gallery](https://greatexpectations.io/expectations/)
- [Trino Connector Docs](https://docs.greatexpectations.io/docs/guides/connecting_to_your_data/database/trino/)
- [S3 Connector Docs](https://docs.greatexpectations.io/docs/guides/connecting_to_your_data/cloud/s3/)

## Support

For issues or questions:

- Check logs: `docker logs docker-great-expectations`
- Review configuration: `/opt/great_expectations/great_expectations.yml`
- Test connections in JupyterLab notebook
