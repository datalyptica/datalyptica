# Great Expectations Example Expectations
# Data Quality Validation Suites

from great_expectations.core.batch import RuntimeBatchRequest
from great_expectations.checkpoint import SimpleCheckpoint
import great_expectations as gx
import os

def create_basic_data_quality_suite():
    """
    Creates a basic data quality expectation suite for Iceberg tables
    """
    context = gx.get_context()
    
    # Create expectation suite
    suite_name = "iceberg_table_basic_quality"
    suite = context.create_expectation_suite(
        expectation_suite_name=suite_name,
        overwrite_existing=True
    )
    
    # Add expectations
    expectations = [
        {
            "expectation_type": "expect_table_row_count_to_be_between",
            "kwargs": {
                "min_value": 0,
                "max_value": None,
            }
        },
        {
            "expectation_type": "expect_table_columns_to_match_ordered_list",
            "kwargs": {
                "column_list": []  # Will be populated at runtime
            }
        },
        {
            "expectation_type": "expect_column_values_to_not_be_null",
            "kwargs": {
                "column": "id"  # Example: primary key should not be null
            }
        },
        {
            "expectation_type": "expect_column_values_to_be_unique",
            "kwargs": {
                "column": "id"  # Example: primary key should be unique
            }
        }
    ]
    
    for expectation in expectations:
        suite.add_expectation(**expectation)
    
    context.save_expectation_suite(suite)
    print(f"Created expectation suite: {suite_name}")
    return suite_name


def create_checkpoint_for_trino_table(table_name, schema_name="default"):
    """
    Creates a checkpoint for validating Trino/Iceberg tables
    """
    context = gx.get_context()
    
    checkpoint_name = f"trino_{schema_name}_{table_name}_checkpoint"
    
    checkpoint_config = {
        "name": checkpoint_name,
        "config_version": 1.0,
        "class_name": "SimpleCheckpoint",
        "run_name_template": f"%Y%m%d-%H%M%S-{table_name}",
        "validations": [
            {
                "batch_request": {
                    "datasource_name": "trino_datasource",
                    "data_connector_name": "default_inferred_data_connector_name",
                    "data_asset_name": f"{schema_name}.{table_name}",
                },
                "expectation_suite_name": "iceberg_table_basic_quality"
            }
        ],
    }
    
    context.add_checkpoint(**checkpoint_config)
    print(f"Created checkpoint: {checkpoint_name}")
    return checkpoint_name


def run_validation(checkpoint_name):
    """
    Runs a checkpoint and returns results
    """
    context = gx.get_context()
    results = context.run_checkpoint(checkpoint_name=checkpoint_name)
    
    if results["success"]:
        print(f"✅ Validation passed for {checkpoint_name}")
    else:
        print(f"❌ Validation failed for {checkpoint_name}")
        
    return results


# Example usage in Jupyter notebook or Python script:
"""
# Initialize context
import great_expectations as gx
context = gx.get_context()

# Create suite and checkpoint
suite_name = create_basic_data_quality_suite()
checkpoint_name = create_checkpoint_for_trino_table("customers", "analytics")

# Run validation
results = run_validation(checkpoint_name)

# View data docs
context.open_data_docs()
"""
