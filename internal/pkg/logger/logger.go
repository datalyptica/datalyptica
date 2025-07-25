package logger

import (
	"os"
	"strings"
	"time"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
)

// Logger wraps zerolog.Logger with additional functionality
type Logger struct {
	*zerolog.Logger
}

// Config holds logger configuration
type Config struct {
	Level       string `mapstructure:"level" json:"level"`
	Environment string `mapstructure:"environment" json:"environment"`
	TimeFormat  string `mapstructure:"time_format" json:"time_format"`
}

// New creates a new logger instance with the given configuration
func New(config Config) *Logger {
	// Set default values
	if config.Level == "" {
		config.Level = "info"
	}
	if config.Environment == "" {
		config.Environment = "development"
	}
	if config.TimeFormat == "" {
		config.TimeFormat = time.RFC3339
	}

	// Set log level
	level, err := zerolog.ParseLevel(strings.ToLower(config.Level))
	if err != nil {
		level = zerolog.InfoLevel
	}
	zerolog.SetGlobalLevel(level)

	// Configure logger based on environment
	var logger zerolog.Logger
	if config.Environment == "production" {
		// JSON output for production
		logger = zerolog.New(os.Stdout).With().Timestamp().Logger()
	} else {
		// Pretty output for development
		logger = zerolog.New(zerolog.ConsoleWriter{
			Out:        os.Stdout,
			TimeFormat: config.TimeFormat,
		}).With().Timestamp().Logger()
	}

	// Set global logger
	log.Logger = logger

	return &Logger{Logger: &logger}
}

// GetGlobal returns the global logger instance
func GetGlobal() *Logger {
	return &Logger{Logger: &log.Logger}
}

// WithComponent adds component context to logger
func (l *Logger) WithComponent(component string) *Logger {
	newLogger := l.Logger.With().Str("component", component).Logger()
	return &Logger{Logger: &newLogger}
}

// WithRequestID adds request ID context to logger
func (l *Logger) WithRequestID(requestID string) *Logger {
	newLogger := l.Logger.With().Str("request_id", requestID).Logger()
	return &Logger{Logger: &newLogger}
}

// WithOperation adds operation context to logger
func (l *Logger) WithOperation(operation string) *Logger {
	newLogger := l.Logger.With().Str("operation", operation).Logger()
	return &Logger{Logger: &newLogger}
}

// LogError logs an error with additional context
func (l *Logger) LogError(err error, message string, fields map[string]interface{}) {
	event := l.Logger.Error().Err(err)
	for key, value := range fields {
		event = event.Interface(key, value)
	}
	event.Msg(message)
}

// LogInfo logs an info message with additional context
func (l *Logger) LogInfo(message string, fields map[string]interface{}) {
	event := l.Logger.Info()
	for key, value := range fields {
		event = event.Interface(key, value)
	}
	event.Msg(message)
}

// LogDebug logs a debug message with additional context
func (l *Logger) LogDebug(message string, fields map[string]interface{}) {
	event := l.Logger.Debug()
	for key, value := range fields {
		event = event.Interface(key, value)
	}
	event.Msg(message)
}

// LogWarn logs a warning message with additional context
func (l *Logger) LogWarn(message string, fields map[string]interface{}) {
	event := l.Logger.Warn()
	for key, value := range fields {
		event = event.Interface(key, value)
	}
	event.Msg(message)
} 