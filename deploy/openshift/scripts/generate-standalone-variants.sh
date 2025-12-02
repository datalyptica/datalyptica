#!/usr/bin/env zsh

# Script to generate standalone deployment variants from HA manifests
# This converts HA configurations to single-replica standalone deployments

set -eo pipefail

SCRIPT_DIR="${0:a:h}"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HA_DIR="$PROJECT_ROOT/deploy/openshift"
STANDALONE_DIR="$PROJECT_ROOT/deploy/openshift/standalone"

echo "🔧 Generating standalone deployment variants..."
echo "   HA source: $HA_DIR"
echo "   Standalone target: $STANDALONE_DIR"
echo

# Layers and services to convert (using zsh associative array)
typeset -A LAYERS
LAYERS=(
    storage "postgresql minio"
    control "kafka schema-registry kafka-connect"
    data "nessie trino spark flink clickhouse dbt"
    management "prometheus grafana loki alertmanager alloy kafka-ui airflow jupyterhub mlflow superset great-expectations"
    infrastructure "keycloak redis"
)

# Function to convert replicas to 1
convert_replicas() {
    local file="$1"
    sed -i.bak 's/^  replicas: [0-9]\+$/  replicas: 1/g' "$file"
    rm -f "${file}.bak"
}

# Function to convert required to preferred anti-affinity
convert_anti_affinity() {
    local file="$1"
    if grep -q "requiredDuringSchedulingIgnoredDuringExecution" "$file"; then
        # Replace required with preferred
        sed -i.bak '/requiredDuringSchedulingIgnoredDuringExecution:/,/topologyKey:/{
            s/requiredDuringSchedulingIgnoredDuringExecution:/preferredDuringSchedulingIgnoredDuringExecution:\
          - weight: 100\
            podAffinityTerm:/
            s/- labelSelector:/labelSelector:/
            s/  topologyKey:/topologyKey:/
        }' "$file"
        rm -f "${file}.bak"
    fi
}

# Function to convert storage class
convert_storage_class() {
    local file="$1"
    sed -i.bak 's/storageClassName: fast-ssd/storageClassName: standard/g' "$file"
    rm -f "${file}.bak"
}

# Function to reduce resources by 50%
reduce_resources() {
    local file="$1"
    # This is complex, so we'll just add a comment for manual adjustment
    if grep -q "resources:" "$file"; then
        echo "⚠️  Manual resource adjustment needed: $file"
    fi
}

# Function to add deployment-mode label
add_deployment_mode_label() {
    local file="$1"
    if grep -q "labels:" "$file"; then
        sed -i.bak '/labels:/a\    deployment-mode: standalone' "$file"
        rm -f "${file}.bak"
    fi
}

# Process each layer
for layer in "${(@k)LAYERS}"; do
    echo "📦 Processing $layer layer..."
    
    for service in ${=LAYERS[$layer]}; do
        echo "   → Converting $service..."
        
        # Create target directory
        mkdir -p "$STANDALONE_DIR/$layer/$service"
        
        # Copy all files from HA to standalone
        if [ -d "$HA_DIR/$layer/$service" ]; then
            cp -r "$HA_DIR/$layer/$service/"* "$STANDALONE_DIR/$layer/$service/" 2>/dev/null || true
            
            # Convert each YAML file
            for yaml_file in "$STANDALONE_DIR/$layer/$service"/*.yaml; do
                if [ -f "$yaml_file" ]; then
                    filename=$(basename "$yaml_file")
                    
                    # Skip PDB files (remove them for standalone)
                    if [[ "$filename" == "pdb.yaml" ]]; then
                        rm -f "$yaml_file"
                        echo "      ✗ Removed PDB: $filename"
                        continue
                    fi
                    
                    # Apply conversions
                    if [[ "$filename" == "statefulset.yaml" ]] || [[ "$filename" == "deployment"*.yaml ]] || [[ "$filename" == "statefulset-"*.yaml ]]; then
                        convert_replicas "$yaml_file"
                        convert_anti_affinity "$yaml_file"
                        add_deployment_mode_label "$yaml_file"
                        echo "      ✓ Converted: $filename (replicas=1, preferred anti-affinity)"
                    fi
                    
                    if [[ "$filename" == "statefulset.yaml" ]] || [[ "$filename" == "statefulset-"*.yaml ]]; then
                        convert_storage_class "$yaml_file"
                        echo "      ✓ Updated storage class: standard"
                    fi
                fi
            done
            
            # Update kustomization.yaml to remove PDB reference
            if [ -f "$STANDALONE_DIR/$layer/$service/kustomization.yaml" ]; then
                sed -i.bak '/- pdb.yaml/d' "$STANDALONE_DIR/$layer/$service/kustomization.yaml"
                rm -f "$STANDALONE_DIR/$layer/$service/kustomization.yaml.bak"
            fi
        else
            echo "      ⚠️  Source directory not found: $HA_DIR/$layer/$service"
        fi
    done
    echo
done

# Create standalone kustomization files for each layer
echo "📝 Creating layer kustomization files..."
for layer in "${(@k)LAYERS}"; do
    cat > "$STANDALONE_DIR/$layer/kustomization.yaml" <<EOF
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: datalyptica-$layer

resources:
EOF
    
    for service in ${=LAYERS[$layer]}; do
        if [ -d "$STANDALONE_DIR/$layer/$service" ]; then
            echo "  - $service" >> "$STANDALONE_DIR/$layer/kustomization.yaml"
        fi
    done
    
    echo "   ✓ Created $layer/kustomization.yaml"
done

# Create root standalone kustomization
echo
echo "📝 Creating root standalone kustomization..."
cat > "$STANDALONE_DIR/kustomization.yaml" <<'EOF'
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Standalone deployment variant - single replica, reduced resources
# Suitable for development, testing, and demo environments

resources:
  - storage
  - infrastructure
  - control
  - data
  - management
  
commonLabels:
  deployment-mode: standalone
  environment: development
EOF

echo "   ✓ Created standalone/kustomization.yaml"

echo
echo "✅ Standalone deployment variants generated successfully!"
echo
echo "📋 Summary:"
echo "   - All services converted to replicas: 1"
echo "   - Anti-affinity: required → preferred"
echo "   - Storage class: fast-ssd → standard"
echo "   - PodDisruptionBudgets: removed"
echo
echo "⚠️  Manual adjustments needed:"
echo "   - Review and reduce resource requests/limits by ~50%"
echo "   - Update PostgreSQL to single-node mode (disable Patroni clustering)"
echo "   - Update Redis to single-node mode (disable Sentinel)"
echo "   - Update Kafka to single-broker mode"
echo "   - Update ClickHouse to single-node mode"
echo
echo "📖 Next steps:"
echo "   1. Review generated files in: $STANDALONE_DIR"
echo "   2. Test deployment: kubectl apply -k $STANDALONE_DIR"
echo "   3. Update documentation with standalone deployment instructions"
