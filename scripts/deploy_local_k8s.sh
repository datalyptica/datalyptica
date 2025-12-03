#!/usr/bin/env bash
set -euo pipefail

#######################################
# Datalyptica Local Kubernetes Deployment Script
# Supports both Kind cluster and Helm deployment
#######################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-datalyptica}"
NAMESPACE_CORE="datalyptica-core"
NAMESPACE_APPS="datalyptica-apps"
NAMESPACE_MONITORING="datalyptica-monitoring"
USE_HELM="${USE_HELM:-true}"
HELM_RELEASE_NAME="${HELM_RELEASE_NAME:-datalyptica}"
HELM_CHART_PATH="./deploy/helm/datalyptica"
K8S_MANIFEST_PATH="./deploy/k8s"

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command_exists kubectl; then
        missing_tools+=("kubectl")
    fi
    
    if ! command_exists kind; then
        missing_tools+=("kind")
    fi
    
    if [[ "$USE_HELM" == "true" ]] && ! command_exists helm; then
        missing_tools+=("helm")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        echo "Install instructions:"
        echo "  kubectl: https://kubernetes.io/docs/tasks/tools/"
        echo "  kind: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
        echo "  helm: https://helm.sh/docs/intro/install/"
        exit 1
    fi
    
    print_success "All prerequisites met"
}

# Create Kind cluster
create_kind_cluster() {
    print_info "Checking if Kind cluster '$CLUSTER_NAME' exists..."
    
    if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
        print_warning "Cluster '$CLUSTER_NAME' already exists"
        read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Deleting existing cluster..."
            kind delete cluster --name "$CLUSTER_NAME"
        else
            print_info "Using existing cluster"
            return 0
        fi
    fi
    
    print_info "Creating Kind cluster '$CLUSTER_NAME'..."
    
    cat <<EOF | kind create cluster --name "$CLUSTER_NAME" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 5432
    hostPort: 5432
    protocol: TCP
  - containerPort: 9000
    hostPort: 9000
    protocol: TCP
  - containerPort: 9001
    hostPort: 9001
    protocol: TCP
  - containerPort: 8080
    hostPort: 8080
    protocol: TCP
  - containerPort: 8082
    hostPort: 8082
    protocol: TCP
  - containerPort: 8088
    hostPort: 8088
    protocol: TCP
EOF
    
    print_success "Kind cluster created"
}

# Setup local registry
setup_local_registry() {
    print_info "Setting up local Docker registry..."
    
    if docker ps -a --format '{{.Names}}' | grep -q "^kind-registry$"; then
        if docker ps --format '{{.Names}}' | grep -q "^kind-registry$"; then
            print_info "Local registry already running"
            return 0
        else
            print_info "Starting existing registry container..."
            docker start kind-registry
            return 0
        fi
    fi
    
    print_info "Creating local registry..."
    docker run -d --restart=always -p 5001:5000 --name kind-registry registry:2
    
    # Connect registry to Kind network
    docker network connect "kind" kind-registry 2>/dev/null || true
    
    print_success "Local registry setup complete"
}

# Deploy using Helm
deploy_with_helm() {
    print_info "Deploying with Helm..."
    
    if [[ ! -d "$HELM_CHART_PATH" ]]; then
        print_error "Helm chart not found at $HELM_CHART_PATH"
        exit 1
    fi
    
    # Check if release already exists
    if helm list -A | grep -q "^${HELM_RELEASE_NAME}"; then
        print_warning "Helm release '$HELM_RELEASE_NAME' already exists"
        read -p "Do you want to upgrade it? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            print_info "Upgrading Helm release..."
            helm upgrade "$HELM_RELEASE_NAME" "$HELM_CHART_PATH" \
                --create-namespace \
                --wait \
                --timeout 10m
            print_success "Helm release upgraded"
        fi
    else
        print_info "Installing Helm release..."
        helm install "$HELM_RELEASE_NAME" "$HELM_CHART_PATH" \
            --create-namespace \
            --wait \
            --timeout 10m
        print_success "Helm release installed"
    fi
}

# Deploy using kubectl
deploy_with_kubectl() {
    print_info "Deploying with kubectl..."
    
    if [[ ! -d "$K8S_MANIFEST_PATH" ]]; then
        print_error "Kubernetes manifests not found at $K8S_MANIFEST_PATH"
        exit 1
    fi
    
    # Create namespaces
    print_info "Creating namespaces..."
    kubectl create namespace "$NAMESPACE_CORE" --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace "$NAMESPACE_APPS" --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace "$NAMESPACE_MONITORING" --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply core services
    print_info "Deploying core services..."
    kubectl apply -f "$K8S_MANIFEST_PATH/core/" -R
    
    # Apply app services
    print_info "Deploying application services..."
    kubectl apply -f "$K8S_MANIFEST_PATH/apps/" -R
    
    print_success "Resources applied"
}

# Wait for pods to be ready
wait_for_pods() {
    print_info "Waiting for pods to be ready..."
    
    local namespaces=("$NAMESPACE_CORE" "$NAMESPACE_APPS")
    
    for ns in "${namespaces[@]}"; do
        print_info "Waiting for pods in namespace: $ns"
        kubectl wait --for=condition=ready pod --all -n "$ns" --timeout=600s || {
            print_warning "Some pods in $ns are not ready yet. Continuing anyway..."
        }
    done
    
    print_success "All pods are ready"
}

# Display access information
display_access_info() {
    echo ""
    echo "========================================"
    echo "  Datalyptica Platform Deployed!"
    echo "========================================"
    echo ""
    
    if [[ "$USE_HELM" == "true" ]]; then
        print_info "Helm Release: $HELM_RELEASE_NAME"
        echo ""
        print_info "To see installation notes:"
        echo "  helm get notes $HELM_RELEASE_NAME"
    fi
    
    echo ""
    print_info "Access Services with Port Forwarding:"
    echo ""
    echo "Core Services:"
    echo "  PostgreSQL:  kubectl port-forward -n $NAMESPACE_CORE svc/postgresql 5432:5432"
    echo "  Redis:       kubectl port-forward -n $NAMESPACE_CORE svc/redis 6379:6379"
    echo "  MinIO:       kubectl port-forward -n $NAMESPACE_CORE svc/minio 9000:9000 9001:9001"
    echo "  Nessie:      kubectl port-forward -n $NAMESPACE_CORE svc/nessie 19120:19120"
    echo ""
    echo "Application Services:"
    echo "  Trino:       kubectl port-forward -n $NAMESPACE_APPS svc/trino-coordinator 8080:8080"
    echo "  Flink:       kubectl port-forward -n $NAMESPACE_APPS svc/flink-jobmanager 8081:8081"
    echo "  Airflow:     kubectl port-forward -n $NAMESPACE_APPS svc/airflow-webserver 8082:8082"
    echo "  Superset:    kubectl port-forward -n $NAMESPACE_APPS svc/superset 8088:8088"
    echo "  Spark:       kubectl port-forward -n $NAMESPACE_APPS svc/spark-master 4040:4040"
    echo ""
    print_info "View Pod Status:"
    echo "  kubectl get pods -n $NAMESPACE_CORE"
    echo "  kubectl get pods -n $NAMESPACE_APPS"
    echo ""
    print_info "View Logs:"
    echo "  kubectl logs -n <namespace> <pod-name>"
    echo ""
    print_info "Get Secrets:"
    echo "  kubectl get secret -n $NAMESPACE_CORE postgresql-credentials -o jsonpath='{.data.postgres-password}' | base64 -d"
    echo "  kubectl get secret -n $NAMESPACE_CORE minio-credentials -o jsonpath='{.data.root-password}' | base64 -d"
    echo ""
}

# Cleanup function
cleanup() {
    print_info "Cleaning up..."
    
    if [[ "$USE_HELM" == "true" ]]; then
        print_info "Uninstalling Helm release..."
        helm uninstall "$HELM_RELEASE_NAME" 2>/dev/null || true
    else
        print_info "Deleting Kubernetes resources..."
        kubectl delete -f "$K8S_MANIFEST_PATH" -R 2>/dev/null || true
    fi
    
    print_info "Deleting namespaces..."
    kubectl delete namespace "$NAMESPACE_CORE" 2>/dev/null || true
    kubectl delete namespace "$NAMESPACE_APPS" 2>/dev/null || true
    kubectl delete namespace "$NAMESPACE_MONITORING" 2>/dev/null || true
    
    print_info "Deleting Kind cluster..."
    kind delete cluster --name "$CLUSTER_NAME" 2>/dev/null || true
    
    print_info "Stopping local registry..."
    docker stop kind-registry 2>/dev/null || true
    docker rm kind-registry 2>/dev/null || true
    
    print_success "Cleanup complete"
}

# Main function
main() {
    echo "========================================"
    echo "  Datalyptica Local K8s Deployment"
    echo "========================================"
    echo ""
    echo "Configuration:"
    echo "  Cluster Name: $CLUSTER_NAME"
    echo "  Use Helm: $USE_HELM"
    echo "  Helm Release: $HELM_RELEASE_NAME"
    echo ""
    
    # Parse arguments
    case "${1:-}" in
        cleanup|clean|destroy)
            cleanup
            exit 0
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS] [COMMAND]"
            echo ""
            echo "Commands:"
            echo "  (default)        Deploy the platform"
            echo "  cleanup          Remove all resources and cluster"
            echo ""
            echo "Options:"
            echo "  --use-helm       Use Helm for deployment (default: true)"
            echo "  --use-kubectl    Use kubectl for deployment"
            echo "  --cluster-name   Set Kind cluster name (default: datalyptica)"
            echo ""
            echo "Environment Variables:"
            echo "  CLUSTER_NAME     Kind cluster name"
            echo "  USE_HELM         Use Helm (true/false)"
            echo "  HELM_RELEASE_NAME Helm release name"
            echo ""
            echo "Examples:"
            echo "  $0                      # Deploy with Helm"
            echo "  $0 --use-kubectl        # Deploy with kubectl"
            echo "  $0 cleanup              # Remove everything"
            exit 0
            ;;
        --use-kubectl)
            USE_HELM="false"
            ;;
        --use-helm)
            USE_HELM="true"
            ;;
        --cluster-name)
            CLUSTER_NAME="$2"
            shift
            ;;
    esac
    
    check_prerequisites
    create_kind_cluster
    setup_local_registry
    
    if [[ "$USE_HELM" == "true" ]]; then
        deploy_with_helm
    else
        deploy_with_kubectl
    fi
    
    wait_for_pods
    display_access_info
    
    print_success "Deployment complete!"
}

# Run main function
main "$@"
