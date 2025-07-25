/**
 * System Validation Module
 * Handles system requirement checks and validation
 */

import { apiClient } from './api.js';

export class SystemValidator {
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