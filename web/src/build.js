#!/usr/bin/env node

/**
 * ShuDL Frontend Build Script
 * Simple build system for CSS and JavaScript compilation
 */

const fs = require('fs');
const path = require('path');

class AssetBuilder {
    constructor() {
        this.srcDir = path.join(__dirname, 'assets');
        this.distDir = path.join(__dirname, '..', 'static');
    }

    /**
     * Build all assets
     */
    async build() {
        console.log('🚀 Building ShuDL Frontend Assets...\n');
        
        try {
            await this.buildCSS();
            await this.buildJS();
            
            console.log('\n✅ Build completed successfully!');
        } catch (error) {
            console.error('\n❌ Build failed:', error.message);
            process.exit(1);
        }
    }

    /**
     * Build CSS by processing @import statements
     */
    async buildCSS() {
        console.log('📦 Building CSS...');
        
        const mainCSSPath = path.join(this.srcDir, 'css', 'installer.css');
        const outputPath = path.join(this.distDir, 'css', 'installer.css');
        
        if (!fs.existsSync(mainCSSPath)) {
            throw new Error(`Main CSS file not found: ${mainCSSPath}`);
        }

        const processedCSS = await this.processCSS(mainCSSPath);
        
        // Ensure output directory exists
        const outputDir = path.dirname(outputPath);
        if (!fs.existsSync(outputDir)) {
            fs.mkdirSync(outputDir, { recursive: true });
        }
        
        fs.writeFileSync(outputPath, processedCSS);
        console.log(`   ✓ CSS compiled: ${outputPath}`);
    }

    /**
     * Process CSS file and resolve @import statements
     */
    async processCSS(filePath) {
        const content = fs.readFileSync(filePath, 'utf-8');
        const baseDir = path.dirname(filePath);
        
        return content.replace(/@import\s+['"]([^'"]+)['"];?/g, (match, importPath) => {
            const fullPath = path.resolve(baseDir, importPath);
            
            if (fs.existsSync(fullPath)) {
                const importedContent = fs.readFileSync(fullPath, 'utf-8');
                return `/* === ${importPath} === */\n${importedContent}\n`;
            } else {
                console.warn(`   ⚠️  CSS import not found: ${importPath}`);
                return `/* MISSING: ${importPath} */`;
            }
        });
    }

    /**
     * Build JavaScript by bundling ES6 modules
     */
    async buildJS() {
        console.log('📦 Building JavaScript...');
        
        const mainJSPath = path.join(this.srcDir, 'js', 'app.js');
        const outputPath = path.join(this.distDir, 'js', 'installer.js');
        
        if (!fs.existsSync(mainJSPath)) {
            throw new Error(`Main JS file not found: ${mainJSPath}`);
        }

        const bundledJS = await this.bundleJS(mainJSPath);
        
        // Ensure output directory exists
        const outputDir = path.dirname(outputPath);
        if (!fs.existsSync(outputDir)) {
            fs.mkdirSync(outputDir, { recursive: true });
        }
        
        fs.writeFileSync(outputPath, bundledJS);
        console.log(`   ✓ JavaScript bundled: ${outputPath}`);
    }

    /**
     * Simple JavaScript bundler (resolves ES6 imports)
     */
    async bundleJS(entryPath) {
        const processed = new Set();
        let bundleContent = '';

        const processFile = (filePath) => {
            const normalizedPath = path.resolve(filePath);
            
            if (processed.has(normalizedPath)) {
                return;
            }
            
            processed.add(normalizedPath);
            
            if (!fs.existsSync(normalizedPath)) {
                console.warn(`   ⚠️  JS import not found: ${filePath}`);
                return;
            }
            
            const content = fs.readFileSync(normalizedPath, 'utf-8');
            const baseDir = path.dirname(normalizedPath);
            
            // Process imports first
            const importMatches = content.match(/import\s+.*\s+from\s+['"]([^'"]+)['"];?/g) || [];
            
            for (const importStatement of importMatches) {
                const match = importStatement.match(/from\s+['"]([^'"]+)['"];?/);
                if (match) {
                    let importPath = match[1];
                    
                    // Resolve relative imports
                    if (importPath.startsWith('./') || importPath.startsWith('../')) {
                        const resolvedPath = path.resolve(baseDir, importPath);
                        const jsPath = resolvedPath.endsWith('.js') ? resolvedPath : `${resolvedPath}.js`;
                        processFile(jsPath);
                    }
                }
            }
            
            // Remove imports and exports, add to bundle
            const cleanContent = content
                .replace(/import\s+.*\s+from\s+['"][^'"]+['"];?\s*\n?/g, '')
                .replace(/export\s+\{[^}]*\};\s*\n?/g, '')
                .replace(/export\s+(const|class|function)\s+/g, '$1 ')
                .replace(/export\s+/g, '');
            
            bundleContent += `\n/* === ${path.relative(this.srcDir, normalizedPath)} === */\n`;
            bundleContent += cleanContent + '\n';
        };

        processFile(entryPath);
        
        return `/**
 * ShuDL Installer - Bundled JavaScript
 * Built from modular ES6 source files
 * Generated: ${new Date().toISOString()}
 */

${bundleContent}`;
    }

    /**
     * Watch for file changes and rebuild
     */
    watch() {
        console.log('👀 Watching for changes...\n');
        
        const watchDir = (dir) => {
            fs.watch(dir, { recursive: true }, (eventType, filename) => {
                if (filename && (filename.endsWith('.css') || filename.endsWith('.js'))) {
                    console.log(`📝 File changed: ${filename}`);
                    this.build().catch(console.error);
                }
            });
        };

        watchDir(this.srcDir);
    }
}

// CLI handling
const builder = new AssetBuilder();

const command = process.argv[2];

switch (command) {
    case 'build':
        builder.build();
        break;
    case 'watch':
        builder.build().then(() => builder.watch());
        break;
    default:
        console.log(`
Usage: node build.js [command]

Commands:
  build    Build assets once
  watch    Build assets and watch for changes

Examples:
  node build.js build
  node build.js watch
        `);
        break;
} 