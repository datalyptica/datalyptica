/**
 * Dependency Graph Component
 * Visual representation of service dependencies
 */

export class DependencyGraph {
    constructor(container) {
        this.container = container;
        this.services = [];
        this.selectedServices = [];
        this.showAnimations = true;
        this.layout = 'hierarchical'; // hierarchical, circular, force
        
        this.nodePositions = new Map();
        this.edges = [];
    }
    
    setServices(services, selectedServices = []) {
        this.services = services;
        this.selectedServices = selectedServices;
        this.calculateLayout();
        this.render();
    }
    
    render() {
        this.container.innerHTML = `
            <div class="dependency-graph">
                <div class="dependency-graph-header">
                    <h3>
                        <i class="fas fa-project-diagram"></i>
                        Service Dependencies
                    </h3>
                    <div class="graph-controls">
                        <button class="graph-control-btn ${this.layout === 'hierarchical' ? 'active' : ''}" 
                                data-layout="hierarchical">
                            <i class="fas fa-sitemap"></i> Hierarchical
                        </button>
                        <button class="graph-control-btn ${this.layout === 'circular' ? 'active' : ''}" 
                                data-layout="circular">
                            <i class="fas fa-circle-notch"></i> Circular
                        </button>
                        <button class="graph-control-btn ${this.showAnimations ? 'active' : ''}" 
                                data-action="toggle-animation">
                            <i class="fas fa-play"></i> Animate
                        </button>
                    </div>
                </div>
                
                <div class="graph-container" id="graph-container">
                    ${this.renderNodes()}
                    ${this.renderEdges()}
                </div>
                
                <div class="dependency-legend">
                    <div class="legend-item">
                        <div class="legend-color infrastructure"></div>
                        <span>Infrastructure</span>
                    </div>
                    <div class="legend-item">
                        <div class="legend-color compute"></div>
                        <span>Compute</span>
                    </div>
                    <div class="legend-item">
                        <div class="legend-color monitoring"></div>
                        <span>Monitoring</span>
                    </div>
                    <div class="legend-item">
                        <div class="legend-color selected"></div>
                        <span>Selected</span>
                    </div>
                </div>
            </div>
        `;
        
        this.bindEvents();
    }
    
    calculateLayout() {
        const containerRect = { width: 800, height: 300 };
        
        switch (this.layout) {
            case 'hierarchical':
                this.calculateHierarchicalLayout(containerRect);
                break;
            case 'circular':
                this.calculateCircularLayout(containerRect);
                break;
            default:
                this.calculateHierarchicalLayout(containerRect);
        }
        
        this.calculateEdges();
    }
    
    calculateHierarchicalLayout(containerRect) {
        // Group services by category and dependency level
        const levels = new Map();
        const processedServices = new Set();
        
        // Level 0: Services with no dependencies
        let currentLevel = 0;
        let servicesToProcess = [...this.services];
        
        while (servicesToProcess.length > 0 && currentLevel < 10) {
            const currentLevelServices = servicesToProcess.filter(service => {
                if (processedServices.has(service.name)) return false;
                
                if (!service.dependencies || service.dependencies.length === 0) {
                    return true;
                }
                
                return service.dependencies.every(dep => processedServices.has(dep));
            });
            
            if (currentLevelServices.length === 0) {
                // Handle circular dependencies by taking services with minimum unmet dependencies
                const remaining = servicesToProcess.filter(s => !processedServices.has(s.name));
                if (remaining.length > 0) {
                    currentLevelServices.push(remaining[0]);
                }
            }
            
            levels.set(currentLevel, currentLevelServices);
            currentLevelServices.forEach(service => processedServices.add(service.name));
            servicesToProcess = servicesToProcess.filter(s => !processedServices.has(s.name));
            currentLevel++;
        }
        
        // Position nodes
        const levelHeight = containerRect.height / (levels.size || 1);
        
        levels.forEach((services, level) => {
            const serviceWidth = containerRect.width / (services.length + 1);
            
            services.forEach((service, index) => {
                const x = serviceWidth * (index + 1) - 50; // Offset for node width
                const y = levelHeight * level + 30;
                
                this.nodePositions.set(service.name, { x, y });
            });
        });
    }
    
    calculateCircularLayout(containerRect) {
        const centerX = containerRect.width / 2;
        const centerY = containerRect.height / 2;
        const radius = Math.min(centerX, centerY) - 60;
        
        this.services.forEach((service, index) => {
            const angle = (2 * Math.PI * index) / this.services.length;
            const x = centerX + radius * Math.cos(angle) - 50;
            const y = centerY + radius * Math.sin(angle) - 15;
            
            this.nodePositions.set(service.name, { x, y });
        });
    }
    
    calculateEdges() {
        this.edges = [];
        
        this.services.forEach(service => {
            if (service.dependencies) {
                service.dependencies.forEach(dependency => {
                    const fromPos = this.nodePositions.get(dependency);
                    const toPos = this.nodePositions.get(service.name);
                    
                    if (fromPos && toPos) {
                        this.edges.push({
                            from: dependency,
                            to: service.name,
                            fromPos,
                            toPos
                        });
                    }
                });
            }
        });
    }
    
    renderNodes() {
        return this.services.map(service => {
            const position = this.nodePositions.get(service.name);
            if (!position) return '';
            
            const isSelected = this.selectedServices.includes(service.name);
            const categoryClass = service.category || 'infrastructure';
            
            return `
                <div class="graph-node ${categoryClass} ${isSelected ? 'selected' : ''}" 
                     style="left: ${position.x}px; top: ${position.y}px;"
                     data-service="${service.name}"
                     title="${service.description || service.name}">
                    ${service.displayName || service.name}
                </div>
            `;
        }).join('');
    }
    
    renderEdges() {
        return this.edges.map((edge, index) => {
            const deltaX = edge.toPos.x - edge.fromPos.x;
            const deltaY = edge.toPos.y - edge.fromPos.y;
            const distance = Math.sqrt(deltaX * deltaX + deltaY * deltaY);
            const angle = Math.atan2(deltaY, deltaX) * 180 / Math.PI;
            
            // Position the edge in the middle of the connection
            const centerX = edge.fromPos.x + deltaX / 2 + 50; // Offset for node center
            const centerY = edge.fromPos.y + deltaY / 2 + 15;
            
            const isActive = this.selectedServices.includes(edge.from) && 
                           this.selectedServices.includes(edge.to);
            
            return `
                <div class="graph-edge horizontal ${isActive ? 'active' : ''} ${this.showAnimations ? 'animated' : ''}"
                     style="
                         left: ${centerX - distance/2}px; 
                         top: ${centerY}px; 
                         width: ${distance}px;
                         transform: rotate(${angle}deg);
                         transform-origin: center;
                     "
                     data-edge="${edge.from}-${edge.to}">
                </div>
            `;
        }).join('');
    }
    
    bindEvents() {
        this.container.addEventListener('click', (e) => {
            if (e.target.matches('.graph-control-btn')) {
                const layout = e.target.dataset.layout;
                const action = e.target.dataset.action;
                
                if (layout) {
                    this.layout = layout;
                    this.calculateLayout();
                    this.render();
                } else if (action === 'toggle-animation') {
                    this.showAnimations = !this.showAnimations;
                    this.render();
                }
            }
        });
        
        // Node hover effects
        this.container.addEventListener('mouseenter', (e) => {
            if (e.target.matches('.graph-node')) {
                const serviceName = e.target.dataset.service;
                this.highlightConnections(serviceName);
            }
        }, true);
        
        this.container.addEventListener('mouseleave', (e) => {
            if (e.target.matches('.graph-node')) {
                this.clearHighlights();
            }
        }, true);
    }
    
    highlightConnections(serviceName) {
        // Highlight all edges connected to this service
        const relatedEdges = this.edges.filter(edge => 
            edge.from === serviceName || edge.to === serviceName
        );
        
        relatedEdges.forEach(edge => {
            const edgeElement = this.container.querySelector(`[data-edge="${edge.from}-${edge.to}"]`);
            if (edgeElement) {
                edgeElement.style.backgroundColor = 'var(--color-primary)';
                edgeElement.style.height = '4px';
                edgeElement.style.width = '4px';
            }
        });
    }
    
    clearHighlights() {
        const edges = this.container.querySelectorAll('.graph-edge');
        edges.forEach(edge => {
            edge.style.backgroundColor = '';
            edge.style.height = '';
            edge.style.width = '';
        });
    }
    
    exportGraph() {
        return {
            services: this.services,
            selectedServices: this.selectedServices,
            layout: this.layout,
            nodePositions: Object.fromEntries(this.nodePositions),
            edges: this.edges
        };
    }
} 