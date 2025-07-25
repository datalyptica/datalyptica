package config

import (
	"fmt"
	"os"
	"strings"

	"github.com/shudl/shudl/internal/pkg/logger"
	"github.com/spf13/viper"
)

// Config holds all configuration for the application
type Config struct {
	Server ServerConfig  `mapstructure:"server"`
	Logger logger.Config `mapstructure:"logger"`
	Docker DockerConfig  `mapstructure:"docker"`
}

// ServerConfig holds server-related configuration
type ServerConfig struct {
	Host         string `mapstructure:"host" json:"host"`
	Port         int    `mapstructure:"port" json:"port"`
	ReadTimeout  int    `mapstructure:"read_timeout" json:"read_timeout"`
	WriteTimeout int    `mapstructure:"write_timeout" json:"write_timeout"`
	Environment  string `mapstructure:"environment" json:"environment"`
}

// DockerConfig holds Docker-related configuration
type DockerConfig struct {
	ComposeFile     string            `mapstructure:"compose_file" json:"compose_file"`
	ProjectName     string            `mapstructure:"project_name" json:"project_name"`
	DefaultRegistry string            `mapstructure:"default_registry" json:"default_registry"`
	Timeout         int               `mapstructure:"timeout" json:"timeout"`
	Environment     map[string]string `mapstructure:"environment" json:"environment"`
}

// Load loads configuration from various sources
func Load() (*Config, error) {
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath("./configs")
	viper.AddConfigPath(".")
	viper.AddConfigPath("/etc/shudl")

	// Set default values
	setDefaults()

	// Read from environment variables
	viper.SetEnvPrefix("SHUDL")
	viper.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))
	viper.AutomaticEnv()

	// Read config file if it exists
	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return nil, fmt.Errorf("failed to read config file: %w", err)
		}
		// Config file not found is not an error, we'll use defaults and env vars
	}

	var config Config
	if err := viper.Unmarshal(&config); err != nil {
		return nil, fmt.Errorf("failed to unmarshal config: %w", err)
	}

	// Validate configuration
	if err := validate(&config); err != nil {
		return nil, fmt.Errorf("invalid configuration: %w", err)
	}

	return &config, nil
}

// setDefaults sets default configuration values
func setDefaults() {
	// Server defaults
	viper.SetDefault("server.host", "0.0.0.0")
	viper.SetDefault("server.port", 8080)
	viper.SetDefault("server.read_timeout", 30)
	viper.SetDefault("server.write_timeout", 30)
	viper.SetDefault("server.environment", "development")

	// Logger defaults
	viper.SetDefault("logger.level", "info")
	viper.SetDefault("logger.environment", "development")
	viper.SetDefault("logger.time_format", "15:04:05")

	// Docker defaults
	viper.SetDefault("docker.compose_file", "docker-compose.yml")
	viper.SetDefault("docker.project_name", "shudl")
	viper.SetDefault("docker.default_registry", "")
	viper.SetDefault("docker.timeout", 300)
}

// validate validates the configuration
func validate(config *Config) error {
	if config.Server.Port < 1 || config.Server.Port > 65535 {
		return fmt.Errorf("invalid server port: %d", config.Server.Port)
	}

	if config.Server.ReadTimeout < 0 {
		return fmt.Errorf("invalid read timeout: %d", config.Server.ReadTimeout)
	}

	if config.Server.WriteTimeout < 0 {
		return fmt.Errorf("invalid write timeout: %d", config.Server.WriteTimeout)
	}

	if config.Docker.Timeout < 0 {
		return fmt.Errorf("invalid docker timeout: %d", config.Docker.Timeout)
	}

	// Check if compose file exists if specified
	if config.Docker.ComposeFile != "" {
		if _, err := os.Stat(config.Docker.ComposeFile); os.IsNotExist(err) {
			// Only error if the compose file is explicitly set but doesn't exist
			if viper.IsSet("docker.compose_file") && config.Docker.ComposeFile != "docker-compose.yml" {
				return fmt.Errorf("docker compose file not found: %s", config.Docker.ComposeFile)
			}
			// For default docker-compose.yml, just warn but don't fail
			// This allows the installer to work in generator mode without requiring existing compose files
		}
	}

	return nil
}

// GetString returns a string configuration value
func GetString(key string) string {
	return viper.GetString(key)
}

// GetInt returns an integer configuration value
func GetInt(key string) int {
	return viper.GetInt(key)
}

// GetBool returns a boolean configuration value
func GetBool(key string) bool {
	return viper.GetBool(key)
}

// GetStringMap returns a string map configuration value
func GetStringMap(key string) map[string]interface{} {
	return viper.GetStringMap(key)
}

// Set sets a configuration value
func Set(key string, value interface{}) {
	viper.Set(key, value)
}
