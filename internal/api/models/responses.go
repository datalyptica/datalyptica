package models

// TODO: Fix imports after restructure
// import (
//	"github.com/shudl/shudl/internal/services/compose"
//	"github.com/shudl/shudl/internal/services/docker"
// )

// HealthResponse represents a health check response
type HealthResponse struct {
	Status    string            `json:"status"`
	Timestamp string            `json:"timestamp"`
	Version   string            `json:"version"`
	Services  map[string]string `json:"services,omitempty"`
}

// ValidationResponse represents a validation response
type ValidationResponse struct {
	Valid   bool                   `json:"valid"`
	Errors  []string               `json:"errors,omitempty"`
	Details map[string]interface{} `json:"details,omitempty"`
}

// GenerationResponse represents the response after generating files
type GenerationResponse struct {
	ComposeFile    string `json:"compose_file"`
	EnvFile        string `json:"env_file"`
	ComposeContent string `json:"compose_content,omitempty"`
	EnvContent     string `json:"env_content,omitempty"`
}

// ServiceStatusResponse represents the status of services
type ServiceStatusResponse struct {
	ProjectName string        `json:"project_name"`
	Services    []interface{} `json:"services"` // TODO: Fix type after import
	Summary     interface{}   `json:"summary"`  // TODO: Fix type after import
}

// DeploymentResponse represents a deployment operation response
type DeploymentResponse struct {
	Success     bool                 `json:"success"`
	Message     string               `json:"message"`
	ProjectName string               `json:"project_name"`
	Services    []string             `json:"services"`
	Status      interface{}          `json:"status"` // TODO: Fix type after import
	HealthCheck *HealthCheckResponse `json:"health_check,omitempty"`
}

// HealthCheckResponse represents detailed health check results
type HealthCheckResponse struct {
	Overall  string                           `json:"overall"`
	Services map[string]ServiceHealthResponse `json:"services"`
	Duration string                           `json:"duration"`
}

// ServiceHealthResponse represents individual service health
type ServiceHealthResponse struct {
	Status    string `json:"status"`
	Message   string `json:"message,omitempty"`
	Uptime    string `json:"uptime,omitempty"`
	LastCheck string `json:"last_check"`
}

// ConfigurationResponse represents configuration data
type ConfigurationResponse struct {
	ProjectName     string                 `json:"project_name"`
	Environment     string                 `json:"environment"`
	Services        map[string]interface{} `json:"services"`                  // TODO: Fix type after import
	DefaultConfigs  interface{}            `json:"default_configs,omitempty"` // TODO: Fix type after import
	ValidationRules map[string]interface{} `json:"validation_rules,omitempty"`
}

// InstallationConfigResponse represents installation configuration
type InstallationConfigResponse struct {
	InstallationType string                 `json:"installation_type"`
	StorageType      string                 `json:"storage_type"`
	Categories       map[string]interface{} `json:"categories"`
	SharedParams     map[string]interface{} `json:"shared_params"`
	Dependencies     map[string][]string    `json:"dependencies"`
}

// ServiceListResponse represents a list of available services
type ServiceListResponse struct {
	Services   []ServiceInfo `json:"services"`
	Categories []string      `json:"categories"`
}

// ServiceInfo represents information about a service
type ServiceInfo struct {
	Name         string            `json:"name"`
	DisplayName  string            `json:"display_name"`
	Description  string            `json:"description"`
	Category     string            `json:"category"`
	Required     bool              `json:"required"`
	Dependencies []string          `json:"dependencies,omitempty"`
	Ports        []PortInfo        `json:"ports,omitempty"`
	Volumes      []string          `json:"volumes,omitempty"`
	Environment  map[string]string `json:"environment,omitempty"`
}

// PortInfo represents port configuration
type PortInfo struct {
	Internal int    `json:"internal"`
	External int    `json:"external"`
	Protocol string `json:"protocol,omitempty"`
}
