/**
 * Step Controller Component
 * Manages multi-step installer navigation
 */

export class StepController {
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