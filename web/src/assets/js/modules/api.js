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
export const apiClient = new APIClient(); 