#!/bin/bash
# generate-certificates.sh
# Generate self-signed certificates for Datalyptica services

set -e

CERT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../secrets/certificates" && pwd)"
DAYS_VALID=825  # ~2 years

echo "🔐 Generating TLS/SSL Certificates for Datalyptica Services"
echo "=================================================="
echo "Certificate directory: $CERT_DIR"
echo ""

# Create directory structure for all services
mkdir -p "$CERT_DIR"/{ca,postgresql,minio,nessie,trino,kafka,grafana,prometheus,schema-registry,kafka-connect,clickhouse,keycloak,flink,spark,loki,alertmanager,etcd-1,etcd-2,etcd-3}

# Function to generate CA
generate_ca() {
    echo "📜 Generating Certificate Authority (CA)..."
    
    # Generate CA private key
    openssl genrsa -out "$CERT_DIR/ca/ca-key.pem" 4096
    
    # Generate CA certificate
    openssl req -new -x509 -days $DAYS_VALID \
        -key "$CERT_DIR/ca/ca-key.pem" \
        -out "$CERT_DIR/ca/ca-cert.pem" \
        -subj "/C=US/ST=State/L=City/O=Datalyptica/OU=Engineering/CN=Datalyptica-CA"
    
    echo "✅ CA certificate generated"
}

# Function to generate service certificate
generate_service_cert() {
    local service=$1
    local common_name=$2
    local san_names=$3
    
    echo "🔑 Generating certificate for $service..."
    
    local service_dir="$CERT_DIR/$service"
    
    # Generate private key
    openssl genrsa -out "$service_dir/server-key.pem" 2048
    
    # Create OpenSSL config with SAN
    cat > "$service_dir/openssl.cnf" <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = Datalyptica
OU = Engineering
CN = $common_name

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $common_name
DNS.2 = localhost
DNS.3 = *.local
IP.1 = 127.0.0.1
$san_names
EOF
    
    # Generate CSR
    openssl req -new \
        -key "$service_dir/server-key.pem" \
        -out "$service_dir/server.csr" \
        -config "$service_dir/openssl.cnf"
    
    # Sign certificate with CA
    openssl x509 -req -days $DAYS_VALID \
        -in "$service_dir/server.csr" \
        -CA "$CERT_DIR/ca/ca-cert.pem" \
        -CAkey "$CERT_DIR/ca/ca-key.pem" \
        -CAcreateserial \
        -out "$service_dir/server-cert.pem" \
        -extensions v3_req \
        -extfile "$service_dir/openssl.cnf"
    
    # Create combined certificate chain
    cat "$service_dir/server-cert.pem" "$CERT_DIR/ca/ca-cert.pem" > "$service_dir/server-chain.pem"
    
    # Set secure permissions
    chmod 600 "$service_dir/server-key.pem"
    chmod 644 "$service_dir/server-cert.pem"
    
    # Clean up CSR and config
    rm -f "$service_dir/server.csr" "$service_dir/openssl.cnf"
    
    echo "✅ Certificate generated for $service"
}

# Generate CA
generate_ca

# Generate service certificates for all 20 services

echo ""
echo "📦 Generating certificates for all Datalyptica services..."
echo ""

# Consensus Layer (etcd for Patroni)
generate_service_cert "etcd-1" "docker-etcd-1" "DNS.4 = docker-etcd-1\nDNS.5 = etcd-1\nDNS.6 = etcd1"
generate_service_cert "etcd-2" "docker-etcd-2" "DNS.4 = docker-etcd-2\nDNS.5 = etcd-2\nDNS.6 = etcd2"
generate_service_cert "etcd-3" "docker-etcd-3" "DNS.4 = docker-etcd-3\nDNS.5 = etcd-3\nDNS.6 = etcd3"

# Storage Layer
generate_service_cert "postgresql" "docker-postgresql" "DNS.4 = docker-postgresql\nDNS.5 = postgresql\nDNS.6 = docker-postgresql-patroni-1\nDNS.7 = docker-postgresql-patroni-2\nDNS.8 = postgresql-patroni-1\nDNS.9 = postgresql-patroni-2"
generate_service_cert "minio" "docker-minio" "DNS.4 = docker-minio\nDNS.5 = minio.local\nDNS.6 = minio"
generate_service_cert "nessie" "docker-nessie" "DNS.4 = docker-nessie\nDNS.5 = nessie"

# Streaming Layer
generate_service_cert "kafka" "docker-kafka" "DNS.4 = docker-kafka\nDNS.5 = kafka"
generate_service_cert "schema-registry" "docker-schema-registry" "DNS.4 = docker-schema-registry\nDNS.5 = schema-registry"

# Processing Layer
generate_service_cert "spark" "docker-spark-master" "DNS.4 = docker-spark-master\nDNS.5 = docker-spark-worker\nDNS.6 = spark-master\nDNS.7 = spark-worker"
generate_service_cert "flink" "docker-flink-jobmanager" "DNS.4 = docker-flink-jobmanager\nDNS.5 = docker-flink-taskmanager\nDNS.6 = flink-jobmanager\nDNS.7 = flink-taskmanager"

# Query Layer
generate_service_cert "trino" "docker-trino" "DNS.4 = docker-trino\nDNS.5 = trino"
generate_service_cert "clickhouse" "docker-clickhouse" "DNS.4 = docker-clickhouse\nDNS.5 = clickhouse"
generate_service_cert "kafka-connect" "docker-kafka-connect" "DNS.4 = docker-kafka-connect\nDNS.5 = kafka-connect"

# Observability Layer  
generate_service_cert "prometheus" "docker-prometheus" "DNS.4 = docker-prometheus\nDNS.5 = prometheus"
generate_service_cert "grafana" "docker-grafana" "DNS.4 = docker-grafana\nDNS.5 = grafana"
generate_service_cert "loki" "docker-loki" "DNS.4 = docker-loki\nDNS.5 = loki"
generate_service_cert "alertmanager" "docker-alertmanager" "DNS.4 = docker-alertmanager\nDNS.5 = alertmanager"
generate_service_cert "keycloak" "docker-keycloak" "DNS.4 = docker-keycloak\nDNS.5 = keycloak"

echo ""
echo "✅ All certificates generated successfully!"
echo ""
echo "📁 Certificate locations:"
echo "  CA Certificate: $CERT_DIR/ca/ca-cert.pem"
echo ""
echo "  Consensus Layer (High Availability):"
echo "    - etcd-1: $CERT_DIR/etcd-1/"
echo "    - etcd-2: $CERT_DIR/etcd-2/"
echo "    - etcd-3: $CERT_DIR/etcd-3/"
echo ""
echo "  Storage Layer:"
echo "    - PostgreSQL (Patroni): $CERT_DIR/postgresql/"
echo "    - MinIO: $CERT_DIR/minio/"
echo "    - Nessie: $CERT_DIR/nessie/"
echo ""
echo "  Streaming Layer:"
echo "    - Kafka: $CERT_DIR/kafka/"
echo "    - Schema Registry: $CERT_DIR/schema-registry/"
echo ""
echo "  Processing Layer:"
echo "    - Spark: $CERT_DIR/spark/"
echo "    - Flink: $CERT_DIR/flink/"
echo ""
echo "  Query Layer:"
echo "    - Trino: $CERT_DIR/trino/"
echo "    - ClickHouse: $CERT_DIR/clickhouse/"
echo "    - Kafka Connect: $CERT_DIR/kafka-connect/"
echo ""
echo "  Observability Layer:"
echo "    - Prometheus: $CERT_DIR/prometheus/"
echo "    - Grafana: $CERT_DIR/grafana/"
echo "    - Loki: $CERT_DIR/loki/"
echo "    - Alertmanager: $CERT_DIR/alertmanager/"
echo "    - Keycloak: $CERT_DIR/keycloak/"
echo ""
echo "⚠️  IMPORTANT:"
echo "  - Keep the CA private key secure: $CERT_DIR/ca/ca-key.pem"
echo "  - Distribute CA certificate to clients: $CERT_DIR/ca/ca-cert.pem"
echo "  - Certificates valid for $DAYS_VALID days (~2 years)"
echo "  - Set calendar reminder to regenerate before expiry"
echo ""
echo "📝 Next steps:"
echo "  1. Review generated certificates"
echo "  2. Update docker-compose.yml to mount certificates"
echo "  3. Configure services to use TLS"
echo "  4. Update client connections to use SSL"
echo "  5. Test connectivity with: openssl s_client -connect localhost:PORT"
