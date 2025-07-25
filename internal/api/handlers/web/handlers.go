package web

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/shudl/shudl/internal/api/models"
	"github.com/shudl/shudl/internal/pkg/logger"
	"github.com/shudl/shudl/internal/pkg/utils"
)

// Handler handles web interface requests
type Handler struct {
	logger *logger.Logger
}

// NewHandler creates a new web handler
func NewHandler(log *logger.Logger) *Handler {
	return &Handler{
		logger: log.WithComponent("web-handler"),
	}
}

// @Summary Serve web interface
// @Description Serve the main web interface page
// @Tags web
// @Produce html
// @Success 200 {string} html "Main installer page"
// @Router / [get]
func (h *Handler) ServePage(c *gin.Context) {
	h.logger.LogInfo("Serving web interface", map[string]interface{}{
		"remote_addr": c.ClientIP(),
		"user_agent":  c.GetHeader("User-Agent"),
	})

	c.HTML(http.StatusOK, "index.html", gin.H{
		"Title":       "ShuDL Installer",
		"Version":     "1.0.0",
		"Description": "Deploy and manage your ShuDL infrastructure with ease",
	})
}

// @Summary Get installation configuration
// @Description Get dynamic configuration for the web installer interface
// @Tags web
// @Produce json
// @Success 200 {object} utils.APIResponse{data=models.InstallationConfigResponse}
// @Router /api/v1/web/config [get]
func (h *Handler) GetInstallationConfig(c *gin.Context) {
	h.logger.LogInfo("Installation config requested", map[string]interface{}{
		"remote_addr": c.ClientIP(),
	})

	config := h.generateInstallationConfig()

	utils.SuccessResponse(c, "Installation configuration retrieved", config)
}

// generateInstallationConfig creates the dynamic configuration for the installer
func (h *Handler) generateInstallationConfig() models.InstallationConfigResponse {
	return models.InstallationConfigResponse{
		InstallationType: "docker",
		StorageType:      "builtin_minio",
		Categories: map[string]interface{}{
			"infrastructure": map[string]interface{}{
				"name":        "Infrastructure Services",
				"description": "Core infrastructure components",
				"services":    []string{"postgresql", "minio", "nessie"},
				"required":    true,
			},
			"compute": map[string]interface{}{
				"name":        "Compute Engines",
				"description": "Data processing and query engines",
				"services":    []string{"trino", "spark"},
				"required":    false,
			},
			"monitoring": map[string]interface{}{
				"name":        "Monitoring & Observability",
				"description": "Monitoring and logging services",
				"services":    []string{"prometheus", "grafana"},
				"required":    false,
			},
		},
		SharedParams: map[string]interface{}{
			"project_name": map[string]interface{}{
				"type":         "text",
				"display_name": "Project Name",
				"description":  "Name for your ShuDL deployment",
				"default":      "shudl",
				"required":     true,
			},
			"environment": map[string]interface{}{
				"type":         "select",
				"display_name": "Environment",
				"description":  "Deployment environment",
				"options":      []string{"development", "production"},
				"default":      "development",
				"required":     true,
			},
		},
		Dependencies: map[string][]string{
			"nessie":  {"postgresql"},
			"trino":   {"nessie", "minio"},
			"spark":   {"nessie", "minio"},
			"grafana": {"prometheus"},
		},
	}
}

// @Summary Save user configuration
// @Description Save user's installation configuration
// @Tags web
// @Accept json
// @Produce json
// @Param config body models.ConfigurationRequest true "User configuration"
// @Success 200 {object} utils.APIResponse{data=interface{}}
// @Failure 400 {object} utils.APIResponse
// @Router /api/v1/web/save-config [post]
func (h *Handler) SaveConfiguration(c *gin.Context) {
	var config models.ConfigurationRequest
	if err := c.ShouldBindJSON(&config); err != nil {
		h.logger.LogError(err, "Invalid configuration data", map[string]interface{}{
			"endpoint": "/api/v1/web/save-config",
		})
		utils.ValidationErrorResponse(c, "Invalid configuration data", map[string]interface{}{
			"error": err.Error(),
		})
		return
	}

	h.logger.LogInfo("Configuration saved", map[string]interface{}{
		"project_name": config.ProjectName,
		"environment":  config.Environment,
		"services":     len(config.Services),
	})

	// TODO: Implement actual configuration persistence
	// For now, just acknowledge the save

	utils.SuccessResponse(c, "Configuration saved successfully", map[string]interface{}{
		"project_name": config.ProjectName,
		"saved_at":     "timestamp", // TODO: Add actual timestamp
	})
}

// @Summary Get deployment progress
// @Description Get the current deployment progress and status
// @Tags web
// @Produce json
// @Param project query string false "Project name"
// @Success 200 {object} utils.APIResponse{data=interface{}}
// @Router /api/v1/web/progress [get]
func (h *Handler) GetDeploymentProgress(c *gin.Context) {
	projectName := c.DefaultQuery("project", "shudl")

	h.logger.LogInfo("Deployment progress requested", map[string]interface{}{
		"project": projectName,
	})

	// TODO: Implement actual progress tracking
	progress := map[string]interface{}{
		"project":  projectName,
		"status":   "in_progress", // idle, in_progress, completed, failed
		"step":     "deploying",   // validating, generating, deploying, health_check
		"progress": 75,            // 0-100
		"message":  "Starting services...",
		"services": map[string]interface{}{
			"postgresql": "running",
			"minio":      "running",
			"nessie":     "starting",
			"trino":      "pending",
		},
	}

	utils.SuccessResponse(c, "Deployment progress retrieved", progress)
}
