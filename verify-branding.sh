#!/bin/bash
# Branding Verification Script
# Checks for any remaining operational "ShuDL" references

set -e

echo "🔍 Datalyptica Branding Verification"
echo "===================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counter
total_issues=0

echo "1️⃣  Checking Grafana dashboards..."
if grep -ri "shudl" docker/config/monitoring/grafana/dashboards/ 2>/dev/null | grep -v "datalyptica" > /dev/null; then
    echo -e "${RED}❌ Found ShuDL references in Grafana dashboards${NC}"
    grep -ri "shudl" docker/config/monitoring/grafana/dashboards/ | grep -v "datalyptica"
    ((total_issues++))
else
    echo -e "${GREEN}✅ Grafana dashboards clean${NC}"
fi
echo ""

echo "2️⃣  Checking Loki/Alloy configuration..."
if grep -i "shudl" docker/config/monitoring/loki/alloy-config.alloy 2>/dev/null | grep -v "datalyptica" > /dev/null; then
    echo -e "${RED}❌ Found ShuDL references in Alloy config${NC}"
    grep -i "shudl" docker/config/monitoring/loki/alloy-config.alloy | grep -v "datalyptica"
    ((total_issues++))
else
    echo -e "${GREEN}✅ Alloy configuration clean${NC}"
fi
echo ""

echo "3️⃣  Checking Alertmanager templates..."
if grep -i "shudl" docker/config/monitoring/alertmanager/templates/ 2>/dev/null | grep -v "datalyptica" > /dev/null; then
    echo -e "${RED}❌ Found ShuDL references in Alertmanager${NC}"
    grep -i "shudl" docker/config/monitoring/alertmanager/templates/ | grep -v "datalyptica"
    ((total_issues++))
else
    echo -e "${GREEN}✅ Alertmanager templates clean${NC}"
fi
echo ""

echo "4️⃣  Checking service configuration templates..."
config_files=("docker/config/airflow/airflow.cfg.template" "docker/config/superset/superset_config.py.template")
config_clean=true
for file in "${config_files[@]}"; do
    if [ -f "$file" ] && grep -i "shudl" "$file" 2>/dev/null | grep -v "datalyptica" > /dev/null; then
        echo -e "${RED}❌ Found ShuDL references in $file${NC}"
        grep -i "shudl" "$file" | grep -v "datalyptica"
        config_clean=false
        ((total_issues++))
    fi
done
if $config_clean; then
    echo -e "${GREEN}✅ Service configuration templates clean${NC}"
fi
echo ""

echo "5️⃣  Checking Docker images..."
if grep -i "# ShuDL" deploy/docker/postgresql/Dockerfile 2>/dev/null > /dev/null; then
    echo -e "${RED}❌ Found ShuDL comment in PostgreSQL Dockerfile${NC}"
    grep -i "# ShuDL" deploy/docker/postgresql/Dockerfile
    ((total_issues++))
else
    echo -e "${GREEN}✅ Docker images clean${NC}"
fi
echo ""

echo "6️⃣  Checking version file..."
if grep -i "SHUDL_VERSION" docker/VERSION 2>/dev/null > /dev/null; then
    echo -e "${RED}❌ Found SHUDL_VERSION in version file${NC}"
    grep -i "SHUDL_VERSION" docker/VERSION
    ((total_issues++))
else
    echo -e "${GREEN}✅ Version file clean${NC}"
fi
echo ""

echo "===================================="
echo "📊 Verification Summary"
echo "===================================="
if [ $total_issues -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed! No operational ShuDL references found.${NC}"
    echo ""
    echo "🎉 The platform is fully rebranded as Datalyptica!"
    exit 0
else
    echo -e "${RED}❌ Found $total_issues issue(s)${NC}"
    echo ""
    echo "⚠️  Please review and fix the issues above."
    exit 1
fi

