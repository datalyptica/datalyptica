#!/bin/bash
# generate-certificates.sh
# Generate self-signed certificates for ShuDL services

set -e

CERT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../secrets/certificates" && pwd)"
DAYS_VALID=825  # ~2 years

echo "🔐 Generating TLS/SSL Certificates for ShuDL Services"
echo "=================================================="
echo "Certificate directory: $CERT_DIR"
echo ""

# Create directory structure
mkdir -p "$CERT_DIR"/{ca,postgresql,minio,nessie,trino,kafka,grafana}

# Function to generate CA
generate_ca() {
    echo "📜 Generating Certificate Authority (CA)..."
    
    # Generate CA private key
    openssl genrsa -out "$CERT_DIR/ca/ca-key.pem" 4096
    
    # Generate CA certificate
    openssl req -new -x509 -days $DAYS_VALID \
        -key "$CERT_DIR/ca/ca-key.pem" \
        -out "$CERT_DIR/ca/ca-cert.pem" \
        -subj "/C=US/ST=State/L=City/O=ShuDL/OU=Engineering/CN=ShuDL-CA"
    
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
O = ShuDL
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

# Generate service certificates
generate_service_cert "postgresql" "docker-postgresql" "DNS.4 = docker-postgresql"
generate_service_cert "minio" "docker-minio" "DNS.4 = docker-minio\nDNS.5 = minio.local"
generate_service_cert "nessie" "docker-nessie" "DNS.4 = docker-nessie"
generate_service_cert "trino" "docker-trino" "DNS.4 = docker-trino"
generate_service_cert "kafka" "docker-kafka" "DNS.4 = docker-kafka\nDNS.5 = docker-zookeeper"
generate_service_cert "grafana" "docker-grafana" "DNS.4 = docker-grafana"

echo ""
echo "✅ All certificates generated successfully!"
echo ""
echo "📁 Certificate locations:"
echo "  CA Certificate: $CERT_DIR/ca/ca-cert.pem"
echo "  PostgreSQL: $CERT_DIR/postgresql/"
echo "  MinIO: $CERT_DIR/minio/"
echo "  Nessie: $CERT_DIR/nessie/"
echo "  Trino: $CERT_DIR/trino/"
echo "  Kafka: $CERT_DIR/kafka/"
echo "  Grafana: $CERT_DIR/grafana/"
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
