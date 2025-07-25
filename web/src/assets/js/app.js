/**
 * ShuDL Installer - Main Application Controller
 * Modular, modern JavaScript architecture with Phase 1B enhancements
 */

import { apiClient } from './modules/api.js';
import { SystemValidator } from './modules/validation.js';
import { StepController } from './components/step-controller.js';
import { notificationManager } from './components/notifications.js';
import { ServiceBuilder } from './components/service-builder.js';

class ShuDLInstallerApp {
    constructor() {
        this.stepController = new StepController();
        this.systemValidator = new SystemValidator();
        this.serviceBuilder = null; // Will be initialized when needed
        this.currentConfig = {};
        this.configSchema = null;
        this.validationErrors = {};
        this.deploymentProgress = 0;
        this.serviceStatus = {};
        
        this.init();
    }

    /**
     * Initialize the application
     */
    async init() {
        try {
            this.bindGlobalEvents();
            await this.systemValidator.runAllChecks();
            await this.loadConfigSchema();
            
            notificationManager.success('Application initialized successfully');
        } catch (error) {
            console.error('Application initialization failed:', error);
            notificationManager.error('Failed to initialize application');
        }
    }

    /**
     * Bind global event listeners
     */
    bindGlobalEvents() {
        // Configuration events
        document.getElementById('validate-config')?.addEventListener('click', () => this.validateConfiguration());
        
        // Dashboard events
        document.getElementById('restart-services')?.addEventListener('click', () => this.restartServices());
        document.getElementById('stop-services')?.addEventListener('click', () => this.stopServices());
        document.getElementById('view-logs')?.addEventListener('click', () => this.viewLogs());

        // Listen to step changes
        window.addEventListener('stepChanged', (event) => {
            this.onStepChanged(event.detail.currentStep);
        });
    }

    /**
     * Handle step change events
     */
    async onStepChanged(step) {
        switch (step) {
            case 2: // Configuration step
                await this.loadConfigurationStep();
                break;
            case 3: // Preview step
                await this.loadPreviewStep();
                break;
            case 4: // Deployment step
                await this.startDeployment();
                break;
            case 5: // Dashboard step
                await this.loadDashboard();
                break;
        }
    }

    /**
     * Load configuration schema from API
     */
    async loadConfigSchema() {
        try {
            const response = await apiClient.getConfigSchema();
            if (response.success) {
                this.configSchema = response.data;
            }
        } catch (error) {
            console.error('Failed to load config schema:', error);
        }
    }

    /**
     * Load configuration step with Phase 1B enhancements
     */
    async loadConfigurationStep() {
        try {
            // Initialize ServiceBuilder if not already done
            if (!this.serviceBuilder) {
                this.serviceBuilder = new ServiceBuilder();
                
                // Wait for ServiceBuilder to initialize
                await new Promise(resolve => {
                    const checkInit = () => {
                        if (this.serviceBuilder.serviceDefinitions.size > 0) {
                            resolve();
                        } else {
                            setTimeout(checkInit, 100);
                        }
                    };
                    checkInit();
                });
            }
            
            notificationManager.info('Configuration interface loaded with visual builder');
        } catch (error) {
            console.error('Failed to load configuration step:', error);
            notificationManager.error('Failed to load configuration interface');
        }
    }

    /**
     * Load preview step with enhanced functionality
     */
    async loadPreviewStep() {
        try {
            // Get configuration from ServiceBuilder if available
            if (this.serviceBuilder) {
                this.currentConfig = this.serviceBuilder.getConfiguration();
            }
            
            await this.generatePreview();
            notificationManager.info('Configuration preview generated');
        } catch (error) {
            console.error('Failed to load preview step:', error);
            notificationManager.error('Failed to generate preview');
        }
    }

    /**
     * Generate configuration preview
     */
    async generatePreview() {
        try {
            const response = await apiClient.previewGeneration(this.currentConfig);
            
            if (response.success) {
                this.updatePreviewDisplay(response.data);
            } else {
                notificationManager.error('Failed to generate preview');
            }
        } catch (error) {
            console.error('Preview generation failed:', error);
            notificationManager.error('Preview generation failed');
        }
    }

    /**
     * Update preview display with generated content
     */
    updatePreviewDisplay(previewData) {
        // Update services preview
        const servicesPreview = document.getElementById('services-preview');
        if (servicesPreview && previewData.services) {
            servicesPreview.innerHTML = this.renderServicesPreview(previewData.services);
        }

        // Update compose preview
        const composePreview = document.getElementById('compose-preview');
        if (composePreview && previewData.compose_content) {
            composePreview.innerHTML = `<code>${this.escapeHtml(previewData.compose_content)}</code>`;
        }

        // Update environment preview
        const envPreview = document.getElementById('env-preview');
        if (envPreview && previewData.env_content) {
            envPreview.innerHTML = `<code>${this.escapeHtml(previewData.env_content)}</code>`;
        }
    }

    /**
     * Render services preview with dependency information
     */
    renderServicesPreview(services) {
        return Object.entries(services).map(([serviceName, serviceConfig]) => {
            const service = this.serviceBuilder?.serviceDefinitions.get(serviceName);
            const icon = this.serviceBuilder?.getServiceIcon(serviceName) || 'fas fa-cube';
            
            return `
                <div class="service-preview-card">
                    <div class="service-header">
                        <i class="${icon}"></i>
                        <h4>${service?.display_name || serviceName}</h4>
                        <span class="service-status ${serviceConfig.enabled ? 'enabled' : 'disabled'}">
                            ${serviceConfig.enabled ? 'Enabled' : 'Disabled'}
                        </span>
                    </div>
                    <div class="service-config">
                        ${this.renderServiceConfigPreview(serviceConfig.config)}
                    </div>
                </div>
            `;
        }).join('');
    }

    /**
     * Render service configuration preview
     */
    renderServiceConfigPreview(config) {
        if (!config || Object.keys(config).length === 0) {
            return '<p class="text-muted">Default configuration</p>';
        }

        return Object.entries(config).map(([key, value]) => {
            return `<div class="config-item"><strong>${key}:</strong> ${value}</div>`;
        }).join('');
    }

    /**
     * Validate current configuration
     */
    async validateConfiguration() {
        const loadingId = notificationManager.showLoading('Validating configuration...');
        
        try {
            // Use ServiceBuilder configuration if available
            const configToValidate = this.serviceBuilder ? 
                this.serviceBuilder.getConfiguration() : 
                this.currentConfig;
            
            const response = await apiClient.validateConfiguration(configToValidate);
            notificationManager.remove(loadingId);
            
            if (response.success && response.data.valid) {
                notificationManager.success('Configuration is valid');
                this.validationErrors = {};
            } else {
                notificationManager.warning('Configuration has validation errors');
                this.validationErrors = response.data.errors || {};
            }
        } catch (error) {
            notificationManager.remove(loadingId);
            notificationManager.error('Configuration validation failed');
            console.error('Validation failed:', error);
        }
    }

    /**
     * Start deployment process
     */
    async startDeployment() {
        const loadingId = notificationManager.showLoading('Starting deployment...');
        
        try {
            // Use ServiceBuilder configuration if available
            const configToDeploy = this.serviceBuilder ? 
                this.serviceBuilder.getConfiguration() : 
                this.currentConfig;
            
            const response = await apiClient.startServices(configToDeploy);
            notificationManager.remove(loadingId);
            
            if (response.success) {
                notificationManager.success('Deployment started successfully');
                this.monitorDeployment();
            } else {
                notificationManager.error('Failed to start deployment');
            }
        } catch (error) {
            notificationManager.remove(loadingId);
            notificationManager.error('Deployment failed to start');
            console.error('Deployment failed:', error);
        }
    }

    /**
     * Monitor deployment progress
     */
    async monitorDeployment() {
        try {
            const response = await apiClient.getDeploymentProgress();
            
            if (response.success) {
                this.updateDeploymentProgress(response.data);
                
                // Continue monitoring if not complete
                if (response.data.status !== 'completed' && response.data.status !== 'failed') {
                    setTimeout(() => this.monitorDeployment(), 2000);
                } else if (response.data.status === 'completed') {
                    notificationManager.success('Deployment completed successfully');
                    // Auto-advance to monitoring step
                    this.stepController.goToStep(5);
                }
            }
        } catch (error) {
            console.error('Failed to monitor deployment:', error);
        }
    }

    /**
     * Update deployment progress display
     */
    updateDeploymentProgress(progressData) {
        // Update progress bar
        const progressFill = document.getElementById('deployment-progress-fill');
        const progressText = document.getElementById('deployment-percentage');
        const statusText = document.getElementById('deployment-status');
        
        if (progressFill) {
            progressFill.style.width = `${progressData.percentage || 0}%`;
        }
        
        if (progressText) {
            progressText.textContent = `${progressData.percentage || 0}%`;
        }
        
        if (statusText) {
            statusText.textContent = progressData.status || 'Deploying...';
        }

        // Update service status
        if (progressData.services) {
            this.updateServicesStatus(progressData.services);
        }
    }

    /**
     * Update services status display
     */
    updateServicesStatus(servicesStatus) {
        const container = document.getElementById('services-status');
        if (!container) return;

        container.innerHTML = Object.entries(servicesStatus).map(([serviceName, status]) => {
            const icon = this.serviceBuilder?.getServiceIcon(serviceName) || 'fas fa-cube';
            const statusClass = status.status === 'running' ? 'success' : 
                              status.status === 'failed' ? 'error' : 'pending';
            
            return `
                <div class="service-status-item ${statusClass}">
                    <i class="${icon}"></i>
                    <span class="service-name">${serviceName}</span>
                    <span class="service-status">${status.status}</span>
                </div>
            `;
        }).join('');
    }

    /**
     * Load dashboard with monitoring integration
     */
    async loadDashboard() {
        try {
            await this.loadServiceStatus();
            notificationManager.info('Dashboard loaded successfully');
        } catch (error) {
            console.error('Failed to load dashboard:', error);
            notificationManager.error('Failed to load dashboard');
        }
    }

    /**
     * Load service status for dashboard
     */
    async loadServiceStatus() {
        try {
            const response = await apiClient.getServiceStatus();
            
            if (response.success) {
                this.serviceStatus = response.data;
                this.updateDashboardDisplay();
            }
        } catch (error) {
            console.error('Failed to load service status:', error);
        }
    }

    /**
     * Update dashboard display
     */
    updateDashboardDisplay() {
        // Implementation for dashboard updates
        // This would include service status, metrics, etc.
    }

    /**
     * Utility functions
     */
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    /**
     * Restart services
     */
    async restartServices() {
        const loadingId = notificationManager.showLoading('Restarting services...');
        
        try {
            const response = await apiClient.restartServices();
            notificationManager.remove(loadingId);
            
            if (response.success) {
                notificationManager.success('Services restarted successfully');
                await this.loadServiceStatus();
            } else {
                notificationManager.error('Failed to restart services');
            }
        } catch (error) {
            notificationManager.remove(loadingId);
            notificationManager.error('Failed to restart services');
            console.error('Restart failed:', error);
        }
    }

    /**
     * Stop services
     */
    async stopServices() {
        const loadingId = notificationManager.showLoading('Stopping services...');
        
        try {
            const response = await apiClient.stopServices();
            notificationManager.remove(loadingId);
            
            if (response.success) {
                notificationManager.success('Services stopped successfully');
                await this.loadServiceStatus();
            } else {
                notificationManager.error('Failed to stop services');
            }
        } catch (error) {
            notificationManager.remove(loadingId);
            notificationManager.error('Failed to stop services');
            console.error('Stop failed:', error);
        }
    }

    /**
     * View logs
     */
    async viewLogs() {
        try {
            const response = await apiClient.getLogs();
            
            if (response.success) {
                // Display logs in a modal or dedicated area
                this.displayLogs(response.data);
            } else {
                notificationManager.error('Failed to load logs');
            }
        } catch (error) {
            notificationManager.error('Failed to load logs');
            console.error('Failed to load logs:', error);
        }
    }

    /**
     * Display logs
     */
    displayLogs(logs) {
        // Implementation for displaying logs
        console.log('Logs:', logs);
    }

    /**
     * Public API for external access
     */
    getServiceBuilder() {
        return this.serviceBuilder;
    }

    getCurrentConfiguration() {
        return this.serviceBuilder ? this.serviceBuilder.getConfiguration() : this.currentConfig;
    }

    isConfigurationValid() {
        return this.serviceBuilder ? this.serviceBuilder.isValid() : Object.keys(this.validationErrors).length === 0;
    }
}

// Initialize application when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.shuDLApp = new ShuDLInstallerApp();
});

// Export for module usage
export { ShuDLInstallerApp }; 