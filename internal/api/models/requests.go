package models

// import "github.com/shudl/shudl/internal/services/compose" // TODO: Fix import after restructure

// StartServicesRequest represents the request body for starting services
type StartServicesRequest struct {
	ComposeFile string            `json:"compose_file,omitempty"`
	ProjectName string            `json:"project_name,omitempty"`
	Environment map[string]string `json:"environment,omitempty"`
	Services    []string          `json:"services,omitempty"`
}

// StopServicesRequest represents the request body for stopping services
type StopServicesRequest struct {
	ProjectName string   `json:"project_name,omitempty"`
	Services    []string `json:"services,omitempty"`
	Timeout     int      `json:"timeout,omitempty"`
}

// ConfigurationRequest represents a request to configure services
type ConfigurationRequest struct {
	ProjectName  string                 `json:"project_name" binding:"required"`
	NetworkName  string                 `json:"network_name"`
	Environment  string                 `json:"environment"`
	Services     map[string]interface{} `json:"services" binding:"required"` // TODO: Fix type after import
	GlobalConfig map[string]string      `json:"global_config,omitempty"`
}

// ValidateRequest represents a validation request
type ValidateRequest struct {
	ProjectName string                 `json:"project_name" binding:"required"`
	Services    map[string]interface{} `json:"services" binding:"required"` // TODO: Fix type after import
}

// DeploymentRequest represents a deployment request
type DeploymentRequest struct {
	ProjectName   string            `json:"project_name" binding:"required"`
	ComposeFile   string            `json:"compose_file" binding:"required"`
	Environment   map[string]string `json:"environment,omitempty"`
	Services      []string          `json:"services,omitempty"`
	HealthCheck   bool              `json:"health_check,omitempty"`
	HealthTimeout int               `json:"health_timeout,omitempty"`
	DryRun        bool              `json:"dry_run,omitempty"`
}

// HealthCheckRequest represents a health check request
type HealthCheckRequest struct {
	Services []string `json:"services,omitempty"`
	Timeout  int      `json:"timeout,omitempty"`
}
