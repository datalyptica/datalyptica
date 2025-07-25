#!/bin/bash

# ShuDL Monitoring Stack Demo
# Demonstrates Phase 1A.2: Prometheus + Grafana Integration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Demo header
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          🚀 ShuDL Monitoring Stack Demo                     ║${NC}"
echo -e "${CYAN}║         Phase 1A.2: Prometheus + Grafana Integration        ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo

# Build tools
echo -e "${YELLOW}📦 Building ShuDL tools...${NC}"
go build -o bin/shudlctl ./cmd/shudlctl
go build -o bin/installer ./cmd/installer
echo -e "${GREEN}✅ Tools built successfully${NC}"
echo

# Demo 1: Enhanced Service List
echo -e "${BLUE}═══ Demo 1: Enhanced Service Catalog ═══${NC}"
echo -e "${PURPLE}Command: ./bin/shudlctl deploy --help${NC}"
echo
./bin/shudlctl deploy --help | head -20
echo

# Demo 2: Configuration Files Overview
echo -e "${BLUE}═══ Demo 2: Monitoring Configuration Files ═══${NC}"
echo -e "${GREEN}📁 Created monitoring configurations:${NC}"
ls -la configs/monitoring/
echo
echo -e "${GREEN}📋 Prometheus Configuration:${NC}"
head -20 configs/monitoring/prometheus/prometheus.yml
echo

# Demo 3: Grafana Setup
echo -e "${BLUE}═══ Demo 3: Grafana Configuration ═══${NC}"
echo -e "${GREEN}📊 Grafana Datasources:${NC}"
cat configs/monitoring/grafana/provisioning/datasources/prometheus.yml
echo
echo -e "${GREEN}📈 Dashboard Provisioning:${NC}"
cat configs/monitoring/grafana/provisioning/dashboards/dashboards.yml
echo

# Demo 4: Available Services
echo -e "${BLUE}═══ Demo 4: Available Services (with Monitoring) ═══${NC}"
cat << 'EOF'
🏗️  ShuDL Service Categories:

📊 Infrastructure:
  • postgresql   - Metadata storage
  • minio       - Object storage (S3-compatible)  
  • nessie      - Data catalog with versioning

🚀 Compute:
  • trino       - Distributed SQL engine
  • spark       - Unified analytics engine

📈 Monitoring (NEW!):
  • prometheus  - Metrics collection
  • grafana     - Visualization dashboards

🎯 Deployment Examples:
  shudlctl deploy                              # Deploy all services
  shudlctl deploy --services prometheus,grafana  # Monitoring only
  shudlctl deploy --services postgresql,minio,nessie,prometheus,grafana  # Core + Monitoring
EOF
echo

# Demo 5: Service Configuration Details
echo -e "${BLUE}═══ Demo 5: Service Configuration Details ═══${NC}"
echo -e "${GREEN}🔧 Prometheus Configuration:${NC}"
echo "  • Port: 9090"
echo "  • Retention: 15 days"
echo "  • Scrape interval: 15s"
echo "  • Targets: All ShuDL services"
echo
echo -e "${GREEN}🔧 Grafana Configuration:${NC}"
echo "  • Port: 3000"
echo "  • Default credentials: admin/[generated]"
echo "  • Pre-configured Prometheus datasource"
echo "  • ShuDL overview dashboard included"
echo

# Demo 6: Service Endpoints
echo -e "${BLUE}═══ Demo 6: Service Endpoints ═══${NC}"
cat << 'EOF'
🌐 Access Points After Deployment:

📊 Core Services:
  • Trino Web UI      : http://localhost:8080
  • Spark Master UI   : http://localhost:4040  
  • MinIO Console     : http://localhost:9001
  • Nessie API        : http://localhost:19120

📈 Monitoring (NEW!):
  • Prometheus UI     : http://localhost:9090
  • Grafana Dashboard : http://localhost:3000

🔧 Management:
  • ShuDL Installer   : http://localhost:8080
  • CLI Tool          : ./bin/shudlctl
EOF
echo

# Demo 7: CLI Integration
echo -e "${BLUE}═══ Demo 7: CLI Integration Test ═══${NC}"
echo -e "${PURPLE}Testing shudlctl version:${NC}"
./bin/shudlctl version
echo

echo -e "${PURPLE}Testing service status (no server expected):${NC}"
./bin/shudlctl status --server http://localhost:9999 2>&1 || true
echo

# Demo 8: Deployment Workflow
echo -e "${BLUE}═══ Demo 8: Complete Deployment Workflow ═══${NC}"
cat << 'EOF'
🚀 Recommended Deployment Sequence:

1. Infrastructure First:
   shudlctl deploy --services postgresql,minio

2. Data Catalog:  
   shudlctl deploy --services nessie

3. Compute Engines:
   shudlctl deploy --services trino,spark

4. Monitoring Stack:
   shudlctl deploy --services prometheus,grafana

5. Verify Everything:
   shudlctl status

🎯 Or deploy everything at once:
   shudlctl deploy  # Deploys all services including monitoring
EOF
echo

# Demo 9: Benefits Summary
echo -e "${BLUE}═══ Demo 9: Monitoring Benefits ═══${NC}"
echo -e "${GREEN}✅ Complete Observability Stack${NC}"
echo -e "${GREEN}✅ Real-time metrics collection${NC}"
echo -e "${GREEN}✅ Visual dashboards for all services${NC}"
echo -e "${GREEN}✅ Automated service discovery${NC}"
echo -e "${GREEN}✅ Pre-configured ShuDL dashboards${NC}"
echo -e "${GREEN}✅ Industry-standard monitoring tools${NC}"
echo -e "${GREEN}✅ Production-ready configuration${NC}"
echo -e "${GREEN}✅ Easy integration with existing services${NC}"
echo

# Demo 10: What's Next
echo -e "${BLUE}═══ Demo 10: Phase 1A Completion Status ═══${NC}"
echo -e "${GREEN}✅ Phase 1A.1: shudlctl CLI Tool - COMPLETE${NC}"
echo -e "${GREEN}✅ Phase 1A.2: Monitoring Stack - COMPLETE${NC}"
echo
echo -e "${YELLOW}🎯 Phase 1A Summary:${NC}"
echo -e "  • Professional CLI tool (like stackablectl)"
echo -e "  • Comprehensive monitoring with Prometheus + Grafana"
echo -e "  • Enhanced service management"
echo -e "  • Production-ready observability"
echo

# Final summary
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                🎉 Phase 1A Complete!                        ║${NC}"
echo -e "${CYAN}║                                                              ║${NC}"
echo -e "${CYAN}║  ShuDL now includes enterprise-grade monitoring with        ║${NC}"
echo -e "${CYAN}║  Prometheus and Grafana, plus a professional CLI tool.      ║${NC}"
echo -e "${CYAN}║  This completes the foundation enhancement phase!           ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo

echo -e "${GREEN}🚀 Ready for Phase 1B: Enhanced Web UI Development${NC}"
echo -e "${GREEN}🎯 Next: Transform web installer into Data Platform Configurator${NC}" 