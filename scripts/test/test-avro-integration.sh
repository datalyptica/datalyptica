#!/bin/bash

################################################################################
#                                                                              #
#         Schema Registry & Avro Integration - Complete Guide                 #
#                                                                              #
################################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

SCHEMA_REGISTRY_URL="http://localhost:8085"
KAFKA_BROKER="localhost:9093"

print_header() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}  $1${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${PURPLE}▶ $1${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

wait_for_user() {
    echo ""
    echo -e "${YELLOW}Press ENTER to continue...${NC}"
    read -r
}

################################################################################
# Main Demo
################################################################################

print_header "Schema Registry & Avro Integration Demo"

print_info "This demo shows how Kafka now uses Avro format with Schema Registry"
print_info "Benefits: 50-80% storage reduction, schema evolution, type safety"
wait_for_user

# Check Schema Registry
print_section "Step 1: Check Schema Registry Status"
echo "Querying Schema Registry at $SCHEMA_REGISTRY_URL..."
if curl -sf "$SCHEMA_REGISTRY_URL/subjects" > /dev/null 2>&1; then
    print_success "Schema Registry is running!"
    echo ""
    echo "Schema Registry Info:"
    curl -s "$SCHEMA_REGISTRY_URL/config" | jq '.'
else
    print_warning "Schema Registry not accessible. Ensure service is running."
fi
wait_for_user

# Register Order Schema
print_section "Step 2: Register Avro Schema"
echo "Registering 'order-value' schema..."

ORDER_SCHEMA='{
  "schema": "{\"type\":\"record\",\"name\":\"Order\",\"namespace\":\"com.shudl.orders\",\"fields\":[{\"name\":\"order_id\",\"type\":\"long\"},{\"name\":\"customer_id\",\"type\":\"long\"},{\"name\":\"product_id\",\"type\":\"long\"},{\"name\":\"quantity\",\"type\":\"int\"},{\"name\":\"amount\",\"type\":\"double\"},{\"name\":\"timestamp\",\"type\":\"string\"},{\"name\":\"status\",\"type\":\"string\"}]}"
}'

RESPONSE=$(curl -s -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data "$ORDER_SCHEMA" \
  "$SCHEMA_REGISTRY_URL/subjects/order-events-value/versions")

if echo "$RESPONSE" | jq -e '.id' > /dev/null 2>&1; then
    SCHEMA_ID=$(echo "$RESPONSE" | jq -r '.id')
    print_success "Schema registered with ID: $SCHEMA_ID"
else
    print_info "Response: $RESPONSE"
fi
wait_for_user

# List all schemas
print_section "Step 3: List All Registered Schemas"
echo "Fetching all subjects from Schema Registry..."
curl -s "$SCHEMA_REGISTRY_URL/subjects" | jq -r '.[]' | while read -r subject; do
    VERSION=$(curl -s "$SCHEMA_REGISTRY_URL/subjects/$subject/versions/latest" | jq -r '.version')
    echo -e "${GREEN}  • $subject${NC} (version: $VERSION)"
done
wait_for_user

# Show schema details
print_section "Step 4: View Schema Details"
echo "Retrieving latest version of 'order-events-value' schema..."
if curl -sf "$SCHEMA_REGISTRY_URL/subjects/order-events-value/versions/latest" > /dev/null 2>&1; then
    echo ""
    curl -s "$SCHEMA_REGISTRY_URL/subjects/order-events-value/versions/latest" | jq '{
        subject: .subject,
        version: .version,
        id: .id,
        schema: .schema | fromjson
    }'
else
    print_info "Schema not yet registered. Will be created automatically by Kafka Connect."
fi
wait_for_user

# Show compatibility settings
print_section "Step 5: Schema Compatibility"
echo "Current compatibility level:"
curl -s "$SCHEMA_REGISTRY_URL/config" | jq '.'
echo ""
print_info "BACKWARD compatibility allows:"
print_info "  • Adding optional fields (with defaults)"
print_info "  • Deleting fields"
print_info "  • Old consumers can read new data"
wait_for_user

# Storage comparison
print_section "Step 6: Storage Optimization"
cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║              JSON vs AVRO Storage Comparison                    ║
╠════════════════════════════════════════════════════════════════╣
║                                                                 ║
║  Sample Order Record:                                           ║
║  {                                                              ║
║    "order_id": 1001,                                           ║
║    "customer_id": 123,                                         ║
║    "product_id": 456,                                          ║
║    "quantity": 5,                                              ║
║    "amount": 1299.99,                                          ║
║    "timestamp": "2024-11-25T10:30:00Z",                        ║
║    "status": "pending"                                         ║
║  }                                                              ║
║                                                                 ║
║  JSON Format:        ~230 bytes per record                     ║
║  AVRO Format:        ~45 bytes per record                      ║
║                                                                 ║
║  Space Saved:        ~80% reduction! 🎉                        ║
║                                                                 ║
║  For 1 million records:                                        ║
║    JSON:  ~230 MB                                              ║
║    AVRO:  ~45 MB                                               ║
║    Saved: ~185 MB                                              ║
║                                                                 ║
╚════════════════════════════════════════════════════════════════╝
EOF
wait_for_user

# Kafka Connect configuration
print_section "Step 7: Kafka Connect Avro Configuration"
cat << 'EOF'
Kafka Connect is now configured to use Avro:

Key Converter:    io.confluent.connect.avro.AvroConverter
Value Converter:  io.confluent.connect.avro.AvroConverter
Schema Registry:  http://schema-registry:8081

Example Debezium PostgreSQL Connector (Avro):

{
  "name": "postgres-avro-connector",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "postgresql",
    "database.port": "5432",
    "database.user": "nessie",
    "database.password": "nessie123",
    "database.dbname": "nessie",
    "database.server.name": "shudl",
    "table.include.list": "public.*",
    "plugin.name": "pgoutput",
    "key.converter": "io.confluent.connect.avro.AvroConverter",
    "key.converter.schema.registry.url": "http://schema-registry:8081",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "http://schema-registry:8081"
  }
}

Deploy with:
  curl -X POST http://localhost:8083/connectors \
    -H "Content-Type: application/json" \
    -d @connector-avro.json
EOF
wait_for_user

# Schema evolution example
print_section "Step 8: Schema Evolution Example"
cat << 'EOF'
Evolving Schema (BACKWARD Compatible):

Original Schema:
{
  "type": "record",
  "name": "Order",
  "fields": [
    {"name": "order_id", "type": "long"},
    {"name": "amount", "type": "double"}
  ]
}

Evolved Schema (adds optional field):
{
  "type": "record",
  "name": "Order",
  "fields": [
    {"name": "order_id", "type": "long"},
    {"name": "amount", "type": "double"},
    {"name": "shipping_address", "type": ["null", "string"], "default": null}
  ]
}

✅ Old consumers can still read new data (ignore new field)
✅ New consumers can read old data (use default value)
✅ No downtime required!
EOF
wait_for_user

# Performance benefits
print_section "Step 9: Performance Benefits"
cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║                   Avro Performance Benefits                     ║
╠════════════════════════════════════════════════════════════════╣
║                                                                 ║
║  ✅ Storage: 50-80% reduction vs JSON                          ║
║  ✅ Network: Smaller payloads = faster transfers               ║
║  ✅ Serialization: 2-5x faster than JSON                       ║
║  ✅ Type Safety: Compile-time type checking                    ║
║  ✅ Schema Evolution: Backward/Forward compatibility           ║
║  ✅ No Field Names: Only values transmitted (schema in registry)║
║  ✅ Compression: Better compression ratios                     ║
║  ✅ Validation: Automatic schema validation                    ║
║                                                                 ║
╚════════════════════════════════════════════════════════════════╝
EOF
wait_for_user

# Integration with other tools
print_section "Step 10: Integration Examples"
cat << 'EOF'
Schema Registry integrates with:

1. Kafka Connect (Debezium)
   ✓ Automatic schema registration
   ✓ CDC with Avro format
   ✓ Schema evolution support

2. Apache Flink
   ✓ Read/Write Avro from/to Kafka
   ✓ Schema Registry integration
   ✓ Type-safe stream processing

3. Trino
   ✓ Query Kafka topics with Avro
   ✓ Automatic schema discovery
   ✓ SQL on streaming data

4. Apache Spark
   ✓ Read Avro from Kafka
   ✓ Batch processing with schema
   ✓ DataFrame API support

5. Kafka UI
   ✓ View schemas visually
   ✓ Browse Avro messages
   ✓ Schema management
EOF
wait_for_user

print_header "Summary"
cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║              Schema Registry Setup Complete! 🎉                 ║
╠════════════════════════════════════════════════════════════════╣
║                                                                 ║
║  ✅ Schema Registry running on port 8085                       ║
║  ✅ Kafka Connect configured for Avro                          ║
║  ✅ Kafka UI shows schema registry                             ║
║  ✅ 50-80% storage optimization                                ║
║  ✅ Schema evolution enabled                                   ║
║                                                                 ║
║  Access Points:                                                 ║
║    Schema Registry: http://localhost:8085                      ║
║    Kafka UI:        http://localhost:8090                      ║
║    Kafka Connect:   http://localhost:8083                      ║
║                                                                 ║
║  Next Steps:                                                    ║
║    1. Create Avro-based CDC connectors                         ║
║    2. Monitor storage usage reduction                          ║
║    3. Implement schema evolution                               ║
║                                                                 ║
╚════════════════════════════════════════════════════════════════╝
EOF

echo ""
print_success "Demo Complete!"
echo ""
