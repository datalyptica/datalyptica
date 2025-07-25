package docker

import (
	"fmt"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/shudl/shudl/internal/api/models"
	"github.com/shudl/shudl/internal/pkg/logger"
	"github.com/shudl/shudl/internal/pkg/utils"
	"github.com/shudl/shudl/internal/services/docker"
)

// Handler handles Docker service endpoints
type Handler struct {
	dockerService *docker.Service
	logger        *logger.Logger
}

// NewHandler creates a new Docker handler
func NewHandler(dockerService *docker.Service, log *logger.Logger) *Handler {
	return &Handler{
		dockerService: dockerService,
		logger:        log.WithComponent("docker-handler"),
	}
}

// @Summary Start Docker services
// @Description Start Docker services using docker-compose
// @Tags docker
// @Accept json
// @Produce json
// @Param request body models.StartServicesRequest true "Service configuration"
// @Success 200 {object} utils.APIResponse{data=models.DeploymentResponse}
// @Failure 400 {object} utils.APIResponse
// @Failure 500 {object} utils.APIResponse
// @Router /api/v1/docker/start [post]
func (h *Handler) StartServices(c *gin.Context) {
	var req models.StartServicesRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.LogError(err, "Invalid request body", map[string]interface{}{
			"endpoint": "/api/v1/docker/start",
		})
		utils.ValidationErrorResponse(c, "Invalid request body", map[string]interface{}{
			"error": err.Error(),
		})
		return
	}

	serviceConfig := docker.ServiceConfig{
		ComposeFile: req.ComposeFile,
		ProjectName: req.ProjectName,
		Environment: req.Environment,
		Services:    req.Services,
	}

	// Use generated compose file by default if none specified
	if serviceConfig.ComposeFile == "" {
		serviceConfig.ComposeFile = "generated/docker-compose.yml"
	}

	result, err := h.dockerService.Start(c.Request.Context(), serviceConfig)
	if err != nil {
		h.logger.LogError(err, "Failed to start services", map[string]interface{}{
			"config": serviceConfig,
		})
		utils.ErrorResponse(c, err)
		return
	}

	response := models.DeploymentResponse{
		Success:     result.Success,
		Message:     result.Message,
		ProjectName: req.ProjectName,
		Services:    req.Services,
		Status:      result,
	}

	if result.Success {
		utils.SuccessResponse(c, "Services started successfully", response)
	} else {
		// Create an error from the result if it's not successful
		err := fmt.Errorf("service start failed: %s", result.Error)
		utils.ErrorResponse(c, err)
	}
}

// @Summary Stop Docker services
// @Description Stop Docker services using docker-compose
// @Tags docker
// @Accept json
// @Produce json
// @Param request body models.StopServicesRequest true "Service configuration"
// @Success 200 {object} utils.APIResponse{data=models.DeploymentResponse}
// @Failure 400 {object} utils.APIResponse
// @Failure 500 {object} utils.APIResponse
// @Router /api/v1/docker/stop [post]
func (h *Handler) StopServices(c *gin.Context) {
	var req models.StopServicesRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.LogError(err, "Invalid request body", map[string]interface{}{
			"endpoint": "/api/v1/docker/stop",
		})
		utils.ValidationErrorResponse(c, "Invalid request body", map[string]interface{}{
			"error": err.Error(),
		})
		return
	}

	serviceConfig := docker.ServiceConfig{
		ProjectName: req.ProjectName,
		Services:    req.Services,
	}

	// Use generated compose file by default
	serviceConfig.ComposeFile = "generated/docker-compose.yml"

	result, err := h.dockerService.Stop(c.Request.Context(), serviceConfig)
	if err != nil {
		h.logger.LogError(err, "Failed to stop services", map[string]interface{}{
			"config": serviceConfig,
		})
		utils.ErrorResponse(c, err)
		return
	}

	response := models.DeploymentResponse{
		Success:     result.Success,
		Message:     result.Message,
		ProjectName: req.ProjectName,
		Services:    req.Services,
		Status:      result,
	}

	utils.SuccessResponse(c, "Services stopped successfully", response)
}

// @Summary Get service status
// @Description Get the status of Docker services
// @Tags docker
// @Produce json
// @Param project query string false "Project name"
// @Param compose_file query string false "Compose file path"
// @Success 200 {object} utils.APIResponse{data=models.ServiceStatusResponse}
// @Failure 500 {object} utils.APIResponse
// @Router /api/v1/docker/status [get]
func (h *Handler) GetStatus(c *gin.Context) {
	projectName := c.Query("project")
	composeFile := c.Query("compose_file")

	// Create service config with compose file
	serviceConfig := docker.ServiceConfig{
		ComposeFile: composeFile,
		ProjectName: projectName,
	}

	status, err := h.dockerService.GetStatus(c.Request.Context(), serviceConfig)
	if err != nil {
		h.logger.LogError(err, "Failed to get service status", map[string]interface{}{
			"project": projectName,
		})
		utils.ErrorResponse(c, err)
		return
	}

	// Convert services to interface{} slice
	services := make([]interface{}, len(status.Services))
	for i, svc := range status.Services {
		services[i] = svc
	}

	response := models.ServiceStatusResponse{
		ProjectName: projectName,
		Services:    services,
		Summary:     status.Summary,
	}

	utils.SuccessResponse(c, "Service status retrieved", response)
}

// @Summary Restart Docker services
// @Description Restart Docker services using docker-compose
// @Tags docker
// @Accept json
// @Produce json
// @Param request body models.StartServicesRequest true "Service configuration"
// @Success 200 {object} utils.APIResponse{data=models.DeploymentResponse}
// @Failure 400 {object} utils.APIResponse
// @Failure 500 {object} utils.APIResponse
// @Router /api/v1/docker/restart [post]
func (h *Handler) RestartServices(c *gin.Context) {
	var req models.StartServicesRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.LogError(err, "Invalid request body", map[string]interface{}{
			"endpoint": "/api/v1/docker/restart",
		})
		utils.ValidationErrorResponse(c, "Invalid request body", map[string]interface{}{
			"error": err.Error(),
		})
		return
	}

	serviceConfig := docker.ServiceConfig{
		ComposeFile: req.ComposeFile,
		ProjectName: req.ProjectName,
		Environment: req.Environment,
		Services:    req.Services,
	}

	result, err := h.dockerService.Restart(c.Request.Context(), serviceConfig)
	if err != nil {
		h.logger.LogError(err, "Failed to restart services", map[string]interface{}{
			"config": serviceConfig,
		})
		utils.ErrorResponse(c, err)
		return
	}

	response := models.DeploymentResponse{
		Success:     result.Success,
		Message:     result.Message,
		ProjectName: req.ProjectName,
		Services:    req.Services,
		Status:      result,
	}

	utils.SuccessResponse(c, "Services restarted successfully", response)
}

// @Summary Validate Docker installation
// @Description Validate that Docker and docker-compose are properly installed
// @Tags docker
// @Produce json
// @Success 200 {object} utils.APIResponse{data=models.ValidationResponse}
// @Failure 500 {object} utils.APIResponse
// @Router /api/v1/docker/validate [get]
func (h *Handler) ValidateInstallation(c *gin.Context) {
	result, err := h.dockerService.ValidateDockerInstallation(c.Request.Context())
	if err != nil {
		h.logger.LogError(err, "Docker validation failed", nil)
		utils.ErrorResponse(c, err)
		return
	}

	response := models.ValidationResponse{
		Valid:   result.Valid,
		Errors:  result.Errors,
		Details: result.Details,
	}

	if result.Valid {
		utils.SuccessResponse(c, "Docker installation is valid", response)
	} else {
		c.JSON(http.StatusBadRequest, utils.APIResponse{
			Success: false,
			Message: "Docker installation is invalid",
			Data:    response,
		})
	}
}

// @Summary Get Docker logs
// @Description Get logs from Docker services
// @Tags docker
// @Produce json
// @Param project query string false "Project name"
// @Param service query string false "Service name"
// @Param tail query int false "Number of lines to tail" default(100)
// @Success 200 {object} utils.APIResponse{data=map[string]interface{}}
// @Failure 500 {object} utils.APIResponse
// @Router /api/v1/docker/logs [get]
func (h *Handler) GetLogs(c *gin.Context) {
	projectName := c.Query("project")
	serviceName := c.Query("service")
	tailStr := c.DefaultQuery("tail", "100")

	tail, err := strconv.Atoi(tailStr)
	if err != nil {
		utils.ValidationErrorResponse(c, "Invalid tail parameter", map[string]interface{}{
			"tail": tailStr,
		})
		return
	}

	logs, err := h.dockerService.GetLogs(c.Request.Context(), projectName, serviceName, tail)
	if err != nil {
		h.logger.LogError(err, "Failed to get logs", map[string]interface{}{
			"project": projectName,
			"service": serviceName,
		})
		utils.ErrorResponse(c, err)
		return
	}

	utils.SuccessResponse(c, "Logs retrieved successfully", map[string]interface{}{
		"project": projectName,
		"service": serviceName,
		"logs":    logs,
	})
}
