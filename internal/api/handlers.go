package api

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/shudl/shudl/internal/docker"
	"github.com/shudl/shudl/internal/logger"
)

// Handler holds the API handlers
type Handler struct {
	dockerService *docker.Service
	logger        *logger.Logger
}

// NewHandler creates a new API handler
func NewHandler(dockerService *docker.Service, log *logger.Logger) *Handler {
	return &Handler{
		dockerService: dockerService,
		logger:        log.WithComponent("api-handler"),
	}
}

// APIResponse represents a standard API response
type APIResponse struct {
	Success bool        `json:"success"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
}

// StartServicesRequest represents the request body for starting services
type StartServicesRequest struct {
	ComposeFile string            `json:"compose_file,omitempty"`
	ProjectName string            `json:"project_name,omitempty"`
	Environment map[string]string `json:"environment,omitempty"`
	Services    []string          `json:"services,omitempty"`
}

// @Summary Start Docker services
// @Description Start Docker services using docker-compose
// @Tags docker
// @Accept json
// @Produce json
// @Param request body StartServicesRequest true "Service configuration"
// @Success 200 {object} APIResponse{data=docker.OperationResult}
// @Failure 400 {object} APIResponse
// @Failure 500 {object} APIResponse
// @Router /api/v1/docker/start [post]
func (h *Handler) StartServices(c *gin.Context) {
	var req StartServicesRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.LogError(err, "Invalid request body", map[string]interface{}{
			"endpoint": "/api/v1/docker/start",
		})
		c.JSON(http.StatusBadRequest, APIResponse{
			Success: false,
			Message: "Invalid request body",
			Error:   err.Error(),
		})
		return
	}

	serviceConfig := docker.ServiceConfig{
		ComposeFile: req.ComposeFile,
		ProjectName: req.ProjectName,
		Environment: req.Environment,
		Services:    req.Services,
	}

	result, err := h.dockerService.Start(c.Request.Context(), serviceConfig)
	if err != nil {
		h.logger.LogError(err, "Failed to start services", map[string]interface{}{
			"config": serviceConfig,
		})
		c.JSON(http.StatusInternalServerError, APIResponse{
			Success: false,
			Message: "Failed to start services",
			Error:   err.Error(),
		})
		return
	}

	statusCode := http.StatusOK
	if !result.Success {
		statusCode = http.StatusInternalServerError
	}

	c.JSON(statusCode, APIResponse{
		Success: result.Success,
		Message: result.Message,
		Data:    result,
	})
}

// @Summary Stop Docker services
// @Description Stop Docker services using docker-compose
// @Tags docker
// @Accept json
// @Produce json
// @Param request body StartServicesRequest true "Service configuration"
// @Success 200 {object} APIResponse{data=docker.OperationResult}
// @Failure 400 {object} APIResponse
// @Failure 500 {object} APIResponse
// @Router /api/v1/docker/stop [post]
func (h *Handler) StopServices(c *gin.Context) {
	var req StartServicesRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.LogError(err, "Invalid request body", map[string]interface{}{
			"endpoint": "/api/v1/docker/stop",
		})
		c.JSON(http.StatusBadRequest, APIResponse{
			Success: false,
			Message: "Invalid request body",
			Error:   err.Error(),
		})
		return
	}

	serviceConfig := docker.ServiceConfig{
		ComposeFile: req.ComposeFile,
		ProjectName: req.ProjectName,
		Environment: req.Environment,
		Services:    req.Services,
	}

	result, err := h.dockerService.Stop(c.Request.Context(), serviceConfig)
	if err != nil {
		h.logger.LogError(err, "Failed to stop services", map[string]interface{}{
			"config": serviceConfig,
		})
		c.JSON(http.StatusInternalServerError, APIResponse{
			Success: false,
			Message: "Failed to stop services",
			Error:   err.Error(),
		})
		return
	}

	statusCode := http.StatusOK
	if !result.Success {
		statusCode = http.StatusInternalServerError
	}

	c.JSON(statusCode, APIResponse{
		Success: result.Success,
		Message: result.Message,
		Data:    result,
	})
}

// @Summary Restart Docker services
// @Description Restart Docker services using docker-compose
// @Tags docker
// @Accept json
// @Produce json
// @Param request body StartServicesRequest true "Service configuration"
// @Success 200 {object} APIResponse{data=docker.OperationResult}
// @Failure 400 {object} APIResponse
// @Failure 500 {object} APIResponse
// @Router /api/v1/docker/restart [post]
func (h *Handler) RestartServices(c *gin.Context) {
	var req StartServicesRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.LogError(err, "Invalid request body", map[string]interface{}{
			"endpoint": "/api/v1/docker/restart",
		})
		c.JSON(http.StatusBadRequest, APIResponse{
			Success: false,
			Message: "Invalid request body",
			Error:   err.Error(),
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
		c.JSON(http.StatusInternalServerError, APIResponse{
			Success: false,
			Message: "Failed to restart services",
			Error:   err.Error(),
		})
		return
	}

	statusCode := http.StatusOK
	if !result.Success {
		statusCode = http.StatusInternalServerError
	}

	c.JSON(statusCode, APIResponse{
		Success: result.Success,
		Message: result.Message,
		Data:    result,
	})
}

// @Summary Cleanup Docker resources
// @Description Remove containers, networks, and volumes
// @Tags docker
// @Accept json
// @Produce json
// @Param request body StartServicesRequest true "Service configuration"
// @Success 200 {object} APIResponse{data=docker.OperationResult}
// @Failure 400 {object} APIResponse
// @Failure 500 {object} APIResponse
// @Router /api/v1/docker/cleanup [post]
func (h *Handler) CleanupServices(c *gin.Context) {
	var req StartServicesRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.LogError(err, "Invalid request body", map[string]interface{}{
			"endpoint": "/api/v1/docker/cleanup",
		})
		c.JSON(http.StatusBadRequest, APIResponse{
			Success: false,
			Message: "Invalid request body",
			Error:   err.Error(),
		})
		return
	}

	serviceConfig := docker.ServiceConfig{
		ComposeFile: req.ComposeFile,
		ProjectName: req.ProjectName,
		Environment: req.Environment,
		Services:    req.Services,
	}

	result, err := h.dockerService.Cleanup(c.Request.Context(), serviceConfig)
	if err != nil {
		h.logger.LogError(err, "Failed to cleanup services", map[string]interface{}{
			"config": serviceConfig,
		})
		c.JSON(http.StatusInternalServerError, APIResponse{
			Success: false,
			Message: "Failed to cleanup services",
			Error:   err.Error(),
		})
		return
	}

	statusCode := http.StatusOK
	if !result.Success {
		statusCode = http.StatusInternalServerError
	}

	c.JSON(statusCode, APIResponse{
		Success: result.Success,
		Message: result.Message,
		Data:    result,
	})
}

// @Summary Get Docker services status
// @Description Get the status of Docker services
// @Tags docker
// @Accept json
// @Produce json
// @Param compose_file query string false "Docker compose file path"
// @Param project_name query string false "Docker compose project name"
// @Success 200 {object} APIResponse{data=docker.OperationResult}
// @Failure 500 {object} APIResponse
// @Router /api/v1/docker/status [get]
func (h *Handler) GetServicesStatus(c *gin.Context) {
	serviceConfig := docker.ServiceConfig{
		ComposeFile: c.Query("compose_file"),
		ProjectName: c.Query("project_name"),
	}

	result, err := h.dockerService.Status(c.Request.Context(), serviceConfig)
	if err != nil {
		h.logger.LogError(err, "Failed to get services status", map[string]interface{}{
			"config": serviceConfig,
		})
		c.JSON(http.StatusInternalServerError, APIResponse{
			Success: false,
			Message: "Failed to get services status",
			Error:   err.Error(),
		})
		return
	}

	statusCode := http.StatusOK
	if !result.Success {
		statusCode = http.StatusInternalServerError
	}

	c.JSON(statusCode, APIResponse{
		Success: result.Success,
		Message: result.Message,
		Data:    result,
	})
}

// @Summary Validate Docker installation
// @Description Check if Docker and Docker Compose are available
// @Tags system
// @Produce json
// @Success 200 {object} APIResponse{data=docker.OperationResult}
// @Failure 500 {object} APIResponse
// @Router /api/v1/system/validate [get]
func (h *Handler) ValidateDockerInstallation(c *gin.Context) {
	result, err := h.dockerService.ValidateDockerInstallation(c.Request.Context())
	if err != nil {
		h.logger.LogError(err, "Failed to validate Docker installation", nil)
		c.JSON(http.StatusInternalServerError, APIResponse{
			Success: false,
			Message: "Failed to validate Docker installation",
			Error:   err.Error(),
		})
		return
	}

	statusCode := http.StatusOK
	if !result.Success {
		statusCode = http.StatusServiceUnavailable
	}

	c.JSON(statusCode, APIResponse{
		Success: result.Success,
		Message: result.Message,
		Data:    result,
	})
}

// @Summary Health check
// @Description Check if the API is healthy
// @Tags system
// @Produce json
// @Success 200 {object} APIResponse
// @Router /api/v1/health [get]
func (h *Handler) HealthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, APIResponse{
		Success: true,
		Message: "API is healthy",
		Data: map[string]interface{}{
			"status":    "healthy",
			"timestamp": strconv.FormatInt(c.Request.Context().Value("timestamp").(int64), 10),
		},
	})
} 