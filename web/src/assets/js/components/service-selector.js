/**
 * Service Selector Component
 * Enhanced visual service selection with categories and dependencies
 */

import { apiClient } from '../modules/api.js';
import { notificationManager } from './notifications.js';

export class ServiceSelector {
    constructor(container) {
        this.container = container;
        this.services = [];
        this.categories = [];
        this.selectedServices = new Set();
        this.activeCategory = 'all';
        this.onSelectionChange = null;
        
        this.init();
    }
    
    async init() {
        try {
            // Load available services
            const response = await apiClient.getAvailableServices();
            this.services = response.services || [];
            this.categories = ['all', ...response.categories || []];
            
            this.render();
            this.bindEvents();
        } catch (error) {
            console.error('Failed to load services:', error);
            notificationManager.error('Failed to load available services');
        }
    }
    
    render() {
        this.container.innerHTML = `
            <div class="service-selector">
                <div class="service-categories">
                    ${this.renderCategories()}
                </div>
                
                <div class="services-grid">
                    ${this.renderServices()}
                </div>
                
                ${this.renderSummary()}
            </div>
        `;
    }
    
    renderCategories() {
        return this.categories.map(category => `
            <button class="category-tab ${category === this.activeCategory ? 'active' : ''}" 
                    data-category="${category}">
                <i class="fas fa-${this.getCategoryIcon(category)}"></i>
                ${category === 'all' ? 'All Services' : category.charAt(0).toUpperCase() + category.slice(1)}
            </button>
        `).join('');
    }
    
    renderServices() {
        const filteredServices = this.activeCategory === 'all' 
            ? this.services 
            : this.services.filter(service => service.category === this.activeCategory);
            
        return filteredServices.map(service => this.renderServiceCard(service)).join('');
    }
    
    renderServiceCard(service) {
        const isSelected = this.selectedServices.has(service.name);
        const isDisabled = this.isServiceDisabled(service);
        const isRequired = service.required || false;
        
        return `
            <div class="service-card ${isSelected ? 'selected' : ''} ${isDisabled ? 'disabled' : ''} ${isRequired ? 'required' : ''}" 
                 data-service="${service.name}">
                <div class="service-header">
                    <div class="service-info">
                        <div class="service-icon">
                            <i class="fas fa-${this.getServiceIcon(service)}"></i>
                        </div>
                        <div class="service-details">
                            <h4>${service.displayName || service.name}</h4>
                            <div class="service-name">${service.name}</div>
                        </div>
                    </div>
                    <div class="service-checkbox">
                        ${isSelected ? '<i class="fas fa-check"></i>' : ''}
                    </div>
                </div>
                
                <div class="service-description">
                    ${service.description || 'No description available'}
                </div>
                
                <div class="service-meta">
                    <span class="service-tag category">${service.category}</span>
                    ${isRequired ? '<span class="service-tag">Required</span>' : ''}
                </div>
                
                ${service.ports && service.ports.length > 0 ? `
                    <div class="service-ports">
                        ${service.ports.map(port => `<span class="port-tag">${port.external || port.internal}</span>`).join('')}
                    </div>
                ` : ''}
                
                ${service.dependencies && service.dependencies.length > 0 ? `
                    <div class="service-dependencies">
                        <h5><i class="fas fa-link"></i> Dependencies</h5>
                        <div class="dependency-list">
                            ${service.dependencies.map(dep => `<span class="dependency-tag">${dep}</span>`).join('')}
                        </div>
                    </div>
                ` : ''}
            </div>
        `;
    }
    
    renderSummary() {
        if (this.selectedServices.size === 0) {
            return '';
        }
        
        return `
            <div class="services-summary">
                <h3>
                    <i class="fas fa-layer-group"></i>
                    Selected Services (${this.selectedServices.size})
                </h3>
                <div class="selected-services">
                    ${Array.from(this.selectedServices).map(serviceName => {
                        const service = this.services.find(s => s.name === serviceName);
                        return `
                            <div class="selected-service">
                                <i class="fas fa-${this.getServiceIcon(service)}"></i>
                                ${service.displayName || serviceName}
                                ${!service.required ? `<button class="remove-btn" data-service="${serviceName}">×</button>` : ''}
                            </div>
                        `;
                    }).join('')}
                </div>
            </div>
        `;
    }
    
    bindEvents() {
        // Category tabs
        this.container.addEventListener('click', (e) => {
            if (e.target.matches('.category-tab')) {
                this.activeCategory = e.target.dataset.category;
                this.render();
                this.bindEvents();
            }
        });
        
        // Service selection
        this.container.addEventListener('click', (e) => {
            const serviceCard = e.target.closest('.service-card');
            if (serviceCard && !serviceCard.classList.contains('disabled')) {
                const serviceName = serviceCard.dataset.service;
                this.toggleService(serviceName);
            }
        });
        
        // Remove service
        this.container.addEventListener('click', (e) => {
            if (e.target.matches('.remove-btn')) {
                e.stopPropagation();
                const serviceName = e.target.dataset.service;
                this.removeService(serviceName);
            }
        });
    }
    
    toggleService(serviceName) {
        const service = this.services.find(s => s.name === serviceName);
        if (!service) return;
        
        if (this.selectedServices.has(serviceName)) {
            this.removeService(serviceName);
        } else {
            this.addService(serviceName);
        }
    }
    
    addService(serviceName) {
        const service = this.services.find(s => s.name === serviceName);
        if (!service) return;
        
        // Add dependencies first
        if (service.dependencies) {
            service.dependencies.forEach(dep => {
                if (!this.selectedServices.has(dep)) {
                    this.selectedServices.add(dep);
                }
            });
        }
        
        // Add the service itself
        this.selectedServices.add(serviceName);
        
        this.render();
        this.bindEvents();
        this.notifySelectionChange();
    }
    
    removeService(serviceName) {
        const service = this.services.find(s => s.name === serviceName);
        if (!service || service.required) return;
        
        // Check if any selected services depend on this one
        const dependentServices = this.services.filter(s => 
            this.selectedServices.has(s.name) && 
            s.dependencies && 
            s.dependencies.includes(serviceName)
        );
        
        if (dependentServices.length > 0) {
            notificationManager.warning(
                `Cannot remove ${service.displayName || serviceName}. ` +
                `It's required by: ${dependentServices.map(s => s.displayName || s.name).join(', ')}`
            );
            return;
        }
        
        this.selectedServices.delete(serviceName);
        this.render();
        this.bindEvents();
        this.notifySelectionChange();
    }
    
    isServiceDisabled(service) {
        // Check if dependencies are missing
        if (service.dependencies) {
            return service.dependencies.some(dep => !this.selectedServices.has(dep));
        }
        return false;
    }
    
    getServiceIcon(service) {
        const iconMap = {
            postgresql: 'database',
            minio: 'cube',
            nessie: 'code-branch',
            trino: 'search',
            'spark-master': 'fire',
            'spark-worker': 'fire',
            spark: 'fire',
            prometheus: 'chart-line',
            grafana: 'chart-bar'
        };
        return iconMap[service.name] || 'cog';
    }
    
    getCategoryIcon(category) {
        const iconMap = {
            all: 'th-large',
            infrastructure: 'server',
            compute: 'microchip',
            monitoring: 'chart-line'
        };
        return iconMap[category] || 'folder';
    }
    
    getSelectedServices() {
        return Array.from(this.selectedServices);
    }
    
    setSelectedServices(services) {
        this.selectedServices = new Set(services);
        
        // Auto-add required services
        this.services.filter(s => s.required).forEach(service => {
            this.selectedServices.add(service.name);
        });
        
        this.render();
        this.bindEvents();
        this.notifySelectionChange();
    }
    
    notifySelectionChange() {
        if (this.onSelectionChange) {
            this.onSelectionChange(this.getSelectedServices());
        }
    }
} 