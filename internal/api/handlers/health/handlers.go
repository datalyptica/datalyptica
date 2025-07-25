package health

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/shudl/shudl/internal/api/models"
	"github.com/shudl/shudl/internal/pkg/logger"
	"github.com/shudl/shudl/internal/pkg/utils"
)

// Handler handles health check endpoints
type Handler struct {
	logger *logger.Logger
}

// NewHandler creates a new health handler
func NewHandler(log *logger.Logger) *Handler {
	return &Handler{
		logger: log.WithComponent("health-handler"),
	}
}

// @Summary Health check
// @Description Check if the installer API is healthy and running
// @Tags health
// @Produce json
// @Success 200 {object} utils.APIResponse{data=models.HealthResponse}
// @Router /health [get]
func (h *Handler) Health(c *gin.Context) {
	h.logger.LogInfo("Health check requested", map[string]interface{}{
		"remote_addr": c.ClientIP(),
	})

	response := models.HealthResponse{
		Status:    "healthy",
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Version:   "1.0.0", // TODO: Get from config or build info
	}

	utils.SuccessResponse(c, "Service is healthy", response)
}

// @Summary Readiness check
// @Description Check if the installer API is ready to serve requests
// @Tags health
// @Produce json
// @Success 200 {object} utils.APIResponse{data=models.HealthResponse}
// @Failure 503 {object} utils.APIResponse
// @Router /ready [get]
func (h *Handler) Ready(c *gin.Context) {
	h.logger.LogInfo("Readiness check requested", map[string]interface{}{
		"remote_addr": c.ClientIP(),
	})

	// TODO: Add actual readiness checks (Docker connectivity, etc.)
	ready := true

	if !ready {
		c.JSON(http.StatusServiceUnavailable, utils.APIResponse{
			Success: false,
			Message: "Service not ready",
			Error:   "Dependencies not available",
		})
		return
	}

	response := models.HealthResponse{
		Status:    "ready",
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Version:   "1.0.0",
	}

	utils.SuccessResponse(c, "Service is ready", response)
}

// @Summary Liveness check
// @Description Check if the installer API is alive
// @Tags health
// @Produce json
// @Success 200 {object} utils.APIResponse{data=models.HealthResponse}
// @Router /live [get]
func (h *Handler) Live(c *gin.Context) {
	response := models.HealthResponse{
		Status:    "alive",
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Version:   "1.0.0",
	}

	utils.SuccessResponse(c, "Service is alive", response)
}
