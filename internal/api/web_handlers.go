package api

import (
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/shudl/shudl/internal/logger"
)

// WebHandler handles web interface requests
type WebHandler struct {
	logger *logger.Logger
}

// NewWebHandler creates a new web handler
func NewWebHandler(log *logger.Logger) *WebHandler {
	return &WebHandler{
		logger: log,
	}
}

// InstallationConfig represents the dynamic configuration structure
type InstallationConfig struct {
	InstallationType string                 `json:"installation_type"` // "docker", "kubernetes"
	StorageType      string                 `json:"storage_type"`      // "builtin_minio", "external_s3"
	Categories       map[string]interface{} `json:"categories"`
	SharedParams     map[string]interface{} `json:"shared_params"`
	Dependencies     map[string][]string    `json:"dependencies"`
}

// ConfigCategory represents a configuration category
type ConfigCategory struct {
	Name        string                 `json:"name"`
	DisplayName string                 `json:"display_name"`
	Description string                 `json:"description"`
	Fields      []ConfigField          `json:"fields"`
	Conditions  map[string]interface{} `json:"conditions,omitempty"`
}

// ConfigField represents a configuration field
type ConfigField struct {
	Name         string      `json:"name"`
	DisplayName  string      `json:"display_name"`
	Type         string      `json:"type"` // "text", "password", "number", "select", "checkbox"
	Default      interface{} `json:"default,omitempty"`
	Required     bool        `json:"required"`
	Description  string      `json:"description"`
	Options      []string    `json:"options,omitempty"`       // For select fields
	DependsOn    []string    `json:"depends_on,omitempty"`    // Fields this depends on
	AutoPopulate string      `json:"auto_populate,omitempty"` // Auto-populate logic
	SharedWith   []string    `json:"shared_with,omitempty"`   // Components that share this value
}

// ServeInstaller serves the main installer page
func (h *WebHandler) ServeInstaller(c *gin.Context) {
	h.logger.LogInfo("Serving installer page", map[string]interface{}{
		"user_agent": c.GetHeader("User-Agent"),
		"ip":         c.ClientIP(),
	})

	data := gin.H{
		"Title":       "ShuDL Data Lakehouse Installer",
		"Version":     "v1.0.0",
		"Description": "Intelligent installer for ShuDL data lakehouse stack",
	}

	c.HTML(http.StatusOK, "index.html", data)
}

// GetConfigSchema returns the dynamic configuration schema
func (h *WebHandler) GetConfigSchema(c *gin.Context) {
	installationType := c.DefaultQuery("installation_type", "docker")

	schema := h.buildConfigSchema(installationType)

	h.logger.LogInfo("Generated config schema", map[string]interface{}{
		"installation_type": installationType,
		"categories_count":  len(schema.Categories),
	})

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    schema,
	})
}

// buildConfigSchema builds the dynamic configuration schema
func (h *WebHandler) buildConfigSchema(installationType string) *InstallationConfig {
	config := &InstallationConfig{
		InstallationType: installationType,
		Categories:       make(map[string]interface{}),
		SharedParams:     make(map[string]interface{}),
		Dependencies:     make(map[string][]string),
	}

	// Build categories based on installation type
	categories := []ConfigCategory{}

	// 1. Installation Type Category
	categories = append(categories, ConfigCategory{
		Name:        "installation",
		DisplayName: "Installation Type",
		Description: "Choose your installation method and target environment",
		Fields: []ConfigField{
			{
				Name:        "type",
				DisplayName: "Installation Method",
				Type:        "select",
				Default:     "docker",
				Required:    true,
				Description: "Choose how to deploy ShuDL",
				Options:     []string{"docker"},
			},
			{
				Name:        "project_name",
				DisplayName: "Project Name",
				Type:        "text",
				Default:     "shudl",
				Required:    true,
				Description: "Unique name for your ShuDL deployment",
			},
			{
				Name:        "environment",
				DisplayName: "Environment",
				Type:        "select",
				Default:     "development",
				Required:    true,
				Description: "Deployment environment affects default configurations",
				Options:     []string{"development", "production", "testing"},
			},
		},
	})

	// 2. Storage Configuration Category
	categories = append(categories, ConfigCategory{
		Name:        "storage",
		DisplayName: "Storage Configuration",
		Description: "Configure object storage and database settings",
		Fields: []ConfigField{
			{
				Name:        "object_storage_type",
				DisplayName: "Object Storage",
				Type:        "select",
				Default:     "builtin_minio",
				Required:    true,
				Description: "Choose object storage backend",
				Options:     []string{"builtin_minio", "external_s3", "external_minio"},
			},
			{
				Name:         "minio_username",
				DisplayName:  "MinIO Username",
				Type:         "text",
				Default:      "admin",
				Required:     true,
				Description:  "MinIO root username (shared with all components)",
				SharedWith:   []string{"minio", "nessie", "trino", "spark"},
				AutoPopulate: "minio_credentials",
			},
			{
				Name:         "minio_password",
				DisplayName:  "MinIO Password",
				Type:         "password",
				Required:     true,
				Description:  "MinIO root password (shared with all components)",
				SharedWith:   []string{"minio", "nessie", "trino", "spark"},
				AutoPopulate: "minio_credentials",
			},
		},
	})

	// 3. Network Configuration Category
	categories = append(categories, ConfigCategory{
		Name:        "network",
		DisplayName: "Network Configuration",
		Description: "Configure ports, networking, and connectivity",
		Fields: []ConfigField{
			{
				Name:        "network_name",
				DisplayName: "Docker Network Name",
				Type:        "text",
				Default:     "shunetwork",
				Required:    true,
				Description: "Docker network for service communication",
			},
			{
				Name:        "minio_api_port",
				DisplayName: "MinIO API Port",
				Type:        "number",
				Default:     9000,
				Required:    true,
				Description: "MinIO S3 API port",
			},
			{
				Name:        "minio_console_port",
				DisplayName: "MinIO Console Port",
				Type:        "number",
				Default:     9001,
				Required:    true,
				Description: "MinIO web console port",
			},
			{
				Name:        "nessie_port",
				DisplayName: "Nessie Catalog Port",
				Type:        "number",
				Default:     19120,
				Required:    true,
				Description: "Nessie catalog service port",
			},
			{
				Name:        "trino_port",
				DisplayName: "Trino Query Port",
				Type:        "number",
				Default:     8080,
				Required:    true,
				Description: "Trino query engine port",
			},
			{
				Name:        "spark_master_port",
				DisplayName: "Spark Master Port",
				Type:        "number",
				Default:     7077,
				Required:    true,
				Description: "Spark master coordination port",
			},
			{
				Name:        "spark_ui_port",
				DisplayName: "Spark UI Port",
				Type:        "number",
				Default:     4040,
				Required:    true,
				Description: "Spark web UI port",
			},
		},
	})

	// 4. Security Configuration Category
	categories = append(categories, ConfigCategory{
		Name:        "security",
		DisplayName: "Security Configuration",
		Description: "Configure authentication, passwords, and security settings",
		Fields: []ConfigField{
			{
				Name:         "postgres_password",
				DisplayName:  "PostgreSQL Password",
				Type:         "password",
				Required:     true,
				Description:  "PostgreSQL database password (shared with Nessie)",
				SharedWith:   []string{"postgresql", "nessie"},
				AutoPopulate: "database_credentials",
			},
			{
				Name:        "enable_cors",
				DisplayName: "Enable CORS",
				Type:        "checkbox",
				Default:     true,
				Description: "Enable Cross-Origin Resource Sharing for web access",
			},
		},
	})

	// 5. Performance Configuration Category
	categories = append(categories, ConfigCategory{
		Name:        "performance",
		DisplayName: "Performance & Resources",
		Description: "Configure memory, CPU, and performance settings",
		Fields: []ConfigField{
			{
				Name:        "spark_driver_memory",
				DisplayName: "Spark Driver Memory",
				Type:        "text",
				Default:     "1g",
				Description: "Memory allocation for Spark driver",
			},
			{
				Name:        "spark_executor_memory",
				DisplayName: "Spark Executor Memory",
				Type:        "text",
				Default:     "1g",
				Description: "Memory allocation for Spark executors",
			},
			{
				Name:        "trino_memory",
				DisplayName: "Trino Query Memory",
				Type:        "text",
				Default:     "2GB",
				Description: "Maximum memory for Trino queries",
			},
		},
	})

	// Convert categories to map
	for _, category := range categories {
		config.Categories[category.Name] = category
	}

	// Define dependencies
	config.Dependencies = map[string][]string{
		"nessie":       {"postgresql", "minio"},
		"trino":        {"nessie", "minio"},
		"spark-master": {"minio"},
		"spark-worker": {"spark-master", "minio"},
	}

	// Define shared parameters
	config.SharedParams = map[string]interface{}{
		"minio_credentials":    []string{"minio_username", "minio_password"},
		"database_credentials": []string{"postgres_password"},
		"network_settings":     []string{"network_name"},
	}

	return config
}

// ValidateConfig validates the configuration and auto-populates dependent fields
func (h *WebHandler) ValidateConfig(c *gin.Context) {
	var configData map[string]interface{}
	if err := c.ShouldBindJSON(&configData); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid configuration data",
			"error":   err.Error(),
		})
		return
	}

	// Auto-populate dependent configurations
	populatedConfig := h.autoPopulateConfig(configData)

	// Validate configuration
	validationErrors := h.validateConfigData(populatedConfig)

	h.logger.LogInfo("Configuration validation", map[string]interface{}{
		"has_errors":     len(validationErrors) > 0,
		"errors_count":   len(validationErrors),
		"auto_populated": len(populatedConfig) > len(configData),
	})

	response := gin.H{
		"success":           len(validationErrors) == 0,
		"populated_config":  populatedConfig,
		"validation_errors": validationErrors,
	}

	if len(validationErrors) > 0 {
		response["message"] = "Configuration validation failed"
	} else {
		response["message"] = "Configuration is valid"
	}

	c.JSON(http.StatusOK, response)
}

// autoPopulateConfig automatically populates dependent configuration fields
func (h *WebHandler) autoPopulateConfig(config map[string]interface{}) map[string]interface{} {
	populated := make(map[string]interface{})

	// Copy original config
	for k, v := range config {
		populated[k] = v
	}

	// Auto-populate MinIO URL if MinIO credentials are set
	if username, ok := config["minio_username"].(string); ok && username != "" {
		if password, ok := config["minio_password"].(string); ok && password != "" {
			// Auto-populate MinIO endpoint for other services
			populated["s3_endpoint"] = "http://minio:9000"
			populated["s3_access_key"] = username
			populated["s3_secret_key"] = password
			populated["s3_path_style_access"] = true
		}
	}

	// Auto-populate PostgreSQL details for Nessie
	if projectName, ok := config["project_name"].(string); ok {
		populated["postgres_user"] = "nessie"
		populated["postgres_db"] = "nessie"
		populated["compose_project_name"] = projectName
	}

	// Auto-populate Nessie URI for Trino and Spark
	if nessiePort, ok := config["nessie_port"].(float64); ok {
		populated["nessie_uri"] = fmt.Sprintf("http://nessie:%.0f/iceberg/main/", nessiePort)
	}

	// Auto-populate Spark Master URL
	if sparkPort, ok := config["spark_master_port"].(float64); ok {
		populated["spark_master_url"] = fmt.Sprintf("spark://spark-master:%.0f", sparkPort)
	}

	return populated
}

// validateConfigData validates configuration data
func (h *WebHandler) validateConfigData(config map[string]interface{}) []string {
	var errors []string

	// Required field validation
	requiredFields := []string{"project_name", "environment", "minio_username", "minio_password"}
	for _, field := range requiredFields {
		if value, ok := config[field]; !ok || value == "" {
			errors = append(errors, fmt.Sprintf("%s is required", field))
		}
	}

	// Port validation
	portFields := []string{"minio_api_port", "nessie_port", "trino_port", "spark_master_port"}
	for _, field := range portFields {
		if port, ok := config[field].(float64); ok {
			if port < 1024 || port > 65535 {
				errors = append(errors, fmt.Sprintf("%s must be between 1024 and 65535", field))
			}
		}
	}

	return errors
}
