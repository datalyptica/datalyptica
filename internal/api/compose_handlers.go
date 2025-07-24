package api

import (
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/shudl/shudl/internal/compose"
	"github.com/shudl/shudl/internal/logger"
)

// ComposeHandler handles compose generation requests
type ComposeHandler struct {
	generator *compose.Generator
	logger    *logger.Logger
}

// NewComposeHandler creates a new compose handler
func NewComposeHandler(outputDir string, log *logger.Logger) *ComposeHandler {
	return &ComposeHandler{
		generator: compose.NewGenerator(outputDir, log),
		logger:    log.WithComponent("compose-handler"),
	}
}

// ConfigurationRequest represents a request to configure services
type ConfigurationRequest struct {
	ProjectName  string                          `json:"project_name" binding:"required"`
	NetworkName  string                          `json:"network_name"`
	Environment  string                          `json:"environment"`
	Services     map[string]*compose.ServiceConfig `json:"services" binding:"required"`
	GlobalConfig map[string]string               `json:"global_config,omitempty"`
}

// GenerationResponse represents the response after generating files
type GenerationResponse struct {
	ComposeFile    string `json:"compose_file"`
	EnvFile        string `json:"env_file"`
	ComposeContent string `json:"compose_content,omitempty"`
	EnvContent     string `json:"env_content,omitempty"`
}

// @Summary Get default configurations
// @Description Get preset configurations for development, production, and minimal setups
// @Tags compose
// @Produce json
// @Success 200 {object} APIResponse{data=compose.DefaultConfigurations}
// @Router /api/v1/compose/defaults [get]
func (h *ComposeHandler) GetDefaultConfigurations(c *gin.Context) {
	defaults := h.generator.GetDefaultConfigurations()
	
	h.logger.LogInfo("Retrieved default configurations", map[string]interface{}{
		"configurations": []string{"development", "production", "minimal"},
	})

	c.JSON(http.StatusOK, APIResponse{
		Success: true,
		Message: "Default configurations retrieved successfully",
		Data:    defaults,
	})
}

// @Summary Generate docker-compose files
// @Description Generate docker-compose.yml and .env files based on configuration
// @Tags compose
// @Accept json
// @Produce json
// @Param configuration body ConfigurationRequest true "Service configuration"
// @Success 200 {object} APIResponse{data=GenerationResponse}
// @Failure 400 {object} APIResponse
// @Failure 500 {object} APIResponse
// @Router /api/v1/compose/generate [post]
func (h *ComposeHandler) GenerateCompose(c *gin.Context) {
	var req ConfigurationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.LogError(err, "Invalid configuration request", map[string]interface{}{
			"endpoint": "/api/v1/compose/generate",
		})
		c.JSON(http.StatusBadRequest, APIResponse{
			Success: false,
			Message: "Invalid configuration request",
			Error:   err.Error(),
		})
		return
	}

	// Set defaults
	if req.NetworkName == "" {
		req.NetworkName = "shunetwork"
	}
	if req.Environment == "" {
		req.Environment = "development"
	}

	// Create compose configuration
	config := &compose.ComposeConfiguration{
		ProjectName:  req.ProjectName,
		NetworkName:  req.NetworkName,
		Environment:  req.Environment,
		Services:     req.Services,
		GlobalConfig: req.GlobalConfig,
	}

	h.logger.LogInfo("Generating compose files", map[string]interface{}{
		"project_name": config.ProjectName,
		"environment":  config.Environment,
		"services":     len(config.Services),
	})

	// Generate docker-compose.yml
	composeFile, err := h.generator.GenerateCompose(config)
	if err != nil {
		h.logger.LogError(err, "Failed to generate compose file", map[string]interface{}{
			"project_name": config.ProjectName,
		})
		c.JSON(http.StatusInternalServerError, APIResponse{
			Success: false,
			Message: "Failed to generate compose file",
			Error:   err.Error(),
		})
		return
	}

	// Generate .env file
	envFile, err := h.generator.GenerateEnvFile(config)
	if err != nil {
		h.logger.LogError(err, "Failed to generate env file", map[string]interface{}{
			"project_name": config.ProjectName,
		})
		c.JSON(http.StatusInternalServerError, APIResponse{
			Success: false,
			Message: "Failed to generate env file",
			Error:   err.Error(),
		})
		return
	}

	response := GenerationResponse{
		ComposeFile: composeFile,
		EnvFile:     envFile,
	}

	h.logger.LogInfo("Compose files generated successfully", map[string]interface{}{
		"compose_file": composeFile,
		"env_file":     envFile,
		"project_name": config.ProjectName,
	})

	c.JSON(http.StatusOK, APIResponse{
		Success: true,
		Message: "Compose files generated successfully",
		Data:    response,
	})
}

// @Summary Get available services
// @Description Get list of available services that can be configured
// @Tags compose
// @Produce json
// @Success 200 {object} APIResponse{data=map[string]interface{}}
// @Router /api/v1/compose/services [get]
func (h *ComposeHandler) GetAvailableServices(c *gin.Context) {
	services := map[string]interface{}{
		"minio": map[string]interface{}{
			"name":        "MinIO Object Storage",
			"description": "S3-compatible object storage for data lake",
			"ports":       []string{"9000", "9001"},
			"required":    true,
			"category":    "storage",
		},
		"postgresql": map[string]interface{}{
			"name":        "PostgreSQL Database",
			"description": "Relational database for metadata storage",
			"ports":       []string{"5432"},
			"required":    true,
			"category":    "database",
		},
		"nessie": map[string]interface{}{
			"name":        "Nessie Catalog",
			"description": "Git-like data version control and catalog",
			"ports":       []string{"19120"},
			"required":    true,
			"category":    "catalog",
			"depends_on":  []string{"postgresql", "minio"},
		},
		"trino": map[string]interface{}{
			"name":        "Trino Query Engine",
			"description": "Distributed SQL query engine",
			"ports":       []string{"8080"},
			"required":    false,
			"category":    "query-engine",
			"depends_on":  []string{"minio", "nessie"},
		},
		"spark-master": map[string]interface{}{
			"name":        "Spark Master",
			"description": "Apache Spark cluster master node",
			"ports":       []string{"4040", "7077"},
			"required":    false,
			"category":    "compute",
			"depends_on":  []string{"minio", "nessie"},
		},
		"spark-worker": map[string]interface{}{
			"name":        "Spark Worker",
			"description": "Apache Spark cluster worker node",
			"ports":       []string{"4040"},
			"required":    false,
			"category":    "compute",
			"depends_on":  []string{"spark-master"},
		},
	}

	c.JSON(http.StatusOK, APIResponse{
		Success: true,
		Message: "Available services retrieved successfully",
		Data:    services,
	})
}

// @Summary Validate configuration
// @Description Validate a service configuration before generation
// @Tags compose
// @Accept json
// @Produce json
// @Param configuration body ConfigurationRequest true "Service configuration to validate"
// @Success 200 {object} APIResponse{data=map[string]interface{}}
// @Failure 400 {object} APIResponse
// @Router /api/v1/compose/validate [post]
func (h *ComposeHandler) ValidateConfiguration(c *gin.Context) {
	var req ConfigurationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, APIResponse{
			Success: false,
			Message: "Invalid configuration request",
			Error:   err.Error(),
		})
		return
	}

	// Validation logic
	validationResult := h.validateConfiguration(&req)

	if !validationResult.Valid {
		c.JSON(http.StatusBadRequest, APIResponse{
			Success: false,
			Message: "Configuration validation failed",
			Data:    validationResult,
		})
		return
	}

	c.JSON(http.StatusOK, APIResponse{
		Success: true,
		Message: "Configuration is valid",
		Data:    validationResult,
	})
}

// @Summary Preview generated files
// @Description Preview the docker-compose.yml and .env files that would be generated
// @Tags compose
// @Accept json
// @Produce json
// @Param configuration body ConfigurationRequest true "Service configuration"
// @Success 200 {object} APIResponse{data=GenerationResponse}
// @Failure 400 {object} APIResponse
// @Router /api/v1/compose/preview [post]
func (h *ComposeHandler) PreviewGeneration(c *gin.Context) {
	var req ConfigurationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, APIResponse{
			Success: false,
			Message: "Invalid configuration request",
			Error:   err.Error(),
		})
		return
	}

	// Set defaults
	if req.NetworkName == "" {
		req.NetworkName = "shunetwork"
	}
	if req.Environment == "" {
		req.Environment = "development"
	}

	// Create compose configuration
	config := &compose.ComposeConfiguration{
		ProjectName:  req.ProjectName,
		NetworkName:  req.NetworkName,
		Environment:  req.Environment,
		Services:     req.Services,
		GlobalConfig: req.GlobalConfig,
	}

	// Generate content without writing files
	composeContent := h.generator.BuildComposeContent(config)
	envContent := h.generator.BuildEnvContent(config)

	response := GenerationResponse{
		ComposeFile:    fmt.Sprintf("%s/docker-compose.yml", req.ProjectName),
		EnvFile:        fmt.Sprintf("%s/.env", req.ProjectName),
		ComposeContent: composeContent,
		EnvContent:     envContent,
	}

	c.JSON(http.StatusOK, APIResponse{
		Success: true,
		Message: "Preview generated successfully",
		Data:    response,
	})
}

// ValidationResult represents the result of configuration validation
type ValidationResult struct {
	Valid    bool                   `json:"valid"`
	Errors   []string               `json:"errors,omitempty"`
	Warnings []string               `json:"warnings,omitempty"`
	Info     map[string]interface{} `json:"info,omitempty"`
}

// validateConfiguration validates a service configuration
func (h *ComposeHandler) validateConfiguration(req *ConfigurationRequest) *ValidationResult {
	result := &ValidationResult{
		Valid:    true,
		Errors:   []string{},
		Warnings: []string{},
		Info:     make(map[string]interface{}),
	}

	// Check project name
	if req.ProjectName == "" {
		result.Errors = append(result.Errors, "Project name is required")
		result.Valid = false
	}

	// Check if at least one service is enabled
	enabledServices := 0
	for _, service := range req.Services {
		if service.Enabled {
			enabledServices++
		}
	}

	if enabledServices == 0 {
		result.Errors = append(result.Errors, "At least one service must be enabled")
		result.Valid = false
	}

	// Check service dependencies
	for name, service := range req.Services {
		if service.Enabled {
			dependencies := h.getServiceDependencies(name)
			for _, dep := range dependencies {
				if depService, exists := req.Services[dep]; !exists || !depService.Enabled {
					result.Errors = append(result.Errors, 
						fmt.Sprintf("Service '%s' requires '%s' to be enabled", name, dep))
					result.Valid = false
				}
			}
		}
	}

	// Check for required services
	requiredServices := []string{"minio", "postgresql", "nessie"}
	for _, required := range requiredServices {
		if service, exists := req.Services[required]; !exists || !service.Enabled {
			result.Warnings = append(result.Warnings, 
				fmt.Sprintf("Service '%s' is recommended for a complete setup", required))
		}
	}

	// Add info
	result.Info["enabled_services"] = enabledServices
	result.Info["total_services"] = len(req.Services)

	return result
}

// getServiceDependencies returns dependencies for a service
func (h *ComposeHandler) getServiceDependencies(name string) []string {
	switch name {
	case "nessie":
		return []string{"postgresql", "minio"}
	case "trino":
		return []string{"minio", "nessie"}
	case "spark-master":
		return []string{"minio", "nessie"}
	case "spark-worker":
		return []string{"spark-master"}
	default:
		return []string{}
	}
} 