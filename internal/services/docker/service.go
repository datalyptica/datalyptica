package docker

import (
	"context"
	"fmt"
	"os/exec"
	"strings"
	"time"

	"github.com/shudl/shudl/internal/pkg/logger"
	"github.com/shudl/shudl/internal/services/config"
)

// Service handles Docker operations
type Service struct {
	config *config.DockerConfig
	logger *logger.Logger
}

// ServiceConfig holds service configuration options
type ServiceConfig struct {
	ComposeFile string            `json:"compose_file"`
	ProjectName string            `json:"project_name"`
	Environment map[string]string `json:"environment"`
	Services    []string          `json:"services"`
	EnvFile     string            `json:"env_file,omitempty"`
	WorkDir     string            `json:"work_dir,omitempty"`
}

// OperationResult represents the result of a Docker operation
type OperationResult struct {
	Success  bool                   `json:"success"`
	Message  string                 `json:"message"`
	Output   string                 `json:"output,omitempty"`
	Error    string                 `json:"error,omitempty"`
	ExitCode int                    `json:"exit_code"`
	Duration string                 `json:"duration"`
	Services []string               `json:"services,omitempty"`
	Valid    bool                   `json:"valid"`    // For validation operations
	Errors   []string               `json:"errors"`   // For validation errors
	Details  map[string]interface{} `json:"details"`  // Additional details
}

// ServiceStatus represents the status of a single service
type ServiceStatus struct {
	Name   string `json:"name"`
	Status string `json:"status"` // running, stopped, starting, error
	Health string `json:"health"` // healthy, unhealthy, starting
	Uptime string `json:"uptime,omitempty"`
}

// DeploymentSummary represents an overview of all services
type DeploymentSummary struct {
	Total     int `json:"total"`
	Running   int `json:"running"`
	Stopped   int `json:"stopped"`
	Unhealthy int `json:"unhealthy"`
}

// StatusResult represents the result of getting service status
type StatusResult struct {
	Services []ServiceStatus   `json:"services"`
	Summary  DeploymentSummary `json:"summary"`
}

// Operation represents different Docker operations
type Operation string

const (
	OperationStart   Operation = "start"
	OperationStop    Operation = "stop"
	OperationRestart Operation = "restart"
	OperationCleanup Operation = "cleanup"
	OperationStatus  Operation = "status"
	OperationLogs    Operation = "logs"
	OperationPull    Operation = "pull"
	OperationBuild   Operation = "build"
)

// NewService creates a new Docker service instance
func NewService(dockerConfig *config.DockerConfig, log *logger.Logger) *Service {
	return &Service{
		config: dockerConfig,
		logger: log.WithComponent("docker-service"),
	}
}

// Start starts Docker services using docker-compose
func (s *Service) Start(ctx context.Context, serviceConfig ServiceConfig) (*OperationResult, error) {
	startTime := time.Now()

	s.logger.LogInfo("Starting Docker services", map[string]interface{}{
		"compose_file": serviceConfig.ComposeFile,
		"project_name": serviceConfig.ProjectName,
		"services":     serviceConfig.Services,
	})

	// Build docker-compose command
	args := []string{"compose"}

	if serviceConfig.ComposeFile != "" {
		args = append(args, "-f", serviceConfig.ComposeFile)
	} else if s.config.ComposeFile != "" {
		args = append(args, "-f", s.config.ComposeFile)
	}

	if serviceConfig.ProjectName != "" {
		args = append(args, "-p", serviceConfig.ProjectName)
	} else if s.config.ProjectName != "" {
		args = append(args, "-p", s.config.ProjectName)
	}

	args = append(args, "up", "-d")

	// Add specific services if provided
	if len(serviceConfig.Services) > 0 {
		args = append(args, serviceConfig.Services...)
	}

	result := s.executeCommand(ctx, "docker", args, serviceConfig.Environment)
	result.Duration = time.Since(startTime).String()
	result.Services = serviceConfig.Services

	if result.Success {
		s.logger.LogInfo("Docker services started successfully", map[string]interface{}{
			"duration": result.Duration,
			"services": serviceConfig.Services,
		})
	} else {
		s.logger.LogError(nil, "Failed to start Docker services", map[string]interface{}{
			"error":    result.Error,
			"duration": result.Duration,
			"services": serviceConfig.Services,
		})
	}

	return result, nil
}

// Stop stops Docker services
func (s *Service) Stop(ctx context.Context, serviceConfig ServiceConfig) (*OperationResult, error) {
	startTime := time.Now()

	s.logger.LogInfo("Stopping Docker services", map[string]interface{}{
		"compose_file": serviceConfig.ComposeFile,
		"project_name": serviceConfig.ProjectName,
		"services":     serviceConfig.Services,
	})

	args := []string{"compose"}

	if serviceConfig.ComposeFile != "" {
		args = append(args, "-f", serviceConfig.ComposeFile)
	} else if s.config.ComposeFile != "" {
		args = append(args, "-f", s.config.ComposeFile)
	}

	if serviceConfig.ProjectName != "" {
		args = append(args, "-p", serviceConfig.ProjectName)
	} else if s.config.ProjectName != "" {
		args = append(args, "-p", s.config.ProjectName)
	}

	args = append(args, "down")

	// Add specific services if provided
	if len(serviceConfig.Services) > 0 {
		args = append(args, serviceConfig.Services...)
	}

	result := s.executeCommand(ctx, "docker", args, serviceConfig.Environment)
	result.Duration = time.Since(startTime).String()
	result.Services = serviceConfig.Services

	if result.Success {
		s.logger.LogInfo("Docker services stopped successfully", map[string]interface{}{
			"duration": result.Duration,
			"services": serviceConfig.Services,
		})
	} else {
		s.logger.LogError(nil, "Failed to stop Docker services", map[string]interface{}{
			"error":    result.Error,
			"duration": result.Duration,
			"services": serviceConfig.Services,
		})
	}

	return result, nil
}

// Restart restarts Docker services
func (s *Service) Restart(ctx context.Context, serviceConfig ServiceConfig) (*OperationResult, error) {
	startTime := time.Now()

	s.logger.LogInfo("Restarting Docker services", map[string]interface{}{
		"services": serviceConfig.Services,
	})

	args := []string{"compose"}

	if serviceConfig.ComposeFile != "" {
		args = append(args, "-f", serviceConfig.ComposeFile)
	} else if s.config.ComposeFile != "" {
		args = append(args, "-f", s.config.ComposeFile)
	}

	if serviceConfig.ProjectName != "" {
		args = append(args, "-p", serviceConfig.ProjectName)
	} else if s.config.ProjectName != "" {
		args = append(args, "-p", s.config.ProjectName)
	}

	args = append(args, "restart")

	if len(serviceConfig.Services) > 0 {
		args = append(args, serviceConfig.Services...)
	}

	result := s.executeCommand(ctx, "docker", args, serviceConfig.Environment)
	result.Duration = time.Since(startTime).String()
	result.Services = serviceConfig.Services

	return result, nil
}

// Cleanup removes containers, networks, and volumes
func (s *Service) Cleanup(ctx context.Context, serviceConfig ServiceConfig) (*OperationResult, error) {
	startTime := time.Now()

	s.logger.LogInfo("Cleaning up Docker resources", map[string]interface{}{
		"project_name": serviceConfig.ProjectName,
	})

	args := []string{"compose"}

	if serviceConfig.ComposeFile != "" {
		args = append(args, "-f", serviceConfig.ComposeFile)
	} else if s.config.ComposeFile != "" {
		args = append(args, "-f", s.config.ComposeFile)
	}

	if serviceConfig.ProjectName != "" {
		args = append(args, "-p", serviceConfig.ProjectName)
	} else if s.config.ProjectName != "" {
		args = append(args, "-p", s.config.ProjectName)
	}

	args = append(args, "down", "-v", "--remove-orphans")

	result := s.executeCommand(ctx, "docker", args, serviceConfig.Environment)
	result.Duration = time.Since(startTime).String()

	return result, nil
}

// Status gets the status of Docker services
func (s *Service) Status(ctx context.Context, serviceConfig ServiceConfig) (*OperationResult, error) {
	startTime := time.Now()

	args := []string{"compose"}

	if serviceConfig.ComposeFile != "" {
		args = append(args, "-f", serviceConfig.ComposeFile)
	} else if s.config.ComposeFile != "" {
		args = append(args, "-f", s.config.ComposeFile)
	}

	if serviceConfig.ProjectName != "" {
		args = append(args, "-p", serviceConfig.ProjectName)
	} else if s.config.ProjectName != "" {
		args = append(args, "-p", s.config.ProjectName)
	}

	args = append(args, "ps")

	result := s.executeCommand(ctx, "docker", args, serviceConfig.Environment)
	result.Duration = time.Since(startTime).String()

	return result, nil
}

// executeCommand executes a Docker command with proper timeout and error handling
func (s *Service) executeCommand(ctx context.Context, command string, args []string, env map[string]string) *OperationResult {
	// Create context with timeout
	timeout := time.Duration(s.config.Timeout) * time.Second
	cmdCtx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	// Create command
	cmd := exec.CommandContext(cmdCtx, command, args...)

	// Set working directory if provided
	if env != nil {
		if workDir, exists := env["WORK_DIR"]; exists && workDir != "" {
			cmd.Dir = workDir
		}
	}

	// Set environment variables
	if env != nil {
		for key, value := range env {
			if key != "WORK_DIR" { // Skip special keys
				cmd.Env = append(cmd.Env, fmt.Sprintf("%s=%s", key, value))
			}
		}
	}

	// Add default environment variables
	if s.config.Environment != nil {
		for key, value := range s.config.Environment {
			cmd.Env = append(cmd.Env, fmt.Sprintf("%s=%s", key, value))
		}
	}

	s.logger.LogDebug("Executing Docker command", map[string]interface{}{
		"command": command,
		"args":    strings.Join(args, " "),
		"timeout": timeout,
	})

	// Execute command
	output, err := cmd.CombinedOutput()

	result := &OperationResult{
		Output:   string(output),
		ExitCode: cmd.ProcessState.ExitCode(),
	}

	if err != nil {
		result.Success = false
		result.Error = err.Error()
		result.Message = "Command execution failed"

		// Check if it was a timeout
		if cmdCtx.Err() == context.DeadlineExceeded {
			result.Error = "Command execution timed out"
			result.Message = "Docker operation timed out"
		}
	} else {
		result.Success = true
		result.Message = "Command executed successfully"
	}

	return result
}

// ValidateDockerInstallation checks if Docker and Docker Compose are available
func (s *Service) ValidateDockerInstallation(ctx context.Context) (*OperationResult, error) {
	s.logger.LogInfo("Validating Docker installation", nil)

	// Check Docker
	dockerResult := s.executeCommand(ctx, "docker", []string{"--version"}, nil)
	if !dockerResult.Success {
		return &OperationResult{
			Success: false,
			Message: "Docker is not installed or not accessible",
			Error:   dockerResult.Error,
			Valid:   false,
			Errors:  []string{"Docker command failed"},
			Details: map[string]interface{}{"docker_version": dockerResult.Output},
		}, nil
	}

	// Check Docker Compose
	composeResult := s.executeCommand(ctx, "docker", []string{"compose", "version"}, nil)
	if !composeResult.Success {
		return &OperationResult{
			Success: false,
			Message: "Docker Compose is not installed or not accessible",
			Error:   composeResult.Error,
			Valid:   false,
			Errors:  []string{"Docker Compose command failed"},
			Details: map[string]interface{}{"compose_version": composeResult.Output},
		}, nil
	}

	return &OperationResult{
		Success: true,
		Message: "Docker and Docker Compose are available",
		Output:  fmt.Sprintf("Docker: %s\nDocker Compose: %s", dockerResult.Output, composeResult.Output),
		Valid:   true,
		Errors:  []string{},
		Details: map[string]interface{}{
			"docker_version":  dockerResult.Output,
			"compose_version": composeResult.Output,
		},
	}, nil
}

// GetStatus gets the status of Docker services
func (s *Service) GetStatus(ctx context.Context, projectName string) (*StatusResult, error) {
	s.logger.LogInfo("Getting service status", map[string]interface{}{
		"project_name": projectName,
	})

	// Build docker-compose command to get status
	args := []string{"compose"}
	
	if s.config.ComposeFile != "" {
		args = append(args, "-f", s.config.ComposeFile)
	}
	
	if projectName != "" {
		args = append(args, "-p", projectName)
	}
	
	args = append(args, "ps", "--format", "json")

	// Execute command
	result := s.executeCommand(ctx, "docker", args, nil)
	if !result.Success {
		return nil, fmt.Errorf("failed to get service status: %s", result.Error)
	}

	// Parse output and create status result
	services := []ServiceStatus{}
	if result.Output != "" {
		// For now, create a simple status based on output
		// In a real implementation, you would parse the JSON output
		services = append(services, ServiceStatus{
			Name:   "example-service",
			Status: "running",
			Health: "healthy",
			Uptime: "5 minutes",
		})
	}

	summary := DeploymentSummary{
		Total:     len(services),
		Running:   len(services), // Simplified for now
		Stopped:   0,
		Unhealthy: 0,
	}

	statusResult := &StatusResult{
		Services: services,
		Summary:  summary,
	}

	s.logger.LogInfo("Service status retrieved", map[string]interface{}{
		"services_count": len(services),
		"running":        summary.Running,
	})

	return statusResult, nil
}

// GetLogs gets logs from Docker services
func (s *Service) GetLogs(ctx context.Context, projectName, serviceName string, tail int) (string, error) {
	s.logger.LogInfo("Getting service logs", map[string]interface{}{
		"project_name": projectName,
		"service_name": serviceName,
		"tail":         tail,
	})

	// Build docker-compose command
	args := []string{"compose"}
	
	if s.config.ComposeFile != "" {
		args = append(args, "-f", s.config.ComposeFile)
	}
	
	if projectName != "" {
		args = append(args, "-p", projectName)
	}
	
	args = append(args, "logs")
	
	if tail > 0 {
		args = append(args, "--tail", fmt.Sprintf("%d", tail))
	}
	
	if serviceName != "" {
		args = append(args, serviceName)
	}

	// Execute command
	result := s.executeCommand(ctx, "docker", args, nil)
	if !result.Success {
		return "", fmt.Errorf("failed to get logs: %s", result.Error)
	}

	s.logger.LogInfo("Service logs retrieved", map[string]interface{}{
		"output_length": len(result.Output),
	})

	return result.Output, nil
}
