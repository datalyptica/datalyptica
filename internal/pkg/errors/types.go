package errors

import (
	"errors"
	"fmt"
	"net/http"
)

// ErrorType represents different types of errors
type ErrorType string

const (
	// ValidationError represents input validation errors
	ValidationError ErrorType = "validation"
	// ServiceError represents service layer errors
	ServiceError ErrorType = "service"
	// ExternalError represents external service errors (Docker, etc.)
	ExternalError ErrorType = "external"
	// ConfigurationError represents configuration errors
	ConfigurationError ErrorType = "configuration"
	// NotFoundError represents resource not found errors
	NotFoundError ErrorType = "not_found"
	// AuthenticationError represents authentication errors
	AuthenticationError ErrorType = "authentication"
	// InternalError represents internal system errors
	InternalError ErrorType = "internal"
)

// AppError represents an application error with context
type AppError struct {
	Type       ErrorType              `json:"type"`
	Message    string                 `json:"message"`
	Code       string                 `json:"code,omitempty"`
	Details    map[string]interface{} `json:"details,omitempty"`
	Underlying error                  `json:"-"`
}

// Error implements the error interface
func (e *AppError) Error() string {
	if e.Underlying != nil {
		return fmt.Sprintf("%s: %s (underlying: %v)", e.Type, e.Message, e.Underlying)
	}
	return fmt.Sprintf("%s: %s", e.Type, e.Message)
}

// Unwrap returns the underlying error
func (e *AppError) Unwrap() error {
	return e.Underlying
}

// NewValidationError creates a new validation error
func NewValidationError(message string, details map[string]interface{}) *AppError {
	return &AppError{
		Type:    ValidationError,
		Message: message,
		Details: details,
	}
}

// NewServiceError creates a new service error
func NewServiceError(message string, err error) *AppError {
	return &AppError{
		Type:       ServiceError,
		Message:    message,
		Underlying: err,
	}
}

// NewExternalError creates a new external service error
func NewExternalError(message string, err error, details map[string]interface{}) *AppError {
	return &AppError{
		Type:       ExternalError,
		Message:    message,
		Underlying: err,
		Details:    details,
	}
}

// NewConfigurationError creates a new configuration error
func NewConfigurationError(message string, details map[string]interface{}) *AppError {
	return &AppError{
		Type:    ConfigurationError,
		Message: message,
		Details: details,
	}
}

// NewNotFoundError creates a new not found error
func NewNotFoundError(resource string) *AppError {
	return &AppError{
		Type:    NotFoundError,
		Message: fmt.Sprintf("%s not found", resource),
		Details: map[string]interface{}{"resource": resource},
	}
}

// NewInternalError creates a new internal error
func NewInternalError(message string, err error) *AppError {
	return &AppError{
		Type:       InternalError,
		Message:    message,
		Underlying: err,
	}
}

// HTTPStatusCode returns the appropriate HTTP status code for the error type
func (e *AppError) HTTPStatusCode() int {
	switch e.Type {
	case ValidationError:
		return http.StatusBadRequest
	case NotFoundError:
		return http.StatusNotFound
	case AuthenticationError:
		return http.StatusUnauthorized
	case ConfigurationError:
		return http.StatusBadRequest
	case ExternalError:
		return http.StatusBadGateway
	case ServiceError:
		return http.StatusInternalServerError
	default:
		return http.StatusInternalServerError
	}
}

// IsType checks if the error is of a specific type
func IsType(err error, errorType ErrorType) bool {
	var appErr *AppError
	if errors.As(err, &appErr) {
		return appErr.Type == errorType
	}
	return false
}

// GetDetails extracts details from an AppError, or returns empty map
func GetDetails(err error) map[string]interface{} {
	var appErr *AppError
	if errors.As(err, &appErr) && appErr.Details != nil {
		return appErr.Details
	}
	return make(map[string]interface{})
} 