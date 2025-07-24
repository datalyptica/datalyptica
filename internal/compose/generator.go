package compose

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"

	"github.com/shudl/shudl/internal/logger"
)

// Generator handles docker-compose file generation
type Generator struct {
	logger     *logger.Logger
	outputDir  string
	templateDir string
}

// ServiceConfig represents configuration for a specific service
type ServiceConfig struct {
	Name    string            `json:"name"`
	Enabled bool              `json:"enabled"`
	Image   string            `json:"image,omitempty"`
	Tag     string            `json:"tag,omitempty"`
	Ports   map[string]string `json:"ports,omitempty"`
	Env     map[string]string `json:"env,omitempty"`
	Options map[string]string `json:"options,omitempty"`
}

// ComposeConfiguration represents the full configuration for generating compose files
type ComposeConfiguration struct {
	ProjectName  string                    `json:"project_name"`
	NetworkName  string                    `json:"network_name"`
	Services     map[string]*ServiceConfig `json:"services"`
	GlobalConfig map[string]string         `json:"global_config"`
	Environment  string                    `json:"environment"` // dev, prod, custom
}

// DefaultConfigurations provides preset configurations
type DefaultConfigurations struct {
	Development *ComposeConfiguration
	Production  *ComposeConfiguration
	Minimal     *ComposeConfiguration
}

// NewGenerator creates a new compose generator
func NewGenerator(outputDir string, log *logger.Logger) *Generator {
	return &Generator{
		logger:      log.WithComponent("compose-generator"),
		outputDir:   outputDir,
		templateDir: "templates",
	}
}

// GenerateCompose creates a docker-compose.yml file based on configuration
func (g *Generator) GenerateCompose(config *ComposeConfiguration) (string, error) {
	g.logger.LogInfo("Generating docker-compose file", map[string]interface{}{
		"project_name": config.ProjectName,
		"services":     len(config.Services),
		"environment":  config.Environment,
	})

	// Create compose content
	compose := g.BuildComposeContent(config)

	// Write to file
	filename := filepath.Join(g.outputDir, "docker-compose.yml")
	if err := os.WriteFile(filename, []byte(compose), 0644); err != nil {
		return "", fmt.Errorf("failed to write compose file: %w", err)
	}

	g.logger.LogInfo("Docker compose file generated successfully", map[string]interface{}{
		"filename": filename,
		"size":     len(compose),
	})

	return filename, nil
}

// GenerateEnvFile creates a .env file based on configuration
func (g *Generator) GenerateEnvFile(config *ComposeConfiguration) (string, error) {
	g.logger.LogInfo("Generating environment file", map[string]interface{}{
		"project_name": config.ProjectName,
		"environment":  config.Environment,
	})

	// Build environment content
	envContent := g.BuildEnvContent(config)

	// Write to file
	filename := filepath.Join(g.outputDir, ".env")
	if err := os.WriteFile(filename, []byte(envContent), 0644); err != nil {
		return "", fmt.Errorf("failed to write env file: %w", err)
	}

	g.logger.LogInfo("Environment file generated successfully", map[string]interface{}{
		"filename": filename,
		"size":     len(envContent),
	})

	return filename, nil
}

// GetDefaultConfigurations returns preset configurations
func (g *Generator) GetDefaultConfigurations() *DefaultConfigurations {
	return &DefaultConfigurations{
		Development: g.createDevelopmentConfig(),
		Production:  g.createProductionConfig(),
		Minimal:     g.createMinimalConfig(),
	}
}

// BuildComposeContent creates the docker-compose.yml content
func (g *Generator) BuildComposeContent(config *ComposeConfiguration) string {
	var buf bytes.Buffer

	// Write header
	buf.WriteString("services:\n")

	// Generate services
	for name, service := range config.Services {
		if service.Enabled {
			g.writeServiceDefinition(&buf, name, service, config)
		}
	}

	// Write volumes section
	buf.WriteString("\nvolumes:\n")
	for name, service := range config.Services {
		if service.Enabled {
			g.writeServiceVolumes(&buf, name, service)
		}
	}

	// Write networks section
	buf.WriteString(fmt.Sprintf(`
networks:
  %s:
    name: ${NETWORK_NAME}
    driver: bridge
`, config.NetworkName))

	return buf.String()
}

// writeServiceDefinition writes a service definition to the compose file
func (g *Generator) writeServiceDefinition(buf *bytes.Buffer, name string, service *ServiceConfig, config *ComposeConfiguration) {
	image := service.Image
	if image == "" {
		image = fmt.Sprintf("ghcr.io/shugur-network/shudl/%s:latest", name)
	}

	buf.WriteString(fmt.Sprintf(`
  # %s Service
  %s:
    image: %s
    container_name: ${COMPOSE_PROJECT_NAME}-%s
`, g.capitalize(name), name, image, name))

	// Ports
	if len(service.Ports) > 0 {
		buf.WriteString("    ports:\n")
		for internal, external := range service.Ports {
			buf.WriteString(fmt.Sprintf("      - \"${%s}:%s\"\n", external, internal))
		}
	}

	// Environment variables
	buf.WriteString("    environment:\n")
	g.writeServiceEnvironment(buf, name, service, config)

	// Volumes
	buf.WriteString("    volumes:\n")
	g.writeServiceVolumeBinds(buf, name, service)

	// Networks
	buf.WriteString(fmt.Sprintf("    networks:\n      - ${NETWORK_NAME}\n"))

	// Depends on
	g.writeServiceDependencies(buf, name, service, config)

	// Health check
	g.writeServiceHealthCheck(buf, name, service)

	// Restart policy
	buf.WriteString("    restart: unless-stopped\n")
}

// writeServiceEnvironment writes environment variables for a service
func (g *Generator) writeServiceEnvironment(buf *bytes.Buffer, name string, service *ServiceConfig, config *ComposeConfiguration) {
	envVars := g.getServiceEnvironmentVariables(name, service, config)
	
	for key, value := range envVars {
		buf.WriteString(fmt.Sprintf("      - %s=%s\n", key, value))
	}
}

// getServiceEnvironmentVariables returns environment variables for a service
func (g *Generator) getServiceEnvironmentVariables(name string, service *ServiceConfig, config *ComposeConfiguration) map[string]string {
	envVars := make(map[string]string)

	switch name {
	case "minio":
		envVars["MINIO_ROOT_USER"] = "${MINIO_ROOT_USER}"
		envVars["MINIO_ROOT_PASSWORD"] = "${MINIO_ROOT_PASSWORD}"
		envVars["MINIO_VOLUMES"] = "/data"
		envVars["MINIO_OPTS"] = "--console-address :9001"
		envVars["MINIO_REGION"] = "${MINIO_REGION}"
		envVars["MINIO_DEFAULT_BUCKETS"] = "${MINIO_BUCKET_NAME}"

	case "postgresql":
		envVars["POSTGRES_DB"] = "${POSTGRES_DB}"
		envVars["POSTGRES_USER"] = "${POSTGRES_USER}"
		envVars["POSTGRES_PASSWORD"] = "${POSTGRES_PASSWORD}"
		envVars["POSTGRES_INITDB_ARGS"] = "--encoding=UTF-8 --lc-collate=C --lc-ctype=C"
		envVars["PGDATA"] = "/var/lib/postgresql/data/pgdata"
		envVars["SHUDL_DB"] = "${SHUDL_DB}"
		envVars["SHUDL_USER"] = "${SHUDL_USER}"
		envVars["SHUDL_PASSWORD"] = "${SHUDL_PASSWORD}"

	case "nessie":
		envVars["QUARKUS_HTTP_PORT"] = "${NESSIE_PORT}"
		envVars["QUARKUS_HTTP_HOST"] = "${NESSIE_HOST}"
		envVars["NESSIE_VERSION_STORE_TYPE"] = "${NESSIE_VERSION_STORE_TYPE}"
		envVars["QUARKUS_DATASOURCE_POSTGRESQL_JDBC_URL"] = "jdbc:postgresql://postgresql:5432/${POSTGRES_DB}"
		envVars["QUARKUS_DATASOURCE_POSTGRESQL_USERNAME"] = "${POSTGRES_USER}"
		envVars["QUARKUS_DATASOURCE_POSTGRESQL_PASSWORD"] = "${POSTGRES_PASSWORD}"
		envVars["S3_ACCESS_KEY"] = "${S3_ACCESS_KEY}"
		envVars["S3_SECRET_KEY"] = "${S3_SECRET_KEY}"
		envVars["S3_ENDPOINT"] = "${S3_ENDPOINT}"

	case "trino":
		envVars["TRINO_COORDINATOR"] = "${TRINO_COORDINATOR}"
		envVars["TRINO_NODE_SCHEDULER_INCLUDE_COORDINATOR"] = "${TRINO_INCLUDE_COORDINATOR}"
		envVars["TRINO_HTTP_SERVER_PORT"] = "${TRINO_PORT}"
		envVars["TRINO_DISCOVERY_URI"] = "${TRINO_DISCOVERY_URI}"
		envVars["TRINO_QUERY_MAX_MEMORY"] = "${TRINO_QUERY_MAX_MEMORY}"
		envVars["S3_ENDPOINT"] = "${S3_ENDPOINT}"
		envVars["S3_ACCESS_KEY"] = "${S3_ACCESS_KEY}"
		envVars["S3_SECRET_KEY"] = "${S3_SECRET_KEY}"

	case "spark-master":
		envVars["SPARK_MODE"] = "master"
		envVars["SPARK_WEBUI_PORT"] = "${SPARK_UI_PORT}"
		envVars["SPARK_MASTER_URL"] = "${SPARK_MASTER_URL}"
		envVars["S3_ENDPOINT"] = "${S3_ENDPOINT}"
		envVars["S3_ACCESS_KEY"] = "${S3_ACCESS_KEY}"
		envVars["S3_SECRET_KEY"] = "${S3_SECRET_KEY}"
		envVars["NESSIE_URI"] = "${NESSIE_URI}"
		envVars["WAREHOUSE_LOCATION"] = "${WAREHOUSE_LOCATION}"

	case "spark-worker":
		envVars["SPARK_MODE"] = "worker"
		envVars["SPARK_MASTER_URL"] = "${SPARK_MASTER_URL}"
		envVars["SPARK_WORKER_MEMORY"] = "${SPARK_WORKER_MEMORY}"
		envVars["SPARK_WORKER_CORES"] = "${SPARK_WORKER_CORES}"
		envVars["S3_ENDPOINT"] = "${S3_ENDPOINT}"
		envVars["S3_ACCESS_KEY"] = "${S3_ACCESS_KEY}"
		envVars["S3_SECRET_KEY"] = "${S3_SECRET_KEY}"
	}

	// Add custom environment variables from service config
	for key, value := range service.Env {
		envVars[key] = value
	}

	return envVars
}

// writeServiceVolumes writes volume definitions
func (g *Generator) writeServiceVolumes(buf *bytes.Buffer, name string, service *ServiceConfig) {
	switch name {
	case "minio":
		buf.WriteString("  minio_data:\n    driver: local\n")
	case "postgresql":
		buf.WriteString("  postgresql_data:\n    driver: local\n")
	}
}

// writeServiceVolumeBinds writes volume binds for a service
func (g *Generator) writeServiceVolumeBinds(buf *bytes.Buffer, name string, service *ServiceConfig) {
	switch name {
	case "minio":
		buf.WriteString("      - minio_data:/data\n")
	case "postgresql":
		buf.WriteString("      - postgresql_data:/var/lib/postgresql/data\n")
	default:
		buf.WriteString("      # No persistent volumes\n")
	}
}

// writeServiceDependencies writes service dependencies
func (g *Generator) writeServiceDependencies(buf *bytes.Buffer, name string, service *ServiceConfig, config *ComposeConfiguration) {
	dependencies := g.getServiceDependencies(name, config)
	if len(dependencies) > 0 {
		buf.WriteString("    depends_on:\n")
		for _, dep := range dependencies {
			if config.Services[dep] != nil && config.Services[dep].Enabled {
				buf.WriteString(fmt.Sprintf("      %s:\n        condition: service_healthy\n", dep))
			}
		}
	}
}

// getServiceDependencies returns dependencies for a service
func (g *Generator) getServiceDependencies(name string, config *ComposeConfiguration) []string {
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

// writeServiceHealthCheck writes health check configuration
func (g *Generator) writeServiceHealthCheck(buf *bytes.Buffer, name string, service *ServiceConfig) {
	buf.WriteString("    healthcheck:\n")
	
	switch name {
	case "minio":
		buf.WriteString("      test: [\"CMD\", \"curl\", \"-f\", \"http://localhost:9000/minio/health/live\"]\n")
	case "postgresql":
		buf.WriteString("      test: [\"CMD-SHELL\", \"pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}\"]\n")
	case "nessie":
		buf.WriteString("      test: [\"CMD\", \"curl\", \"-f\", \"http://localhost:19120/api/v2/config\"]\n")
	case "trino":
		buf.WriteString("      test: [\"CMD\", \"curl\", \"-f\", \"http://localhost:8080/v1/info\"]\n")
	case "spark-master", "spark-worker":
		buf.WriteString("      test: [\"CMD\", \"curl\", \"-f\", \"http://localhost:4040\"]\n")
	default:
		buf.WriteString("      test: [\"CMD\", \"echo\", \"healthy\"]\n")
	}
	
	buf.WriteString("      interval: ${HEALTHCHECK_INTERVAL}\n")
	buf.WriteString("      timeout: ${HEALTHCHECK_TIMEOUT}\n")
	buf.WriteString("      retries: ${HEALTHCHECK_RETRIES}\n")
	buf.WriteString("      start_period: ${HEALTHCHECK_START_PERIOD}\n")
}

// BuildEnvContent creates the .env file content
func (g *Generator) BuildEnvContent(config *ComposeConfiguration) string {
	var buf bytes.Buffer

	buf.WriteString("# ShuDL Data Lakehouse Environment Configuration\n")
	buf.WriteString("# Generated by ShuDL Installer\n\n")

	// Global configuration
	buf.WriteString("# =============================================================================\n")
	buf.WriteString("# Global Configuration\n")
	buf.WriteString("# =============================================================================\n")
	buf.WriteString(fmt.Sprintf("COMPOSE_PROJECT_NAME=%s\n", config.ProjectName))
	buf.WriteString(fmt.Sprintf("NETWORK_NAME=%s\n", config.NetworkName))
	buf.WriteString("\n")

	// Service-specific configuration
	for name, service := range config.Services {
		if service.Enabled {
			g.writeServiceEnvVars(&buf, name, service, config)
		}
	}

	// Health check configuration
	buf.WriteString("# =============================================================================\n")
	buf.WriteString("# Health Check Configuration\n")
	buf.WriteString("# =============================================================================\n")
	buf.WriteString("HEALTHCHECK_INTERVAL=30s\n")
	buf.WriteString("HEALTHCHECK_TIMEOUT=10s\n")
	buf.WriteString("HEALTHCHECK_RETRIES=3\n")
	buf.WriteString("HEALTHCHECK_START_PERIOD=30s\n")

	return buf.String()
}

// writeServiceEnvVars writes environment variables for a service to .env file
func (g *Generator) writeServiceEnvVars(buf *bytes.Buffer, name string, service *ServiceConfig, config *ComposeConfiguration) {
	buf.WriteString(fmt.Sprintf("# =============================================================================\n"))
	buf.WriteString(fmt.Sprintf("# %s Configuration\n", g.capitalize(name)))
	buf.WriteString(fmt.Sprintf("# =============================================================================\n"))

	envVars := g.getServiceEnvFileVariables(name, service, config)
	for key, value := range envVars {
		buf.WriteString(fmt.Sprintf("%s=%s\n", key, value))
	}
	buf.WriteString("\n")
}

// getServiceEnvFileVariables returns environment file variables for a service
func (g *Generator) getServiceEnvFileVariables(name string, service *ServiceConfig, config *ComposeConfiguration) map[string]string {
	envVars := make(map[string]string)

	switch name {
	case "minio":
		envVars["MINIO_ROOT_USER"] = "admin"
		envVars["MINIO_ROOT_PASSWORD"] = g.getPassword("minio", config.Environment)
		envVars["MINIO_API_PORT"] = "9000"
		envVars["MINIO_CONSOLE_PORT"] = "9001"
		envVars["MINIO_BUCKET_NAME"] = "lakehouse"
		envVars["MINIO_REGION"] = "us-east-1"

	case "postgresql":
		envVars["POSTGRES_DB"] = "nessie"
		envVars["POSTGRES_USER"] = "nessie"
		envVars["POSTGRES_PASSWORD"] = g.getPassword("postgres", config.Environment)
		envVars["POSTGRES_PORT"] = "5432"
		envVars["SHUDL_DB"] = "shudl"
		envVars["SHUDL_USER"] = "shudl"
		envVars["SHUDL_PASSWORD"] = g.getPassword("shudl", config.Environment)

	case "nessie":
		envVars["NESSIE_PORT"] = "19120"
		envVars["NESSIE_HOST"] = "0.0.0.0"
		envVars["NESSIE_VERSION_STORE_TYPE"] = "JDBC2"

	case "trino":
		envVars["TRINO_PORT"] = "8080"
		envVars["TRINO_COORDINATOR"] = "true"
		envVars["TRINO_INCLUDE_COORDINATOR"] = "false"
		envVars["TRINO_DISCOVERY_URI"] = "http://trino:8080"
		envVars["TRINO_QUERY_MAX_MEMORY"] = g.getMemoryConfig("trino", config.Environment)

	case "spark-master":
		envVars["SPARK_UI_PORT"] = "4040"
		envVars["SPARK_MASTER_PORT"] = "7077"
		envVars["SPARK_MASTER_URL"] = "spark://spark-master:7077"

	case "spark-worker":
		envVars["SPARK_WORKER_MEMORY"] = g.getMemoryConfig("spark-worker", config.Environment)
		envVars["SPARK_WORKER_CORES"] = g.getCoresConfig("spark-worker", config.Environment)
	}

	// S3/MinIO shared configuration
	if name == "minio" || name == "nessie" || name == "trino" || name == "spark-master" || name == "spark-worker" {
		envVars["S3_ENDPOINT"] = fmt.Sprintf("http://%s-minio:9000", config.ProjectName)
		envVars["S3_ACCESS_KEY"] = "admin"
		envVars["S3_SECRET_KEY"] = g.getPassword("minio", config.Environment)
		envVars["S3_REGION"] = "us-east-1"
		envVars["S3_PATH_STYLE_ACCESS"] = "true"
		envVars["NESSIE_URI"] = fmt.Sprintf("http://nessie:19120/iceberg/main/")
		envVars["WAREHOUSE_LOCATION"] = "s3://lakehouse/"
	}

	// Add custom environment variables
	for key, value := range service.Env {
		envVars[key] = value
	}

	return envVars
}

// Helper functions
func (g *Generator) capitalize(s string) string {
	if len(s) == 0 {
		return s
	}
	return string(s[0]-32) + s[1:]
}

func (g *Generator) getPassword(service, environment string) string {
	if environment == "development" {
		return "devpass123"
	}
	return "CHANGE_ME_SECURE_PASSWORD"
}

func (g *Generator) getMemoryConfig(service, environment string) string {
	if environment == "development" {
		switch service {
		case "trino":
			return "1GB"
		case "spark-worker":
			return "1g"
		default:
			return "1GB"
		}
	}
	switch service {
	case "trino":
		return "4GB"
	case "spark-worker":
		return "2g"
	default:
		return "2GB"
	}
}

func (g *Generator) getCoresConfig(service, environment string) string {
	if environment == "development" {
		return "1"
	}
	return "2"
}

// Preset configurations
func (g *Generator) createDevelopmentConfig() *ComposeConfiguration {
	return &ComposeConfiguration{
		ProjectName: "shudl-dev",
		NetworkName: "shunetwork",
		Environment: "development",
		GlobalConfig: map[string]string{
			"registry": "ghcr.io/shugur-network/shudl",
		},
		Services: map[string]*ServiceConfig{
			"minio": {
				Name:    "minio",
				Enabled: true,
				Ports:   map[string]string{"9000": "MINIO_API_PORT", "9001": "MINIO_CONSOLE_PORT"},
			},
			"postgresql": {
				Name:    "postgresql",
				Enabled: true,
				Ports:   map[string]string{"5432": "POSTGRES_PORT"},
			},
			"nessie": {
				Name:    "nessie",
				Enabled: true,
				Ports:   map[string]string{"19120": "NESSIE_PORT"},
			},
			"trino": {
				Name:    "trino",
				Enabled: true,
				Ports:   map[string]string{"8080": "TRINO_PORT"},
			},
			"spark-master": {
				Name:    "spark-master",
				Enabled: false,
				Ports:   map[string]string{"4040": "SPARK_UI_PORT", "7077": "SPARK_MASTER_PORT"},
			},
			"spark-worker": {
				Name:    "spark-worker",
				Enabled: false,
				Ports:   map[string]string{"4040": "4041"},
			},
		},
	}
}

func (g *Generator) createProductionConfig() *ComposeConfiguration {
	config := g.createDevelopmentConfig()
	config.ProjectName = "shudl"
	config.Environment = "production"
	
	// Enable all services for production
	for _, service := range config.Services {
		service.Enabled = true
	}
	
	return config
}

func (g *Generator) createMinimalConfig() *ComposeConfiguration {
	return &ComposeConfiguration{
		ProjectName: "shudl-minimal",
		NetworkName: "shunetwork",
		Environment: "development",
		GlobalConfig: map[string]string{
			"registry": "ghcr.io/shugur-network/shudl",
		},
		Services: map[string]*ServiceConfig{
			"minio": {
				Name:    "minio",
				Enabled: true,
				Ports:   map[string]string{"9000": "MINIO_API_PORT", "9001": "MINIO_CONSOLE_PORT"},
			},
			"postgresql": {
				Name:    "postgresql",
				Enabled: true,
				Ports:   map[string]string{"5432": "POSTGRES_PORT"},
			},
			"nessie": {
				Name:    "nessie",
				Enabled: true,
				Ports:   map[string]string{"19120": "NESSIE_PORT"},
			},
		},
	}
} 