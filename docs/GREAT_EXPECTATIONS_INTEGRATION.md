# Great Expectations Integration Guide

## Quick Start

### 1. Build and Start

```bash
# Build the image
./scripts/build/build-great-expectations.sh

# Start the service
cd docker
docker compose up -d great-expectations

# Check status
docker compose ps great-expectations
```

### 2. Access JupyterLab

1. Open browser: http://localhost:8888
2. Enter token: `datalyptica-ge-token` (or value from `.env`)
3. Navigate to `config/notebooks/01_getting_started.ipynb`

### 3. Verify Connections

Run this in a notebook cell:

```python
import great_expectations as gx
from sqlalchemy import create_engine
import os

# Test PostgreSQL
pg_conn = f"postgresql://{os.getenv('POSTGRES_USER')}:{os.getenv('POSTGRES_PASSWORD')}@postgresql:5432/datalyptica"
engine = create_engine(pg_conn)
with engine.connect() as conn:
    result = conn.execute("SELECT version()")
    print("✅ PostgreSQL:", result.fetchone()[0][:50])

# Test Trino
from trino.dbapi import connect
conn = connect(host='trino', port=8080, user='admin')
cursor = conn.cursor()
cursor.execute("SELECT version()")
print("✅ Trino:", cursor.fetchone()[0])

# Test MinIO
import boto3
s3 = boto3.client(
    's3',
    endpoint_url=os.getenv('S3_ENDPOINT'),
    aws_access_key_id=os.getenv('S3_ACCESS_KEY'),
    aws_secret_access_key=os.getenv('S3_SECRET_KEY')
)
buckets = s3.list_buckets()
print("✅ MinIO buckets:", [b['Name'] for b in buckets['Buckets']])
```

## Example Use Cases

### Use Case 1: Validate Iceberg Table Quality

```python
import great_expectations as gx
from great_expectations.core.batch import RuntimeBatchRequest

context = gx.get_context()

# Create expectation suite for orders table
suite = context.create_expectation_suite("orders_quality", overwrite_existing=True)

# Add business rules
expectations = [
    {
        "expectation_type": "expect_table_row_count_to_be_between",
        "kwargs": {"min_value": 1}
    },
    {
        "expectation_type": "expect_column_values_to_not_be_null",
        "kwargs": {"column": "order_id"}
    },
    {
        "expectation_type": "expect_column_values_to_be_unique",
        "kwargs": {"column": "order_id"}
    },
    {
        "expectation_type": "expect_column_values_to_be_between",
        "kwargs": {
            "column": "order_amount",
            "min_value": 0,
            "max_value": 1000000
        }
    }
]

for exp in expectations:
    suite.add_expectation(**exp)

context.save_expectation_suite(suite)

# Create batch request for Trino/Iceberg table
batch_request = RuntimeBatchRequest(
    datasource_name="trino_datasource",
    data_connector_name="default_runtime_data_connector_name",
    data_asset_name="iceberg.analytics.orders",
    runtime_parameters={"query": "SELECT * FROM iceberg.analytics.orders LIMIT 10000"},
    batch_identifiers={"default_identifier_name": "orders_validation"}
)

# Run validation
validator = context.get_validator(
    batch_request=batch_request,
    expectation_suite_name="orders_quality"
)

results = validator.validate()

if results["success"]:
    print("✅ All data quality checks passed!")
else:
    print("❌ Data quality issues found:")
    for result in results["results"]:
        if not result["success"]:
            print(f"  - {result['expectation_config']['expectation_type']}")
```

### Use Case 2: Profile Existing Data

```python
import great_expectations as gx

context = gx.get_context()

# Auto-generate expectations from data
from great_expectations.profile.user_configurable_profiler import UserConfigurableProfiler

batch_request = {
    "datasource_name": "trino_datasource",
    "data_connector_name": "default_inferred_data_connector_name",
    "data_asset_name": "analytics.customers"
}

validator = context.get_validator(
    batch_request=batch_request,
    create_expectation_suite_with_name="customers_profiled"
)

profiler = UserConfigurableProfiler(
    profile_dataset=validator,
    excluded_expectations=[
        "expect_column_quantile_values_to_be_between"
    ]
)

suite = profiler.build_suite()
context.save_expectation_suite(suite)

print(f"Generated {len(suite.expectations)} expectations automatically!")
```

### Use Case 3: Data Pipeline Integration

```python
# In your Spark/Flink job:
import great_expectations as gx

def validate_dataframe(df, table_name):
    """Validate Spark DataFrame before writing to Iceberg"""
    context = gx.get_context()

    # Convert Spark DF to Pandas for validation (sample for large datasets)
    sample_df = df.limit(10000).toPandas()

    batch_request = RuntimeBatchRequest(
        datasource_name="s3_pandas_datasource",
        data_connector_name="default_runtime_data_connector_name",
        data_asset_name=table_name,
        runtime_parameters={"batch_data": sample_df},
        batch_identifiers={"default_identifier_name": f"{table_name}_batch"}
    )

    validator = context.get_validator(
        batch_request=batch_request,
        expectation_suite_name=f"{table_name}_quality"
    )

    results = validator.validate()

    if not results["success"]:
        raise ValueError(f"Data quality validation failed for {table_name}")

    return results

# Usage in ETL pipeline
validated_df = spark.sql("SELECT * FROM source_table")
validation_results = validate_dataframe(validated_df, "target_table")
validated_df.write.format("iceberg").save("iceberg.analytics.target_table")
```

### Use Case 4: Scheduled Quality Checks

```python
# Create checkpoint for automated runs
checkpoint_config = {
    "name": "nightly_data_quality",
    "config_version": 1.0,
    "class_name": "SimpleCheckpoint",
    "run_name_template": "%Y%m%d-%H%M%S-nightly",
    "validations": [
        {
            "batch_request": {
                "datasource_name": "trino_datasource",
                "data_connector_name": "default_inferred_data_connector_name",
                "data_asset_name": "analytics.orders",
            },
            "expectation_suite_name": "orders_quality"
        },
        {
            "batch_request": {
                "datasource_name": "trino_datasource",
                "data_connector_name": "default_inferred_data_connector_name",
                "data_asset_name": "analytics.customers",
            },
            "expectation_suite_name": "customers_quality"
        }
    ],
}

context.add_checkpoint(**checkpoint_config)

# Run checkpoint (can be triggered by Airflow/cron)
results = context.run_checkpoint(checkpoint_name="nightly_data_quality")

# Send alerts if failed
if not results["success"]:
    send_alert_to_slack("Data quality validation failed!")
```

## Integration with Airflow

Create an Airflow DAG: `dags/data_quality_validation.py`

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.docker.operators.docker import DockerOperator
from datetime import datetime, timedelta

def run_ge_checkpoint():
    import great_expectations as gx
    context = gx.get_context()
    results = context.run_checkpoint(checkpoint_name="nightly_data_quality")

    if not results["success"]:
        raise ValueError("Data quality validation failed!")

    return results

default_args = {
    'owner': 'data-eng',
    'depends_on_past': False,
    'email_on_failure': True,
    'email': ['data-eng@company.com'],
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    'data_quality_validation',
    default_args=default_args,
    description='Daily data quality validation with Great Expectations',
    schedule_interval='0 2 * * *',  # 2 AM daily
    start_date=datetime(2025, 11, 30),
    catchup=False,
    tags=['data-quality', 'great-expectations'],
) as dag:

    validate_task = PythonOperator(
        task_id='validate_data_quality',
        python_callable=run_ge_checkpoint,
    )

    # Or use Docker operator to run in GE container
    validate_in_container = DockerOperator(
        task_id='validate_in_ge_container',
        image='ghcr.io/datalyptica/datalyptica/great-expectations:v1.0.0',
        api_version='auto',
        auto_remove=True,
        command='python -c "import great_expectations as gx; gx.get_context().run_checkpoint(\'nightly_data_quality\')"',
        docker_url='unix://var/run/docker.sock',
        network_mode='docker_data_network',
    )
```

## Monitoring & Alerting

### Export Metrics to Prometheus

```python
# In your validation script
from prometheus_client import Counter, Gauge, push_to_gateway

validation_counter = Counter('ge_validations_total', 'Total validations', ['status', 'suite'])
validation_gauge = Gauge('ge_validation_success_rate', 'Validation success rate', ['suite'])

def run_validation_with_metrics(checkpoint_name):
    context = gx.get_context()
    results = context.run_checkpoint(checkpoint_name=checkpoint_name)

    status = 'success' if results['success'] else 'failed'
    validation_counter.labels(status=status, suite=checkpoint_name).inc()

    success_rate = results['statistics']['successful_expectations'] / results['statistics']['evaluated_expectations']
    validation_gauge.labels(suite=checkpoint_name).set(success_rate)

    # Push to Prometheus
    push_to_gateway('prometheus:9091', job='great_expectations', registry=registry)

    return results
```

## Best Practices

1. **Start with Critical Tables**: Focus on high-value data first
2. **Use Sampling**: Validate samples of large tables to reduce overhead
3. **Version Expectations**: Store in Git alongside code
4. **Document Business Rules**: Add metadata to expectations
5. **Monitor Trends**: Track validation metrics over time
6. **Fail Fast**: Validate early in pipeline to catch issues sooner
7. **Generate Docs**: Keep data documentation up-to-date

## Troubleshooting

```bash
# View logs
docker logs docker-great-expectations

# Access shell
docker exec -it docker-great-expectations bash

# Test connections
docker exec docker-great-expectations python -c "
from sqlalchemy import create_engine
import os
conn = f\"postgresql://{os.getenv('POSTGRES_USER')}:{os.getenv('POSTGRES_PASSWORD')}@postgresql:5432/datalyptica\"
engine = create_engine(conn)
print(engine.execute('SELECT 1').fetchone())
"

# Rebuild if needed
docker compose build great-expectations
docker compose up -d great-expectations
```

## Next Steps

1. Review getting started notebook: `01_getting_started.ipynb`
2. Create expectations for your critical tables
3. Set up automated checkpoints
4. Integrate with CI/CD pipeline
5. Configure alerting for failures
6. Generate and publish data documentation
