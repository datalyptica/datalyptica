/**
 * Notification System Component
 * Handles toast notifications and user feedback
 */

export class NotificationManager {
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
export const notificationManager = new NotificationManager();

// Make it globally available for inline event handlers
window.notificationManager = notificationManager; 