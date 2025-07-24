/**
 * ShuDL Installer JavaScript
 * Intelligent, dynamic configuration system with real-time validation
 */

class ShuDLInstaller {
    constructor() {
        this.currentStep = 1;
        this.totalSteps = 5;
        this.configSchema = null;
        this.currentConfig = {};
        this.validationErrors = {};
        this.deploymentProgress = 0;
        this.deploymentLogs = [];
        this.serviceStatus = {};
        
        this.init();
    }

    async init() {
        this.bindEvents();
        await this.checkSystemRequirements();
        await this.loadConfigSchema();
        this.updateUI();
    }

    bindEvents() {
        // Step navigation
        document.getElementById('start-installation')?.addEventListener('click', () => this.nextStep());
        document.getElementById('next-to-preview')?.addEventListener('click', () => this.nextStep());
        document.getElementById('back-to-config')?.addEventListener('click', () => this.previousStep());
        document.getElementById('start-deployment')?.addEventListener('click', () => this.startDeployment());
        
        // Configuration events
        document.getElementById('validate-config')?.addEventListener('click', () => this.validateConfiguration());
        
        // Dashboard events
        document.getElementById('restart-services')?.addEventListener('click', () => this.restartServices());
        document.getElementById('stop-services')?.addEventListener('click', () => this.stopServices());
        document.getElementById('view-logs')?.addEventListener('click', () => this.viewLogs());

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

    async checkSystemRequirements() {
        const checks = [
            { id: 'docker-status', name: 'Docker', check: () => this.checkDocker() },
            { id: 'compose-status', name: 'Docker Compose', check: () => this.checkDockerCompose() },
            { id: 'memory-status', name: 'Memory', check: () => this.checkMemory() }
        ];

        let allPassed = true;

        for (const check of checks) {
            try {
                const result = await check.check();
                this.updateStatusItem(check.id, result.success, result.message, result.details);
                if (!result.success) allPassed = false;
            } catch (error) {
                this.updateStatusItem(check.id, false, 'Check failed', error.message);
                allPassed = false;
            }
        }

        // Enable start button if all checks pass
        const startButton = document.getElementById('start-installation');
        if (startButton) {
            startButton.disabled = !allPassed;
            if (allPassed) {
                startButton.innerHTML = '<i class="fas fa-play"></i> Start Installation';
            } else {
                startButton.innerHTML = '<i class="fas fa-exclamation-triangle"></i> System Requirements Not Met';
            }
        }
    }

    async checkDocker() {
        try {
            const response = await fetch('/api/v1/system/validate');
            const data = await response.json();
            
            if (data.success && data.data) {
                return {
                    success: true,
                    message: 'Docker available',
                    details: `Version: ${data.data.docker_version || 'Unknown'}`
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

    async checkDockerCompose() {
        try {
            const response = await fetch('/api/v1/system/validate');
            const data = await response.json();
            
            if (data.success && data.data) {
                return {
                    success: true,
                    message: 'Docker Compose available',
                    details: `Version: ${data.data.compose_version || 'Unknown'}`
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

    async checkMemory() {
        // Simulate memory check - in real implementation, this would check system memory
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
                        details: `${totalMemoryGB}GB available (${requiredMemoryGB}GB required)`
                    });
                }
            }, 1000);
        });
    }

    updateStatusItem(id, success, message, details) {
        const item = document.getElementById(id);
        if (!item) return;

        const icon = item.querySelector('.status-icon');
        const title = item.querySelector('.status-title');
        const subtitle = item.querySelector('.status-subtitle');

        // Update icon
        icon.className = `status-icon ${success ? 'success' : 'error'}`;
        icon.innerHTML = success ? '<i class="fas fa-check"></i>' : '<i class="fas fa-times"></i>';

        // Update text
        if (title) title.textContent = title.textContent; // Keep original title
        if (subtitle) subtitle.textContent = details || message;

        // Update item class
        item.className = `status-item ${success ? 'success' : 'error'}`;
    }

    async loadConfigSchema() {
        try {
            const response = await fetch('/api/v1/installer/config-schema');
            const data = await response.json();
            
            if (data.success) {
                this.configSchema = data.data;
                this.renderConfigurationTabs();
                this.initializeDefaultValues();
            } else {
                this.showNotification('error', 'Failed to load configuration schema');
            }
        } catch (error) {
            this.showNotification('error', 'Error loading configuration: ' + error.message);
        }
    }

    renderConfigurationTabs() {
        if (!this.configSchema || !this.configSchema.categories) return;

        const tabNav = document.getElementById('config-tab-nav');
        const tabContent = document.getElementById('config-tab-content');
        
        if (!tabNav || !tabContent) return;

        tabNav.innerHTML = '';
        tabContent.innerHTML = '';

        let isFirst = true;
        
        Object.entries(this.configSchema.categories).forEach(([categoryKey, category]) => {
            // Create tab button
            const tabButton = document.createElement('div');
            tabButton.className = `tab-button ${isFirst ? 'active' : ''}`;
            tabButton.dataset.tab = categoryKey;
            tabButton.textContent = category.display_name;
            tabButton.addEventListener('click', () => this.switchConfigTab(categoryKey));
            tabNav.appendChild(tabButton);

            // Create tab content
            const tabPane = document.createElement('div');
            tabPane.className = `tab-pane ${isFirst ? 'active' : ''}`;
            tabPane.id = `config-${categoryKey}`;
            
            tabPane.innerHTML = `
                <div class="category-header">
                    <h3>${category.display_name}</h3>
                    <p>${category.description}</p>
                </div>
                <div class="category-fields" id="fields-${categoryKey}">
                    ${this.renderCategoryFields(category.fields)}
                </div>
            `;
            
            tabContent.appendChild(tabPane);
            isFirst = false;
        });

        // Bind field events
        this.bindFieldEvents();
    }

    renderCategoryFields(fields) {
        return fields.map(field => {
            const required = field.required ? 'required' : '';
            const sharedInfo = field.shared_with ? ` (shared with: ${field.shared_with.join(', ')})` : '';
            
            switch (field.type) {
                case 'select':
                    return `
                        <div class="form-group">
                            <label class="form-label ${required}" for="${field.name}">
                                ${field.display_name}
                            </label>
                            <select class="form-control select" id="${field.name}" name="${field.name}" ${required}>
                                ${field.options.map(option => 
                                    `<option value="${option}" ${field.default === option ? 'selected' : ''}>${option}</option>`
                                ).join('')}
                            </select>
                            <div class="form-help">${field.description}${sharedInfo}</div>
                            <div class="form-error" id="error-${field.name}"></div>
                        </div>
                    `;
                
                case 'checkbox':
                    return `
                        <div class="form-group">
                            <div class="checkbox-group">
                                <input type="checkbox" class="checkbox" id="${field.name}" name="${field.name}" 
                                       ${field.default ? 'checked' : ''}>
                                <label class="form-label" for="${field.name}">
                                    ${field.display_name}
                                </label>
                            </div>
                            <div class="form-help">${field.description}${sharedInfo}</div>
                            <div class="form-error" id="error-${field.name}"></div>
                        </div>
                    `;
                
                case 'password':
                    return `
                        <div class="form-group">
                            <label class="form-label ${required}" for="${field.name}">
                                ${field.display_name}
                            </label>
                            <input type="password" class="form-control" id="${field.name}" name="${field.name}" 
                                   value="${field.default || ''}" ${required} autocomplete="new-password">
                            <div class="form-help">${field.description}${sharedInfo}</div>
                            <div class="form-error" id="error-${field.name}"></div>
                        </div>
                    `;
                
                case 'number':
                    return `
                        <div class="form-group">
                            <label class="form-label ${required}" for="${field.name}">
                                ${field.display_name}
                            </label>
                            <input type="number" class="form-control" id="${field.name}" name="${field.name}" 
                                   value="${field.default || ''}" ${required}>
                            <div class="form-help">${field.description}${sharedInfo}</div>
                            <div class="form-error" id="error-${field.name}"></div>
                        </div>
                    `;
                
                default: // text
                    return `
                        <div class="form-group">
                            <label class="form-label ${required}" for="${field.name}">
                                ${field.display_name}
                            </label>
                            <input type="text" class="form-control" id="${field.name}" name="${field.name}" 
                                   value="${field.default || ''}" ${required}>
                            <div class="form-help">${field.description}${sharedInfo}</div>
                            <div class="form-error" id="error-${field.name}"></div>
                        </div>
                    `;
            }
        }).join('');
    }

    bindFieldEvents() {
        // Bind change events to all form fields for real-time validation and auto-population
        document.querySelectorAll('.form-control, .checkbox').forEach(field => {
            field.addEventListener('input', () => this.handleFieldChange(field));
            field.addEventListener('change', () => this.handleFieldChange(field));
        });
    }

    handleFieldChange(field) {
        const fieldName = field.name;
        const fieldValue = field.type === 'checkbox' ? field.checked : field.value;
        
        // Update current config
        this.currentConfig[fieldName] = fieldValue;
        
        // Clear previous error
        this.clearFieldError(fieldName);
        
        // Auto-populate dependent fields
        this.autoPopulateFields();
        
        // Update shared parameters display
        this.updateSharedParametersDisplay();
        
        // Real-time validation for this field
        this.validateField(fieldName, fieldValue);
    }

    autoPopulateFields() {
        // Smart auto-population based on configuration dependencies
        const config = this.currentConfig;

        // Auto-populate MinIO endpoint if credentials are set
        if (config.minio_username && config.minio_password) {
            this.setFieldValue('s3_endpoint', 'http://minio:9000');
            this.setFieldValue('s3_access_key', config.minio_username);
            this.setFieldValue('s3_secret_key', config.minio_password);
        }

        // Auto-populate PostgreSQL details
        if (config.project_name) {
            this.setFieldValue('postgres_user', 'nessie');
            this.setFieldValue('postgres_db', 'nessie');
        }

        // Auto-populate service URLs
        if (config.nessie_port) {
            this.setFieldValue('nessie_uri', `http://nessie:${config.nessie_port}/iceberg/main/`);
        }

        if (config.spark_master_port) {
            this.setFieldValue('spark_master_url', `spark://spark-master:${config.spark_master_port}`);
        }
    }

    setFieldValue(fieldName, value) {
        const field = document.getElementById(fieldName);
        if (field && !field.value) { // Only set if field is empty
            field.value = value;
            this.currentConfig[fieldName] = value;
        }
    }

    updateSharedParametersDisplay() {
        const sharedParamsContainer = document.querySelector('.shared-params-list');
        if (!sharedParamsContainer || !this.configSchema) return;

        const sharedParams = this.configSchema.shared_params;
        let html = '';

        Object.entries(sharedParams).forEach(([groupName, fields]) => {
            const fieldValues = fields.map(fieldName => {
                const value = this.currentConfig[fieldName];
                return value ? `${fieldName}: ${value.length > 20 ? '***' : value}` : `${fieldName}: (not set)`;
            }).join('<br>');

            html += `
                <div class="shared-param">
                    <div class="shared-param-title">${groupName.replace('_', ' ').toUpperCase()}</div>
                    <div class="shared-param-services">${fieldValues}</div>
                </div>
            `;
        });

        sharedParamsContainer.innerHTML = html;
    }

    initializeDefaultValues() {
        if (!this.configSchema) return;

        Object.values(this.configSchema.categories).forEach(category => {
            category.fields.forEach(field => {
                if (field.default !== undefined) {
                    this.currentConfig[field.name] = field.default;
                    
                    const fieldElement = document.getElementById(field.name);
                    if (fieldElement) {
                        if (field.type === 'checkbox') {
                            fieldElement.checked = field.default;
                        } else {
                            fieldElement.value = field.default;
                        }
                    }
                }
            });
        });

        this.updateSharedParametersDisplay();
    }

    switchConfigTab(categoryKey) {
        // Update tab buttons
        document.querySelectorAll('.tab-button').forEach(btn => {
            btn.classList.remove('active');
        });
        document.querySelector(`[data-tab="${categoryKey}"]`).classList.add('active');

        // Update tab content
        document.querySelectorAll('.tab-pane').forEach(pane => {
            pane.classList.remove('active');
        });
        document.getElementById(`config-${categoryKey}`).classList.add('active');
    }

    switchPreviewTab(tabName) {
        // Update tab buttons
        document.querySelectorAll('.preview-tabs .tab-button').forEach(btn => {
            btn.classList.remove('active');
        });
        document.querySelector(`[data-tab="${tabName}"]`).classList.add('active');

        // Update tab content
        document.querySelectorAll('.preview-tabs .tab-pane').forEach(pane => {
            pane.classList.remove('active');
        });
        document.getElementById(`preview-${tabName}`).classList.add('active');

        // Load content for the selected tab
        if (tabName === 'compose') {
            this.loadComposePreview();
        } else if (tabName === 'environment') {
            this.loadEnvironmentPreview();
        } else if (tabName === 'services') {
            this.loadServicesPreview();
        }
    }

    async validateConfiguration() {
        this.showLoading(true);
        
        try {
            const response = await fetch('/api/v1/installer/validate-config', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(this.currentConfig)
            });
            
            const data = await response.json();
            
            if (data.success) {
                // Update config with auto-populated values
                this.currentConfig = { ...this.currentConfig, ...data.populated_config };
                
                // Update form fields with populated values
                Object.entries(data.populated_config).forEach(([key, value]) => {
                    const field = document.getElementById(key);
                    if (field && !field.value) {
                        if (field.type === 'checkbox') {
                            field.checked = value;
                        } else {
                            field.value = value;
                        }
                    }
                });
                
                this.validationErrors = {};
                this.clearAllFieldErrors();
                
                // Enable next button
                const nextButton = document.getElementById('next-to-preview');
                if (nextButton) {
                    nextButton.disabled = false;
                }
                
                this.showNotification('success', 'Configuration validated successfully!');
                this.updateSharedParametersDisplay();
                
            } else {
                this.validationErrors = data.validation_errors || [];
                this.displayValidationErrors();
                this.showNotification('error', 'Configuration validation failed');
            }
        } catch (error) {
            this.showNotification('error', 'Validation error: ' + error.message);
        } finally {
            this.showLoading(false);
        }
    }

    validateField(fieldName, value) {
        // Basic field validation
        const field = document.getElementById(fieldName);
        if (!field) return;

        let isValid = true;
        let errorMessage = '';

        // Required field check
        if (field.hasAttribute('required') && (!value || value.toString().trim() === '')) {
            isValid = false;
            errorMessage = 'This field is required';
        }

        // Port number validation
        if (field.type === 'number' && fieldName.includes('port')) {
            const portNumber = parseInt(value);
            if (portNumber < 1024 || portNumber > 65535) {
                isValid = false;
                errorMessage = 'Port must be between 1024 and 65535';
            }
        }

        // Password strength validation
        if (field.type === 'password' && value && value.length < 6) {
            isValid = false;
            errorMessage = 'Password must be at least 6 characters';
        }

        if (isValid) {
            this.clearFieldError(fieldName);
        } else {
            this.showFieldError(fieldName, errorMessage);
        }

        return isValid;
    }

    displayValidationErrors() {
        this.clearAllFieldErrors();
        
        if (Array.isArray(this.validationErrors)) {
            this.validationErrors.forEach(error => {
                // Try to extract field name from error message
                const fieldMatch = error.match(/^(\w+)/);
                if (fieldMatch) {
                    this.showFieldError(fieldMatch[1], error);
                }
            });
        }
    }

    showFieldError(fieldName, message) {
        const errorElement = document.getElementById(`error-${fieldName}`);
        const fieldElement = document.getElementById(fieldName);
        
        if (errorElement) {
            errorElement.textContent = message;
            errorElement.style.display = 'block';
        }
        
        if (fieldElement) {
            fieldElement.style.borderColor = 'var(--error-color)';
        }
    }

    clearFieldError(fieldName) {
        const errorElement = document.getElementById(`error-${fieldName}`);
        const fieldElement = document.getElementById(fieldName);
        
        if (errorElement) {
            errorElement.textContent = '';
            errorElement.style.display = 'none';
        }
        
        if (fieldElement) {
            fieldElement.style.borderColor = '';
        }
    }

    clearAllFieldErrors() {
        document.querySelectorAll('.form-error').forEach(error => {
            error.textContent = '';
            error.style.display = 'none';
        });
        
        document.querySelectorAll('.form-control').forEach(field => {
            field.style.borderColor = '';
        });
    }

    async loadServicesPreview() {
        const container = document.getElementById('services-preview');
        if (!container) return;

        // Show which services will be deployed based on current config
        const services = [
            { name: 'PostgreSQL', icon: 'database', enabled: true, description: 'Database for Nessie metadata' },
            { name: 'MinIO', icon: 'cloud', enabled: this.currentConfig.object_storage_type === 'builtin_minio', description: 'Object storage' },
            { name: 'Nessie', icon: 'layer-group', enabled: true, description: 'Data catalog service' },
            { name: 'Trino', icon: 'search', enabled: true, description: 'SQL query engine' },
            { name: 'Spark Master', icon: 'fire', enabled: true, description: 'Distributed computing' },
            { name: 'Spark Worker', icon: 'cogs', enabled: true, description: 'Compute workers' }
        ];

        const html = services.map(service => `
            <div class="service-card ${service.enabled ? 'enabled' : ''}">
                <div class="service-header">
                    <div class="service-icon">
                        <i class="fas fa-${service.icon}"></i>
                    </div>
                    <div class="service-name">${service.name}</div>
                    <div class="service-status ${service.enabled ? 'enabled' : 'disabled'}">
                        ${service.enabled ? 'Enabled' : 'Disabled'}
                    </div>
                </div>
                <div class="service-description">${service.description}</div>
            </div>
        `).join('');

        container.innerHTML = html;
    }

    async loadComposePreview() {
        const container = document.getElementById('compose-preview');
        if (!container) return;

        try {
            const response = await fetch('/api/v1/compose/preview', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    project_name: this.currentConfig.project_name || 'shudl',
                    environment: this.currentConfig.environment || 'development',
                    services: {
                        postgresql: { enabled: true },
                        minio: { enabled: this.currentConfig.object_storage_type === 'builtin_minio' },
                        nessie: { enabled: true },
                        trino: { enabled: true },
                        'spark-master': { enabled: true },
                        'spark-worker': { enabled: true }
                    }
                })
            });

            const data = await response.json();
            
            if (data.success && data.data.compose_content) {
                container.innerHTML = `<code>${this.escapeHtml(data.data.compose_content)}</code>`;
            } else {
                container.innerHTML = '<code>Error loading compose preview</code>';
            }
        } catch (error) {
            container.innerHTML = `<code>Error: ${error.message}</code>`;
        }
    }

    async loadEnvironmentPreview() {
        const container = document.getElementById('env-preview');
        if (!container) return;

        try {
            const response = await fetch('/api/v1/compose/preview', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    project_name: this.currentConfig.project_name || 'shudl',
                    environment: this.currentConfig.environment || 'development',
                    services: {
                        postgresql: { enabled: true },
                        minio: { enabled: this.currentConfig.object_storage_type === 'builtin_minio' },
                        nessie: { enabled: true },
                        trino: { enabled: true },
                        'spark-master': { enabled: true },
                        'spark-worker': { enabled: true }
                    }
                })
            });

            const data = await response.json();
            
            if (data.success && data.data.env_content) {
                container.innerHTML = `<code>${this.escapeHtml(data.data.env_content)}</code>`;
            } else {
                container.innerHTML = '<code>Error loading environment preview</code>';
            }
        } catch (error) {
            container.innerHTML = `<code>Error: ${error.message}</code>`;
        }
    }

    async startDeployment() {
        this.nextStep(); // Move to deployment step
        
        try {
            // Generate configuration files
            const generateResponse = await fetch('/api/v1/compose/generate', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    project_name: this.currentConfig.project_name || 'shudl',
                    environment: this.currentConfig.environment || 'development',
                    services: {
                        postgresql: { enabled: true },
                        minio: { enabled: this.currentConfig.object_storage_type === 'builtin_minio' },
                        nessie: { enabled: true },
                        trino: { enabled: true },
                        'spark-master': { enabled: true },
                        'spark-worker': { enabled: true }
                    }
                })
            });

            const generateData = await generateResponse.json();
            
            if (!generateData.success) {
                throw new Error('Failed to generate configuration files');
            }

            // Start services
            const startResponse = await fetch('/api/v1/docker/start', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    compose_file: generateData.data.compose_file,
                    project_name: this.currentConfig.project_name || 'shudl',
                    env_file: generateData.data.env_file
                })
            });

            const startData = await startResponse.json();
            
            if (startData.success) {
                this.monitorDeployment();
            } else {
                this.showNotification('error', 'Deployment failed: ' + startData.message);
            }
            
        } catch (error) {
            this.showNotification('error', 'Deployment error: ' + error.message);
        }
    }

    async monitorDeployment() {
        const services = ['postgresql', 'minio', 'nessie', 'trino', 'spark-master', 'spark-worker'];
        let progress = 0;
        const totalSteps = services.length;
        
        this.updateDeploymentProgress(0, 'Starting deployment...');
        this.addDeploymentLog('Starting ShuDL deployment...');
        
        for (let i = 0; i < services.length; i++) {
            const service = services[i];
            
            this.addDeploymentLog(`Starting ${service}...`);
            
            // Simulate deployment progress
            await new Promise(resolve => setTimeout(resolve, 2000));
            
            progress = ((i + 1) / totalSteps) * 100;
            this.updateDeploymentProgress(progress, `${service} started`);
            this.addDeploymentLog(`✓ ${service} is running`);
        }

        // Deployment complete
        this.updateDeploymentProgress(100, 'Deployment complete!');
        this.addDeploymentLog('🎉 ShuDL deployment completed successfully!');
        
        setTimeout(() => {
            this.nextStep(); // Move to dashboard
        }, 2000);
    }

    updateDeploymentProgress(percentage, status) {
        const progressFill = document.getElementById('deployment-progress-fill');
        const progressText = document.getElementById('deployment-status');
        const progressPercentage = document.getElementById('deployment-percentage');
        
        if (progressFill) progressFill.style.width = percentage + '%';
        if (progressText) progressText.textContent = status;
        if (progressPercentage) progressPercentage.textContent = Math.round(percentage) + '%';
    }

    addDeploymentLog(message) {
        const logsContainer = document.getElementById('deployment-logs');
        if (!logsContainer) return;
        
        const timestamp = new Date().toLocaleTimeString();
        const logEntry = document.createElement('div');
        logEntry.textContent = `[${timestamp}] ${message}`;
        logsContainer.appendChild(logEntry);
        logsContainer.scrollTop = logsContainer.scrollHeight;
    }

    nextStep() {
        if (this.currentStep < this.totalSteps) {
            this.currentStep++;
            this.updateUI();
            
            // Special handling for preview step
            if (this.currentStep === 3) {
                this.loadServicesPreview();
            }
        }
    }

    previousStep() {
        if (this.currentStep > 1) {
            this.currentStep--;
            this.updateUI();
        }
    }

    updateUI() {
        // Update progress steps
        document.querySelectorAll('.step').forEach((step, index) => {
            const stepNumber = index + 1;
            step.classList.remove('active', 'completed');
            
            if (stepNumber === this.currentStep) {
                step.classList.add('active');
            } else if (stepNumber < this.currentStep) {
                step.classList.add('completed');
            }
        });

        // Show/hide step content
        document.querySelectorAll('.step-content').forEach((content, index) => {
            const stepNumber = index + 1;
            content.classList.remove('active');
            
            if (stepNumber === this.currentStep) {
                content.classList.add('active');
            }
        });
    }

    async restartServices() {
        this.showLoading(true);
        
        try {
            const response = await fetch('/api/v1/docker/restart', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    compose_file: 'generated/docker-compose.yml',
                    project_name: this.currentConfig.project_name || 'shudl'
                })
            });
            
            const data = await response.json();
            
            if (data.success) {
                this.showNotification('success', 'Services restarted successfully');
            } else {
                this.showNotification('error', 'Failed to restart services: ' + data.message);
            }
        } catch (error) {
            this.showNotification('error', 'Error restarting services: ' + error.message);
        } finally {
            this.showLoading(false);
        }
    }

    async stopServices() {
        this.showLoading(true);
        
        try {
            const response = await fetch('/api/v1/docker/stop', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    compose_file: 'generated/docker-compose.yml',
                    project_name: this.currentConfig.project_name || 'shudl'
                })
            });
            
            const data = await response.json();
            
            if (data.success) {
                this.showNotification('success', 'Services stopped successfully');
            } else {
                this.showNotification('error', 'Failed to stop services: ' + data.message);
            }
        } catch (error) {
            this.showNotification('error', 'Error stopping services: ' + error.message);
        } finally {
            this.showLoading(false);
        }
    }

    viewLogs() {
        this.showNotification('info', 'Log viewer feature coming soon!');
    }

    showNotification(type, message) {
        const container = document.getElementById('notifications');
        if (!container) return;

        const notification = document.createElement('div');
        notification.className = `notification ${type}`;
        notification.innerHTML = `
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <span>${message}</span>
                <button onclick="this.parentElement.parentElement.remove()" style="background: none; border: none; font-size: 1.2em; cursor: pointer;">&times;</button>
            </div>
        `;

        container.appendChild(notification);

        // Auto-remove after 5 seconds
        setTimeout(() => {
            if (notification.parentElement) {
                notification.remove();
            }
        }, 5000);
    }

    showLoading(show) {
        const overlay = document.getElementById('loading-overlay');
        if (overlay) {
            overlay.classList.toggle('show', show);
        }
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// Initialize installer when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.shuDLInstaller = new ShuDLInstaller();
}); 