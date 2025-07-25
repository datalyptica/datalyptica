#!/bin/bash

# ShuDL Frontend Build Script (Shell version)
# Simple build system for CSS and JavaScript compilation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directories
SRC_DIR="$(dirname "$0")/assets"
DIST_DIR="$(dirname "$0")/../static"

echo -e "${BLUE}🚀 Building ShuDL Frontend Assets...${NC}\n"

# Build CSS
echo -e "${BLUE}📦 Building CSS...${NC}"

# Simple CSS concatenation (without @import processing for now)
CSS_OUTPUT="$DIST_DIR/css/installer.css"
mkdir -p "$(dirname "$CSS_OUTPUT")"

echo "/* ShuDL Installer CSS - Compiled from modular sources */" > "$CSS_OUTPUT"
echo "/* Generated: $(date) */" >> "$CSS_OUTPUT"
echo "" >> "$CSS_OUTPUT"

# Concatenate CSS files in order
cat "$SRC_DIR/css/base/variables.css" >> "$CSS_OUTPUT" 2>/dev/null || echo "/* base/variables.css not found */" >> "$CSS_OUTPUT"
cat "$SRC_DIR/css/base/reset.css" >> "$CSS_OUTPUT" 2>/dev/null || echo "/* base/reset.css not found */" >> "$CSS_OUTPUT"
cat "$SRC_DIR/css/components/header.css" >> "$CSS_OUTPUT" 2>/dev/null || echo "/* components/header.css not found */" >> "$CSS_OUTPUT"
cat "$SRC_DIR/css/components/progress.css" >> "$CSS_OUTPUT" 2>/dev/null || echo "/* components/progress.css not found */" >> "$CSS_OUTPUT"
cat "$SRC_DIR/css/components/buttons.css" >> "$CSS_OUTPUT" 2>/dev/null || echo "/* components/buttons.css not found */" >> "$CSS_OUTPUT"
cat "$SRC_DIR/css/components/forms.css" >> "$CSS_OUTPUT" 2>/dev/null || echo "/* components/forms.css not found */" >> "$CSS_OUTPUT"
cat "$SRC_DIR/css/components/notifications.css" >> "$CSS_OUTPUT" 2>/dev/null || echo "/* components/notifications.css not found */" >> "$CSS_OUTPUT"
cat "$SRC_DIR/css/pages/welcome.css" >> "$CSS_OUTPUT" 2>/dev/null || echo "/* pages/welcome.css not found */" >> "$CSS_OUTPUT"
cat "$SRC_DIR/css/base/responsive.css" >> "$CSS_OUTPUT" 2>/dev/null || echo "/* base/responsive.css not found */" >> "$CSS_OUTPUT"

echo -e "   ${GREEN}✓ CSS compiled: $CSS_OUTPUT${NC}"

# Build JavaScript
echo -e "${BLUE}📦 Building JavaScript...${NC}"

JS_OUTPUT="$DIST_DIR/js/installer.js"
mkdir -p "$(dirname "$JS_OUTPUT")"

echo "/**" > "$JS_OUTPUT"
echo " * ShuDL Installer - Compiled JavaScript" >> "$JS_OUTPUT"
echo " * Built from modular ES6 source files" >> "$JS_OUTPUT"
echo " * Generated: $(date)" >> "$JS_OUTPUT"
echo " */" >> "$JS_OUTPUT"
echo "" >> "$JS_OUTPUT"

# Simple concatenation (ES6 modules will be converted to standard JS)
if [ -f "$SRC_DIR/js/modules/api.js" ]; then
    echo "/* === API Module === */" >> "$JS_OUTPUT"
    # Remove ES6 imports/exports for simple concatenation
    sed -e 's/import.*from.*;//g' -e 's/export.*{.*};//g' -e 's/export //' "$SRC_DIR/js/modules/api.js" >> "$JS_OUTPUT"
    echo "" >> "$JS_OUTPUT"
fi

if [ -f "$SRC_DIR/js/modules/validation.js" ]; then
    echo "/* === Validation Module === */" >> "$JS_OUTPUT"
    sed -e 's/import.*from.*;//g' -e 's/export.*{.*};//g' -e 's/export //' "$SRC_DIR/js/modules/validation.js" >> "$JS_OUTPUT"
    echo "" >> "$JS_OUTPUT"
fi

if [ -f "$SRC_DIR/js/components/step-controller.js" ]; then
    echo "/* === Step Controller Component === */" >> "$JS_OUTPUT"
    sed -e 's/import.*from.*;//g' -e 's/export.*{.*};//g' -e 's/export //' "$SRC_DIR/js/components/step-controller.js" >> "$JS_OUTPUT"
    echo "" >> "$JS_OUTPUT"
fi

if [ -f "$SRC_DIR/js/components/notifications.js" ]; then
    echo "/* === Notifications Component === */" >> "$JS_OUTPUT"
    sed -e 's/import.*from.*;//g' -e 's/export.*{.*};//g' -e 's/export //' "$SRC_DIR/js/components/notifications.js" >> "$JS_OUTPUT"
    echo "" >> "$JS_OUTPUT"
fi

if [ -f "$SRC_DIR/js/app.js" ]; then
    echo "/* === Main Application === */" >> "$JS_OUTPUT"
    sed -e 's/import.*from.*;//g' -e 's/export.*{.*};//g' -e 's/export //' "$SRC_DIR/js/app.js" >> "$JS_OUTPUT"
fi

echo -e "   ${GREEN}✓ JavaScript bundled: $JS_OUTPUT${NC}"

# Show file sizes
echo ""
echo -e "${BLUE}📊 Build Summary:${NC}"
if [ -f "$CSS_OUTPUT" ]; then
    CSS_SIZE=$(wc -c < "$CSS_OUTPUT")
    echo -e "   CSS: ${GREEN}$CSS_SIZE bytes${NC}"
fi

if [ -f "$JS_OUTPUT" ]; then
    JS_SIZE=$(wc -c < "$JS_OUTPUT")
    echo -e "   JavaScript: ${GREEN}$JS_SIZE bytes${NC}"
fi

echo ""
echo -e "${GREEN}✅ Build completed successfully!${NC}" 