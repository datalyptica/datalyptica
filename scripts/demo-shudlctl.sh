#!/bin/bash

# ShuDL CLI (shudlctl) Demo Script
# Demonstrates the new Stackable-inspired CLI tool

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
echo -e "${CYAN}║               🚀 ShuDL CLI (shudlctl) Demo                   ║${NC}"
echo -e "${CYAN}║          Stackable-Inspired Data Platform CLI               ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo

# Build the CLI if needed
if [ ! -f "bin/shudlctl" ]; then
    echo -e "${YELLOW}📦 Building shudlctl CLI tool...${NC}"
    go build -o bin/shudlctl ./cmd/shudlctl
    echo -e "${GREEN}✅ CLI tool built successfully${NC}"
    echo
fi

# Demo 1: Help and Commands
echo -e "${BLUE}═══ Demo 1: Available Commands ═══${NC}"
echo -e "${PURPLE}Command: ./bin/shudlctl --help${NC}"
echo
./bin/shudlctl --help
echo

# Demo 2: Version Information
echo -e "${BLUE}═══ Demo 2: Version Information ═══${NC}"
echo -e "${PURPLE}Command: ./bin/shudlctl version${NC}"
echo
./bin/shudlctl version
echo

# Demo 3: Command Help
echo -e "${BLUE}═══ Demo 3: Command-Specific Help ═══${NC}"
echo -e "${PURPLE}Command: ./bin/shudlctl deploy --help${NC}"
echo
./bin/shudlctl deploy --help
echo

# Demo 4: Status Command (will show connection behavior)
echo -e "${BLUE}═══ Demo 4: Status Command (No Server) ═══${NC}"
echo -e "${PURPLE}Command: ./bin/shudlctl status --server http://localhost:9999${NC}"
echo -e "${YELLOW}Expected: Connection error (demonstrates error handling)${NC}"
echo
./bin/shudlctl status --server http://localhost:9999 2>&1 || true
echo

# Demo 5: Deploy Command Help
echo -e "${BLUE}═══ Demo 5: Deploy Command Options ═══${NC}"
echo -e "${PURPLE}Command: ./bin/shudlctl deploy --help${NC}"
echo
./bin/shudlctl deploy --help
echo

# Demo 6: Configuration Options
echo -e "${BLUE}═══ Demo 6: Configuration Management ═══${NC}"
echo -e "${YELLOW}📋 Configuration Sources (in order of precedence):${NC}"
echo -e "  1. Command-line flags"
echo -e "  2. Environment variables (SHUDL_*)"
echo -e "  3. Config file (~/.shudlctl.yaml)"
echo -e "  4. Default values"
echo
echo -e "${PURPLE}Example: SHUDL_SERVER=http://localhost:8090 ./bin/shudlctl version${NC}"
echo
SHUDL_SERVER=http://localhost:8090 ./bin/shudlctl version
echo

# Demo 7: CLI Features Summary
echo -e "${BLUE}═══ Demo 7: Key Features ═══${NC}"
echo -e "${GREEN}✅ Professional CLI with Cobra framework${NC}"
echo -e "${GREEN}✅ Colored output and user-friendly messages${NC}"
echo -e "${GREEN}✅ Comprehensive help and documentation${NC}"
echo -e "${GREEN}✅ Flexible configuration management${NC}"
echo -e "${GREEN}✅ Error handling and status reporting${NC}"
echo -e "${GREEN}✅ REST API integration with ShuDL server${NC}"
echo -e "${GREEN}✅ Table formatting for service status${NC}"
echo -e "${GREEN}✅ Interactive deployment confirmations${NC}"
echo

# Demo 8: Available Commands Summary
echo -e "${BLUE}═══ Demo 8: Command Reference ═══${NC}"
cat << 'EOF'
📋 Core Commands:
  • shudlctl version              - Show version information
  • shudlctl status               - Check service status
  • shudlctl deploy               - Deploy services
  • shudlctl deploy --services X  - Deploy specific services
  • shudlctl status --watch       - Watch status updates
  • shudlctl deploy --yes         - Skip confirmation

🔧 Configuration:
  • --server URL                  - Set ShuDL server URL
  • --config FILE                 - Use config file
  • --verbose                     - Enable verbose output

🌟 Environment Variables:
  • SHUDL_SERVER                  - Server URL
  • SHUDL_VERBOSE                 - Enable verbose output
EOF
echo

# Demo 9: Integration with ShuDL Server
echo -e "${BLUE}═══ Demo 9: Server Integration ═══${NC}"
echo -e "${YELLOW}💡 To test with running ShuDL server:${NC}"
echo
cat << 'EOF'
# Start ShuDL server on port 8080
./bin/installer &

# Test CLI commands
./bin/shudlctl status                    # Check all services
./bin/shudlctl deploy                    # Deploy services
./bin/shudlctl status --watch            # Monitor deployment

# Use custom server
./bin/shudlctl status --server http://localhost:8081
EOF
echo

# Final summary
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    🎉 Demo Complete!                        ║${NC}"
echo -e "${CYAN}║                                                              ║${NC}"
echo -e "${CYAN}║  ShuDL now has a professional CLI tool inspired by          ║${NC}"
echo -e "${CYAN}║  Stackable's stackablectl. This significantly improves      ║${NC}"
echo -e "${CYAN}║  the developer experience and positions ShuDL as a          ║${NC}"
echo -e "${CYAN}║  modern, enterprise-grade Data Lakehouse platform.         ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo

echo -e "${GREEN}🚀 Next Phase: Add Prometheus + Grafana monitoring stack${NC}"
echo -e "${GREEN}🎯 Goal: Complete Phase 1A of the Stackable-inspired roadmap${NC}" 