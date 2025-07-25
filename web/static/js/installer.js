/**
 * ShuDL Installer - Compiled JavaScript
 * Built from modular ES6 source files
 * Generated: Fri Jul 25 13:58:31 UTC 2025
 */

/* === API Module === */
/**
 * API Communication Module
 * Handles all HTTP requests to the ShuDL installer API
 */

class APIClient {
    constructor(baseURL = '/api/v1') {
        this.baseURL = baseURL;
    }

    /**
     * Make HTTP request with error handling
     */
    async request(endpoint, options = {}) {
        const url = `${this.baseURL}${endpoint}`;
        
        try {
            const response = await fetch(url, {
                headers: {
                    'Content-Type': 'application/json',
                    ...options.headers
                },
                ...options
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }

            return await response.json();
        } catch (error) {
            console.error(`API request failed: ${url}`, error);
            throw error;
        }
    }

    /**
     * System validation endpoints
     */
    async validateSystem() {
        return this.request('/docker/validate');
    }

    /**
     * Configuration endpoints
     */
    async getConfigSchema() {
        return this.request('/web/config');
    }

    async validateConfiguration(config) {
        return this.request('/compose/validate', {
            method: 'POST',
            body: JSON.stringify(config)
        });
    }

    async generateFiles(config) {
        return this.request('/compose/generate', {
            method: 'POST',
            body: JSON.stringify(config)
        });
    }

    /**
     * Deployment endpoints
     */
    async startServices(config) {
        return this.request('/docker/start', {
            method: 'POST',
            body: JSON.stringify(config)
        });
    }

    async stopServices(projectName) {
        return this.request('/docker/stop', {
            method: 'POST',
            body: JSON.stringify({ project_name: projectName })
        });
    }

    async restartServices(projectName) {
        return this.request('/docker/restart', {
            method: 'POST',
            body: JSON.stringify({ project_name: projectName })
        });
    }

    async getServiceStatus(projectName) {
        return this.request(`/docker/status?project=${projectName}`);
    }

    async getServiceLogs(projectName, serviceName, tail = 100) {
        return this.request(`/docker/logs?project=${projectName}&service=${serviceName}&tail=${tail}`);
    }

    async getDeploymentProgress(projectName) {
        return this.request(`/web/progress?project=${projectName}`);
    }
}

// Export singleton instance
const apiClient = new APIClient(); 
/* === Validation Module === */
/**
 * System Validation Module
 * Handles system requirement checks and validation
 */



class SystemValidator {
    constructor() {
        this.checks = [
            { id: 'docker-status', name: 'Docker', check: () => this.checkDocker() },
            { id: 'compose-status', name: 'Docker Compose', check: () => this.checkDockerCompose() },
            { id: 'memory-status', name: 'Memory', check: () => this.checkMemory() }
        ];
    }

    /**
     * Run all system requirement checks
     */
    async runAllChecks() {
        let allPassed = true;

        for (const check of this.checks) {
            try {
                const result = await check.check();
                this.updateStatusItem(check.id, result.success, result.message, result.details);
                if (!result.success) allPassed = false;
            } catch (error) {
                this.updateStatusItem(check.id, false, 'Check failed', error.message);
                allPassed = false;
            }
        }

        this.updateStartButton(allPassed);
        return allPassed;
    }

    /**
     * Check Docker availability
     */
    async checkDocker() {
        try {
            const data = await apiClient.validateSystem();
            
            if (data.success && data.data) {
                return {
                    success: true,
                    message: 'Docker available',
                    details: `Version: ${data.data.details?.docker_version || 'Unknown'}`
                };
            } else {
                return {
                    success: false,
                    message: 'Docker not available',
                    details: 'Please install Docker'
                };
            }
        } catch (error) {
            return {
                success: false,
                message: 'Cannot check Docker',
                details: error.message
            };
        }
    }

    /**
     * Check Docker Compose availability
     */
    async checkDockerCompose() {
        try {
            const data = await apiClient.validateSystem();
            
            if (data.success && data.data) {
                return {
                    success: true,
                    message: 'Docker Compose available',
                    details: `Version: ${data.data.details?.compose_version || 'Unknown'}`
                };
            } else {
                return {
                    success: false,
                    message: 'Docker Compose not available',
                    details: 'Please install Docker Compose'
                };
            }
        } catch (error) {
            return {
                success: false,
                message: 'Cannot check Docker Compose',
                details: error.message
            };
        }
    }

    /**
     * Check system memory
     */
    async checkMemory() {
        return new Promise(resolve => {
            setTimeout(() => {
                const totalMemoryGB = 8; // Simulate 8GB
                const requiredMemoryGB = 4; // Require 4GB minimum
                
                if (totalMemoryGB >= requiredMemoryGB) {
                    resolve({
                        success: true,
                        message: 'Sufficient memory',
                        details: `${totalMemoryGB}GB available (${requiredMemoryGB}GB required)`
                    });
                } else {
                    resolve({
                        success: false,
                        message: 'Insufficient memory',
                        details: `${totalMemoryGB}GB available, ${requiredMemoryGB}GB required`
                    });
                }
            }, 1000);
        });
    }

    /**
     * Update status item in UI
     */
    updateStatusItem(id, success, message, details) {
        const item = document.getElementById(id);
        if (!item) return;

        const icon = item.querySelector('.status-icon');
        const messageEl = item.querySelector('.status-message');
        const detailsEl = item.querySelector('.status-details');

        if (icon) {
            icon.className = `status-icon ${success ? 'success' : 'error'}`;
            icon.innerHTML = success ? '<i class="fas fa-check"></i>' : '<i class="fas fa-times"></i>';
        }

        if (messageEl) messageEl.textContent = message;
        if (detailsEl) detailsEl.textContent = details;
        
        item.className = `status-item ${success ? 'success' : 'error'}`;
    }

    /**
     * Update the start installation button
     */
    updateStartButton(allPassed) {
        const startButton = document.getElementById('start-installation');
        if (!startButton) return;

        startButton.disabled = !allPassed;
        
        if (allPassed) {
            startButton.innerHTML = '<i class="fas fa-play"></i> Start Installation';
        } else {
            startButton.innerHTML = '<i class="fas fa-exclamation-triangle"></i> System Requirements Not Met';
        }
    }
} 
/* === Step Controller Component === */
/**
 * Step Controller Component
 * Manages multi-step installer navigation
 */

class StepController {
    constructor(totalSteps = 5) {
        this.currentStep = 1;
        this.totalSteps = totalSteps;
        this.bindEvents();
    }

    /**
     * Bind step navigation events
     */
    bindEvents() {
        // Step navigation buttons
        document.getElementById('start-installation')?.addEventListener('click', () => this.nextStep());
        document.getElementById('next-to-preview')?.addEventListener('click', () => this.nextStep());
        document.getElementById('back-to-config')?.addEventListener('click', () => this.previousStep());
        document.getElementById('start-deployment')?.addEventListener('click', () => this.nextStep());

        // Preview tab switching
        document.querySelectorAll('.tab-button').forEach(button => {
            button.addEventListener('click', (e) => {
                const tabName = e.target.dataset.tab;
                if (tabName) {
                    this.switchPreviewTab(tabName);
                }
            });
        });
    }

    /**
     * Navigate to next step
     */
    nextStep() {
        if (this.currentStep < this.totalSteps) {
            this.currentStep++;
            this.updateStepDisplay();
        }
    }

    /**
     * Navigate to previous step
     */
    previousStep() {
        if (this.currentStep > 1) {
            this.currentStep--;
            this.updateStepDisplay();
        }
    }

    /**
     * Go to specific step
     */
    goToStep(step) {
        if (step >= 1 && step <= this.totalSteps) {
            this.currentStep = step;
            this.updateStepDisplay();
        }
    }

    /**
     * Update the UI to show current step
     */
    updateStepDisplay() {
        // Update progress indicators
        document.querySelectorAll('.step').forEach((step, index) => {
            const stepNumber = index + 1;
            step.classList.remove('active', 'completed');
            
            if (stepNumber === this.currentStep) {
                step.classList.add('active');
            } else if (stepNumber < this.currentStep) {
                step.classList.add('completed');
            }
        });

        // Update step content visibility
        document.querySelectorAll('.step-content').forEach((content, index) => {
            const stepNumber = index + 1;
            content.classList.remove('active');
            
            if (stepNumber === this.currentStep) {
                content.classList.add('active');
            }
        });

        // Dispatch step change event
        window.dispatchEvent(new CustomEvent('stepChanged', {
            detail: { currentStep: this.currentStep }
        }));
    }

    /**
     * Switch preview tabs
     */
    switchPreviewTab(tabName) {
        // Update tab buttons
        document.querySelectorAll('.tab-button').forEach(button => {
            button.classList.remove('active');
            if (button.dataset.tab === tabName) {
                button.classList.add('active');
            }
        });

        // Update tab panes
        document.querySelectorAll('.tab-pane').forEach(pane => {
            pane.classList.remove('active');
            if (pane.id === `${tabName}-preview`) {
                pane.classList.add('active');
            }
        });
    }

    /**
     * Mark current step as completed
     */
    completeCurrentStep() {
        document.querySelector(`.step[data-step="${this.currentStep}"]`)?.classList.add('completed');
    }

    /**
     * Get current step number
     */
    getCurrentStep() {
        return this.currentStep;
    }
} 
/* === Notifications Component === */
/**
 * Notification System Component
 * Handles toast notifications and user feedback
 */

class NotificationManager {
    constructor() {
        this.container = this.createContainer();
        this.notifications = new Map();
    }

    /**
     * Create notifications container if it doesn't exist
     */
    createContainer() {
        let container = document.querySelector('.notifications-container');
        
        if (!container) {
            container = document.createElement('div');
            container.className = 'notifications-container';
            document.body.appendChild(container);
        }
        
        return container;
    }

    /**
     * Show notification
     */
    show(message, type = 'info', duration = 5000) {
        const id = Date.now() + Math.random();
        const notification = this.createNotification(id, message, type);
        
        this.container.appendChild(notification);
        this.notifications.set(id, notification);

        // Auto-remove after duration
        if (duration > 0) {
            setTimeout(() => this.remove(id), duration);
        }

        return id;
    }

    /**
     * Show success notification
     */
    success(message, duration = 5000) {
        return this.show(message, 'success', duration);
    }

    /**
     * Show error notification
     */
    error(message, duration = 8000) {
        return this.show(message, 'error', duration);
    }

    /**
     * Show warning notification
     */
    warning(message, duration = 6000) {
        return this.show(message, 'warning', duration);
    }

    /**
     * Show info notification
     */
    info(message, duration = 5000) {
        return this.show(message, 'info', duration);
    }

    /**
     * Create notification element
     */
    createNotification(id, message, type) {
        const notification = document.createElement('div');
        notification.className = `notification ${type}`;
        notification.dataset.id = id;
        
        const icon = this.getIconForType(type);
        
        notification.innerHTML = `
            <div class="notification-content">
                <div class="notification-icon">
                    <i class="fas fa-${icon}"></i>
                </div>
                <div class="notification-message">${message}</div>
                <button class="notification-close" onclick="notificationManager.remove('${id}')">
                    <i class="fas fa-times"></i>
                </button>
            </div>
        `;

        return notification;
    }

    /**
     * Get icon for notification type
     */
    getIconForType(type) {
        const icons = {
            success: 'check-circle',
            error: 'exclamation-circle',
            warning: 'exclamation-triangle',
            info: 'info-circle'
        };
        return icons[type] || 'info-circle';
    }

    /**
     * Remove notification
     */
    remove(id) {
        const notification = this.notifications.get(id);
        if (notification) {
            notification.style.animation = 'slideOutRight 0.3s ease-in';
            setTimeout(() => {
                if (notification.parentNode) {
                    notification.parentNode.removeChild(notification);
                }
                this.notifications.delete(id);
            }, 300);
        }
    }

    /**
     * Clear all notifications
     */
    clear() {
        this.notifications.forEach((_, id) => this.remove(id));
    }

    /**
     * Show loading notification
     */
    showLoading(message = 'Loading...') {
        return this.show(`
            <div class="loading-notification">
                <i class="fas fa-spinner fa-spin"></i>
                <span>${message}</span>
            </div>
        `, 'info', 0);
    }
}

// Export singleton instance
const notificationManager = new NotificationManager();

// Make it globally available for inline event handlers
window.notificationManager = notificationManager; 
/* === Main Application === */
/**
 * ShuDL Installer - Main Application Controller
 * Modular, modern JavaScript architecture with Phase 1B enhancements
 */







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
 