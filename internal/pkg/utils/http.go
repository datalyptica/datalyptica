package utils

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
	appErrors "github.com/shudl/shudl/internal/pkg/errors"
)

// APIResponse represents a standard API response
type APIResponse struct {
	Success bool        `json:"success"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
	Code    string      `json:"code,omitempty"`
	Details interface{} `json:"details,omitempty"`
}

// SuccessResponse sends a successful response
func SuccessResponse(c *gin.Context, message string, data interface{}) {
	c.JSON(http.StatusOK, APIResponse{
		Success: true,
		Message: message,
		Data:    data,
	})
}

// CreatedResponse sends a created response
func CreatedResponse(c *gin.Context, message string, data interface{}) {
	c.JSON(http.StatusCreated, APIResponse{
		Success: true,
		Message: message,
		Data:    data,
	})
}

// ErrorResponse sends an error response
func ErrorResponse(c *gin.Context, err error) {
	var appErr *appErrors.AppError
	var statusCode int
	var response APIResponse

	if err == nil {
		statusCode = http.StatusInternalServerError
		response = APIResponse{
			Success: false,
			Message: "Internal server error",
			Error:   "Unknown error",
		}
	} else if errors.As(err, &appErr) {
		statusCode = appErr.HTTPStatusCode()
		response = APIResponse{
			Success: false,
			Message: appErr.Message,
			Error:   appErr.Error(),
			Code:    appErr.Code,
			Details: appErr.Details,
		}
	} else {
		statusCode = http.StatusInternalServerError
		response = APIResponse{
			Success: false,
			Message: "Internal server error",
			Error:   err.Error(),
		}
	}

	c.JSON(statusCode, response)
}

// ValidationErrorResponse sends a validation error response
func ValidationErrorResponse(c *gin.Context, message string, details map[string]interface{}) {
	c.JSON(http.StatusBadRequest, APIResponse{
		Success: false,
		Message: message,
		Error:   "Validation failed",
		Details: details,
	})
}

// NotFoundResponse sends a not found response
func NotFoundResponse(c *gin.Context, resource string) {
	c.JSON(http.StatusNotFound, APIResponse{
		Success: false,
		Message: resource + " not found",
		Error:   "Resource not found",
	})
}

// UnauthorizedResponse sends an unauthorized response
func UnauthorizedResponse(c *gin.Context, message string) {
	c.JSON(http.StatusUnauthorized, APIResponse{
		Success: false,
		Message: message,
		Error:   "Unauthorized",
	})
}

// InternalErrorResponse sends an internal error response
func InternalErrorResponse(c *gin.Context, message string) {
	c.JSON(http.StatusInternalServerError, APIResponse{
		Success: false,
		Message: message,
		Error:   "Internal server error",
	})
} 