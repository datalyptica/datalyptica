package compose

import (
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/shudl/shudl/internal/api/models"
	"github.com/shudl/shudl/internal/pkg/logger"
	"github.com/shudl/shudl/internal/pkg/utils"
	"github.com/shudl/shudl/internal/services/compose"
)

// Handler handles compose generation requests
type Handler struct {
	composeService *compose.Generator
	logger         *logger.Logger
}

// NewHandler creates a new compose handler
func NewHandler(outputDir string, log *logger.Logger) *Handler {
	return &Handler{
		composeService: compose.NewGenerator(outputDir, log),
		logger:         log.WithComponent("compose-handler"),
	}
}

// @Summary Get default configurations
// @Description Get preset configurations for development, production, and minimal setups
// @Tags compose
// @Produce json
// @Success 200 {object} utils.APIResponse{data=interface{}}
// @Router /api/v1/compose/defaults [get]
func (h *Handler) GetDefaultConfigurations(c *gin.Context) {
	defaults := h.composeService.GetDefaultConfigurations()

	utils.SuccessResponse(c, "Default configurations retrieved", defaults)
}

// @Summary Generate Docker Compose files
// @Description Generate docker-compose.yml and .env files from configuration
// @Tags compose
// @Accept json
// @Produce json
// @Param request body models.ConfigurationRequest true "Configuration data"
// @Success 200 {object} utils.APIResponse{data=models.GenerationResponse}
// @Failure 400 {object} utils.APIResponse
// @Failure 500 {object} utils.APIResponse
// @Router /api/v1/compose/generate [post]
func (h *Handler) GenerateFiles(c *gin.Context) {
	var req models.ConfigurationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.LogError(err, "Invalid configuration request", map[string]interface{}{
			"endpoint": "/api/v1/compose/generate",
		})
		utils.ValidationErrorResponse(c, "Invalid configuration request", map[string]interface{}{
			"error": err.Error(),
		})
		return
	}

	h.logger.LogInfo("Generating compose files", map[string]interface{}{
		"project_name": req.ProjectName,
		"environment":  req.Environment,
		"services":     len(req.Services),
	})

	result, err := h.composeService.GenerateFiles(req.ProjectName, req.NetworkName, req.Environment, req.Services, req.GlobalConfig)
	if err != nil {
		h.logger.LogError(err, "Failed to generate compose files", map[string]interface{}{
			"project_name": req.ProjectName,
		})
		utils.ErrorResponse(c, err)
		return
	}

	response := models.GenerationResponse{
		ComposeFile:    result.ComposeFile,
		EnvFile:        result.EnvFile,
		ComposeContent: result.ComposeContent,
		EnvContent:     result.EnvContent,
	}

	utils.SuccessResponse(c, "Compose files generated successfully", response)
}

// @Summary Validate configuration
// @Description Validate service configuration before generation
// @Tags compose
// @Accept json
// @Produce json
// @Param request body models.ValidateRequest true "Configuration to validate"
// @Success 200 {object} utils.APIResponse{data=models.ValidationResponse}
// @Failure 400 {object} utils.APIResponse
// @Router /api/v1/compose/validate [post]
func (h *Handler) ValidateConfiguration(c *gin.Context) {
	var req models.ValidateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.LogError(err, "Invalid validation request", map[string]interface{}{
			"endpoint": "/api/v1/compose/validate",
		})
		utils.ValidationErrorResponse(c, "Invalid validation request", map[string]interface{}{
			"error": err.Error(),
		})
		return
	}

	result, err := h.composeService.ValidateConfiguration(req.ProjectName, req.Services)
	if err != nil {
		h.logger.LogError(err, "Configuration validation failed", map[string]interface{}{
			"project_name": req.ProjectName,
		})
		utils.ErrorResponse(c, err)
		return
	}

	response := models.ValidationResponse{
		Valid:   result.Valid,
		Errors:  result.Errors,
		Details: result.Details,
	}

	if result.Valid {
		utils.SuccessResponse(c, "Configuration is valid", response)
	} else {
		c.JSON(http.StatusBadRequest, utils.APIResponse{
			Success: false,
			Message: "Configuration validation failed",
			Data:    response,
		})
	}
}

// @Summary Get service list
// @Description Get list of available services with their configurations
// @Tags compose
// @Produce json
// @Success 200 {object} utils.APIResponse{data=models.ServiceListResponse}
// @Router /api/v1/compose/services [get]
func (h *Handler) GetServices(c *gin.Context) {
	services := h.composeService.GetAvailableServices()

	// Convert services to models.ServiceInfo slice
	modelServices := make([]models.ServiceInfo, len(services.Services))
	for i, svc := range services.Services {
		modelServices[i] = models.ServiceInfo{
			Name:         svc.Name,
			DisplayName:  svc.DisplayName,
			Description:  svc.Description,
			Category:     svc.Category,
			Required:     svc.Required,
			Dependencies: svc.Dependencies,
			Ports: func() []models.PortInfo {
				ports := make([]models.PortInfo, len(svc.Ports))
				for j, port := range svc.Ports {
					ports[j] = models.PortInfo{
						Internal: port.Internal,
						External: port.External,
						Protocol: port.Protocol,
					}
				}
				return ports
			}(),
			Volumes:     svc.Volumes,
			Environment: svc.Environment,
		}
	}

	response := models.ServiceListResponse{
		Services:   modelServices,
		Categories: services.Categories,
	}

	utils.SuccessResponse(c, "Available services retrieved", response)
}

// @Summary Get service configuration template
// @Description Get configuration template for a specific service
// @Tags compose
// @Produce json
// @Param service path string true "Service name"
// @Success 200 {object} utils.APIResponse{data=interface{}}
// @Failure 404 {object} utils.APIResponse
// @Router /api/v1/compose/services/{service}/template [get]
func (h *Handler) GetServiceTemplate(c *gin.Context) {
	serviceName := c.Param("service")

	template, err := h.composeService.GetServiceTemplate(serviceName)
	if err != nil {
		h.logger.LogError(err, "Failed to get service template", map[string]interface{}{
			"service": serviceName,
		})
		utils.ErrorResponse(c, err)
		return
	}

	utils.SuccessResponse(c, fmt.Sprintf("Template for %s retrieved", serviceName), template)
}

// @Summary Preview generated configuration
// @Description Preview the Docker Compose configuration without writing files
// @Tags compose
// @Accept json
// @Produce json
// @Param request body models.ConfigurationRequest true "Configuration data"
// @Success 200 {object} utils.APIResponse{data=models.GenerationResponse}
// @Failure 400 {object} utils.APIResponse
// @Failure 500 {object} utils.APIResponse
// @Router /api/v1/compose/preview [post]
func (h *Handler) PreviewConfiguration(c *gin.Context) {
	var req models.ConfigurationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.LogError(err, "Invalid configuration request", map[string]interface{}{
			"endpoint": "/api/v1/compose/preview",
		})
		utils.ValidationErrorResponse(c, "Invalid configuration request", map[string]interface{}{
			"error": err.Error(),
		})
		return
	}

	h.logger.LogInfo("Previewing configuration", map[string]interface{}{
		"project_name": req.ProjectName,
		"environment":  req.Environment,
		"services":     len(req.Services),
	})

	result, err := h.composeService.PreviewConfiguration(req.ProjectName, req.NetworkName, req.Environment, req.Services, req.GlobalConfig)
	if err != nil {
		h.logger.LogError(err, "Failed to preview configuration", map[string]interface{}{
			"project_name": req.ProjectName,
		})
		utils.ErrorResponse(c, err)
		return
	}

	response := models.GenerationResponse{
		ComposeContent: result.ComposeContent,
		EnvContent:     result.EnvContent,
	}

	utils.SuccessResponse(c, "Configuration preview generated", response)
}
