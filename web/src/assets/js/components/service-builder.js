/**
 * Service Builder Component - Phase 1B Visual Configurator
 * Handles drag-and-drop service selection, dependency mapping, and visual configuration
 */

import { apiClient } from '../modules/api.js';
import { notificationManager } from './notifications.js';

export class ServiceBuilder {
    constructor() {
        this.selectedServices = new Map();
        this.serviceDefinitions = new Map();
        this.dependencies = new Map();
        this.canvas = null;
        this.dependencySvg = null;
        this.validationTimer = null;
        this.validationStatus = 'pending';
        
        this.init();
    }

    async init() {
        try {
            await this.loadServiceDefinitions();
            this.setupDOM();
            this.bindEvents();
            this.renderServicePalette();
            this.initializeDragAndDrop();
        } catch (error) {
            console.error('Failed to initialize service builder:', error);
            notificationManager.error('Failed to initialize service builder');
        }
    }

    async loadServiceDefinitions() {
        try {
            const response = await apiClient.getServices();
            if (response.success && response.data) {
                response.data.forEach(service => {
                    this.serviceDefinitions.set(service.name, service);
                    if (service.dependencies) {
                        this.dependencies.set(service.name, service.dependencies);
                    }
                });
            }
        } catch (error) {
            console.error('Failed to load service definitions:', error);
            throw error;
        }
    }

    setupDOM() {
        this.canvas = document.getElementById('service-canvas');
        this.dependencySvg = document.getElementById('dependency-svg');
        this.validationPanel = document.getElementById('validation-panel');
        this.configForms = document.getElementById('config-forms');
        this.validationStatus = document.getElementById('validation-status');
    }

    bindEvents() {
        // Builder controls
        document.getElementById('reset-selection')?.addEventListener('click', () => this.resetSelection());
        document.getElementById('load-preset')?.addEventListener('click', () => this.showLoadPresetModal());
        document.getElementById('save-preset')?.addEventListener('click', () => this.showSavePresetModal());
        
        // Import/Export
        document.getElementById('export-config')?.addEventListener('click', () => this.exportConfiguration());
        document.getElementById('import-config')?.addEventListener('click', () => this.importConfiguration());
        
        // Canvas events
        this.canvas?.addEventListener('dragover', (e) => this.handleCanvasDragOver(e));
        this.canvas?.addEventListener('drop', (e) => this.handleCanvasDrop(e));
        this.canvas?.addEventListener('dragleave', (e) => this.handleCanvasDragLeave(e));
    }

    renderServicePalette() {
        const categories = {
            storage: ['postgresql', 'minio', 'nessie'],
            compute: ['trino', 'spark'],
            monitoring: ['prometheus', 'grafana']
        };

        Object.entries(categories).forEach(([category, services]) => {
            const container = document.getElementById(`${category}-services`);
            if (!container) return;

            container.innerHTML = '';
            services.forEach(serviceName => {
                const service = this.serviceDefinitions.get(serviceName);
                if (service) {
                    const card = this.createServiceCard(service);
                    container.appendChild(card);
                }
            });
        });
    }

    createServiceCard(service) {
        const card = document.createElement('div');
        card.className = 'service-card';
        card.draggable = true;
        card.dataset.serviceName = service.name;
        
        const icon = this.getServiceIcon(service.name);
        const description = service.description || 'No description available';
        
        card.innerHTML = `
            <div class="service-icon">
                <i class="${icon}"></i>
            </div>
            <div class="service-name">${service.display_name || service.name}</div>
            <div class="service-description">${description}</div>
            <div class="service-status"></div>
        `;

        // Drag events
        card.addEventListener('dragstart', (e) => this.handleDragStart(e, service));
        card.addEventListener('dragend', (e) => this.handleDragEnd(e));
        
        return card;
    }

    getServiceIcon(serviceName) {
        const icons = {
            postgresql: 'fas fa-database',
            minio: 'fas fa-cloud',
            nessie: 'fas fa-code-branch',
            trino: 'fas fa-search',
            spark: 'fas fa-bolt',
            prometheus: 'fas fa-chart-line',
            grafana: 'fas fa-chart-bar'
        };
        return icons[serviceName] || 'fas fa-cube';
    }

    handleDragStart(e, service) {
        e.dataTransfer.setData('text/plain', service.name);
        e.dataTransfer.effectAllowed = 'copy';
        e.target.classList.add('dragging');
    }

    handleDragEnd(e) {
        e.target.classList.remove('dragging');
    }

    handleCanvasDragOver(e) {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'copy';
        this.canvas.classList.add('drag-over');
    }

    handleCanvasDragLeave(e) {
        // Only remove drag-over if leaving the canvas entirely
        if (!this.canvas.contains(e.relatedTarget)) {
            this.canvas.classList.remove('drag-over');
        }
    }

    handleCanvasDrop(e) {
        e.preventDefault();
        this.canvas.classList.remove('drag-over');
        
        const serviceName = e.dataTransfer.getData('text/plain');
        const service = this.serviceDefinitions.get(serviceName);
        
        if (service && !this.selectedServices.has(serviceName)) {
            this.addServiceToCanvas(service);
            this.updateDependencyGraph();
            this.triggerValidation();
        }
    }

    addServiceToCanvas(service) {
        // Add to selected services
        this.selectedServices.set(service.name, {
            ...service,
            config: this.getDefaultConfig(service)
        });

        // Update canvas display
        this.renderCanvas();
        
        // Update configuration forms
        this.renderConfigurationForms();
        
        // Update service card state
        this.updateServiceCardState(service.name, 'selected');
        
        notificationManager.success(`Added ${service.display_name || service.name} to your stack`);
    }

    removeServiceFromCanvas(serviceName) {
        this.selectedServices.delete(serviceName);
        this.renderCanvas();
        this.renderConfigurationForms();
        this.updateServiceCardState(serviceName, 'available');
        this.updateDependencyGraph();
        this.triggerValidation();
        
        notificationManager.info(`Removed ${serviceName} from your stack`);
    }

    renderCanvas() {
        if (!this.canvas) return;

        if (this.selectedServices.size === 0) {
            this.canvas.innerHTML = `
                <div class="canvas-placeholder">
                    <i class="fas fa-hand-pointer"></i>
                    <p>Drag services here to build your stack</p>
                </div>
            `;
            return;
        }

        this.canvas.innerHTML = '';
        this.selectedServices.forEach((service, serviceName) => {
            const node = this.createServiceNode(service);
            this.canvas.appendChild(node);
        });
    }

    createServiceNode(service) {
        const node = document.createElement('div');
        node.className = 'service-node';
        node.dataset.serviceName = service.name;
        
        const icon = this.getServiceIcon(service.name);
        
        node.innerHTML = `
            <div class="service-icon">
                <i class="${icon}"></i>
            </div>
            <div class="service-name">${service.display_name || service.name}</div>
            <button class="remove-service" title="Remove service">
                <i class="fas fa-times"></i>
            </button>
        `;

        // Events
        node.addEventListener('click', () => this.selectServiceForConfig(service.name));
        node.querySelector('.remove-service').addEventListener('click', (e) => {
            e.stopPropagation();
            this.removeServiceFromCanvas(service.name);
        });

        return node;
    }

    updateServiceCardState(serviceName, state) {
        const card = document.querySelector(`[data-service-name="${serviceName}"]`);
        if (!card) return;

        card.classList.remove('selected', 'disabled', 'error');
        
        switch (state) {
            case 'selected':
                card.classList.add('selected');
                break;
            case 'disabled':
                card.classList.add('disabled');
                break;
            case 'error':
                card.classList.add('error');
                break;
        }
    }

    updateDependencyGraph() {
        if (!this.dependencySvg) return;

        // Clear existing graph
        this.dependencySvg.innerHTML = `
            <defs>
                <marker id="arrowhead" markerWidth="10" markerHeight="7" 
                        refX="9" refY="3.5" orient="auto">
                    <polygon points="0 0, 10 3.5, 0 7" fill="var(--primary-500)" />
                </marker>
            </defs>
        `;

        if (this.selectedServices.size === 0) return;

        const services = Array.from(this.selectedServices.keys());
        const positions = this.calculateNodePositions(services);
        
        // Draw nodes
        services.forEach((serviceName, index) => {
            const pos = positions[serviceName];
            const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
            circle.setAttribute('cx', pos.x);
            circle.setAttribute('cy', pos.y);
            circle.setAttribute('r', 20);
            circle.classList.add('dependency-node');
            this.dependencySvg.appendChild(circle);
            
            const text = document.createElementNS('http://www.w3.org/2000/svg', 'text');
            text.setAttribute('x', pos.x);
            text.setAttribute('y', pos.y + 5);
            text.classList.add('dependency-label');
            text.textContent = serviceName.substring(0, 8);
            this.dependencySvg.appendChild(text);
        });

        // Draw connections
        services.forEach(serviceName => {
            const deps = this.dependencies.get(serviceName);
            if (!deps) return;

            deps.forEach(dep => {
                if (this.selectedServices.has(dep.service)) {
                    this.drawConnection(
                        positions[serviceName],
                        positions[dep.service],
                        dep.required ? 'required' : 'optional'
                    );
                }
            });
        });
    }

    calculateNodePositions(services) {
        const positions = {};
        const svgRect = this.dependencySvg.getBoundingClientRect();
        const width = svgRect.width || 800;
        const height = 300;
        
        const radius = Math.min(width, height) / 2 - 50;
        const centerX = width / 2;
        const centerY = height / 2;
        
        if (services.length === 1) {
            positions[services[0]] = { x: centerX, y: centerY };
            return positions;
        }
        
        services.forEach((service, index) => {
            const angle = (2 * Math.PI * index) / services.length;
            positions[service] = {
                x: centerX + radius * Math.cos(angle),
                y: centerY + radius * Math.sin(angle)
            };
        });
        
        return positions;
    }

    drawConnection(from, to, type) {
        const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
        line.setAttribute('x1', from.x);
        line.setAttribute('y1', from.y);
        line.setAttribute('x2', to.x);
        line.setAttribute('y2', to.y);
        line.classList.add('dependency-connection', type);
        this.dependencySvg.appendChild(line);
    }

    renderConfigurationForms() {
        if (!this.configForms) return;

        if (this.selectedServices.size === 0) {
            this.configForms.innerHTML = `
                <div class="no-selection">
                    <i class="fas fa-info-circle"></i>
                    <p>Select services to configure their parameters</p>
                </div>
            `;
            return;
        }

        this.configForms.innerHTML = '';
        this.selectedServices.forEach((service, serviceName) => {
            const form = this.createConfigurationForm(service);
            this.configForms.appendChild(form);
        });
    }

    createConfigurationForm(service) {
        const form = document.createElement('div');
        form.className = 'service-config-form';
        form.dataset.serviceName = service.name;
        
        form.innerHTML = `
            <div class="service-config-header">
                <h5><i class="${this.getServiceIcon(service.name)}"></i> ${service.display_name || service.name}</h5>
                <button class="config-toggle" data-target="${service.name}">
                    <i class="fas fa-chevron-up"></i>
                </button>
            </div>
            <div class="service-config-body" id="config-body-${service.name}">
                ${this.renderConfigFields(service)}
            </div>
        `;

        // Toggle functionality
        form.querySelector('.config-toggle').addEventListener('click', (e) => {
            const body = form.querySelector('.service-config-body');
            const icon = e.target.querySelector('i');
            
            body.classList.toggle('collapsed');
            icon.classList.toggle('fa-chevron-up');
            icon.classList.toggle('fa-chevron-down');
        });

        return form;
    }

    renderConfigFields(service) {
        if (!service.config_schema) {
            return '<p class="text-muted">No configuration options available.</p>';
        }

        return service.config_schema.map(field => {
            const value = service.config[field.name] || field.default || '';
            return `
                <div class="form-group">
                    <label for="${service.name}_${field.name}">${field.display_name || field.name}</label>
                    <input type="${field.type || 'text'}" 
                           id="${service.name}_${field.name}"
                           name="${field.name}"
                           class="form-control"
                           value="${value}"
                           placeholder="${field.placeholder || ''}"
                           ${field.required ? 'required' : ''}
                           data-service="${service.name}">
                    ${field.description ? `<div class="form-help">${field.description}</div>` : ''}
                    <div class="validation-indicator"></div>
                </div>
            `;
        }).join('');
    }

    getDefaultConfig(service) {
        const config = {};
        if (service.config_schema) {
            service.config_schema.forEach(field => {
                config[field.name] = field.default || '';
            });
        }
        return config;
    }

    selectServiceForConfig(serviceName) {
        // Highlight selected service
        document.querySelectorAll('.service-node').forEach(node => {
            node.classList.remove('selected');
        });
        
        const selectedNode = document.querySelector(`[data-service-name="${serviceName}"]`);
        if (selectedNode) {
            selectedNode.classList.add('selected');
        }

        // Scroll to configuration form
        const configForm = document.querySelector(`[data-service-name="${serviceName}"]`);
        if (configForm) {
            configForm.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        }
    }

    triggerValidation() {
        // Debounce validation to avoid excessive API calls
        clearTimeout(this.validationTimer);
        this.validationTimer = setTimeout(() => {
            this.validateConfiguration();
        }, 500);
    }

    async validateConfiguration() {
        if (this.selectedServices.size === 0) {
            this.updateValidationStatus('pending', 'No services selected');
            return;
        }

        this.updateValidationStatus('validating', 'Validating configuration...');

        try {
            const config = this.buildConfiguration();
            const response = await apiClient.validateConfiguration(config);
            
            if (response.success && response.data.valid) {
                this.updateValidationStatus('valid', 'Configuration is valid');
                this.renderValidationResults(response.data.results || []);
            } else {
                this.updateValidationStatus('invalid', 'Configuration has issues');
                this.renderValidationResults(response.data.errors || []);
            }
        } catch (error) {
            console.error('Validation failed:', error);
            this.updateValidationStatus('invalid', 'Validation failed');
        }
    }

    updateValidationStatus(status, message) {
        this.validationStatus = status;
        const indicator = document.querySelector('.validation-status .status-indicator');
        if (!indicator) return;

        indicator.className = `status-indicator ${status}`;
        
        const icons = {
            pending: 'fas fa-clock',
            validating: 'fas fa-spinner fa-spin',
            valid: 'fas fa-check-circle',
            invalid: 'fas fa-exclamation-triangle'
        };
        
        indicator.innerHTML = `
            <i class="${icons[status]}"></i>
            ${message}
        `;

        // Enable/disable next button
        const nextButton = document.getElementById('next-to-preview');
        if (nextButton) {
            nextButton.disabled = status !== 'valid';
        }
    }

    renderValidationResults(results) {
        const container = document.getElementById('validation-items');
        if (!container) return;

        if (results.length === 0) {
            container.innerHTML = `
                <div class="validation-item success">
                    <i class="fas fa-check-circle"></i>
                    <span>All services configured correctly</span>
                </div>
            `;
            return;
        }

        container.innerHTML = results.map(result => {
            const type = result.level || 'info';
            const icon = {
                success: 'fas fa-check-circle',
                warning: 'fas fa-exclamation-triangle',
                error: 'fas fa-times-circle',
                info: 'fas fa-info-circle'
            }[type] || 'fas fa-info-circle';

            return `
                <div class="validation-item ${type}">
                    <i class="${icon}"></i>
                    <span>${result.message}</span>
                </div>
            `;
        }).join('');
    }

    buildConfiguration() {
        const config = {
            project_name: 'shudl',
            network_name: 'shunetwork',
            environment: 'development',
            services: {},
            global_config: {}
        };

        this.selectedServices.forEach((service, serviceName) => {
            config.services[serviceName] = {
                enabled: true,
                config: service.config
            };
        });

        return config;
    }

    resetSelection() {
        this.selectedServices.clear();
        this.renderCanvas();
        this.renderConfigurationForms();
        this.updateDependencyGraph();
        this.updateValidationStatus('pending', 'Configuration reset');
        
        // Reset all service cards
        document.querySelectorAll('.service-card').forEach(card => {
            card.classList.remove('selected', 'disabled', 'error');
        });
        
        notificationManager.info('Service selection reset');
    }

    exportConfiguration() {
        const config = this.buildConfiguration();
        const configString = JSON.stringify(config, null, 2);
        
        // Create and download file
        const blob = new Blob([configString], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `shudl-config-${new Date().toISOString().split('T')[0]}.json`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        
        notificationManager.success('Configuration exported successfully');
    }

    importConfiguration() {
        const input = document.createElement('input');
        input.type = 'file';
        input.accept = '.json';
        
        input.addEventListener('change', (e) => {
            const file = e.target.files[0];
            if (!file) return;
            
            const reader = new FileReader();
            reader.onload = (e) => {
                try {
                    const config = JSON.parse(e.target.result);
                    this.loadConfiguration(config);
                    notificationManager.success('Configuration imported successfully');
                } catch (error) {
                    notificationManager.error('Failed to import configuration: Invalid JSON');
                }
            };
            reader.readAsText(file);
        });
        
        input.click();
    }

    loadConfiguration(config) {
        this.resetSelection();
        
        if (config.services) {
            Object.entries(config.services).forEach(([serviceName, serviceConfig]) => {
                const service = this.serviceDefinitions.get(serviceName);
                if (service && serviceConfig.enabled) {
                    service.config = serviceConfig.config || {};
                    this.selectedServices.set(serviceName, service);
                }
            });
        }
        
        this.renderCanvas();
        this.renderConfigurationForms();
        this.updateDependencyGraph();
        this.triggerValidation();
    }

    // Public API for external access
    getSelectedServices() {
        return Array.from(this.selectedServices.keys());
    }

    getConfiguration() {
        return this.buildConfiguration();
    }

    isValid() {
        return this.validationStatus === 'valid';
    }
} 