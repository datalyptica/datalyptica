package api

import (
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/shudl/shudl/internal/config"
	"github.com/shudl/shudl/internal/logger"
	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"
)

// Router handles HTTP routing
type Router struct {
	engine         *gin.Engine
	handler        *Handler
	composeHandler *ComposeHandler
	webHandler     *WebHandler
	config         *config.ServerConfig
	logger         *logger.Logger
}

// NewRouter creates a new router with all handlers
func NewRouter(handler *Handler, composeHandler *ComposeHandler, webHandler *WebHandler, serverConfig *config.ServerConfig, log *logger.Logger) *Router {
	if serverConfig.Environment == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	return &Router{
		engine:         gin.New(),
		handler:        handler,
		composeHandler: composeHandler,
		webHandler:     webHandler,
		config:         serverConfig,
		logger:         log,
	}
}

// Setup configures middleware and routes
func (r *Router) Setup() {
	// Load HTML templates
	r.engine.LoadHTMLGlob("web/templates/**/*.html")
	
	r.addMiddleware()
	r.addRoutes()
}

// GetEngine returns the Gin engine
func (r *Router) GetEngine() *gin.Engine {
	return r.engine
}

// addMiddleware adds middleware to the router
func (r *Router) addMiddleware() {
	// Add custom logger middleware
	r.engine.Use(r.loggerMiddleware())

	// Add Gin's recovery middleware
	r.engine.Use(gin.Recovery())

	// Add CORS middleware
	r.engine.Use(r.corsMiddleware())

	// Add request ID middleware
	r.engine.Use(r.requestIDMiddleware())
}

// addRoutes adds all routes to the router
func (r *Router) addRoutes() {
	// Static files for web interface
	r.engine.Static("/static", "./web/static")
	
	// Web interface routes
	webGroup := r.engine.Group("/")
	{
		webGroup.GET("/", r.webHandler.ServeInstaller)
		webGroup.GET("/installer", r.webHandler.ServeInstaller)
	}

	// Health check endpoint
	r.engine.GET("/health", r.handler.HealthCheck)

	// Swagger documentation
	r.engine.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))

	// API v1 routes
	v1 := r.engine.Group("/api/v1")
	{
		// System validation endpoints
		system := v1.Group("/system")
		{
			system.GET("/validate", r.handler.ValidateDockerInstallation)
		}

		// Docker management endpoints
		docker := v1.Group("/docker")
		{
			docker.POST("/start", r.handler.StartServices)
			docker.POST("/stop", r.handler.StopServices)
			docker.POST("/restart", r.handler.RestartServices)
			docker.POST("/cleanup", r.handler.CleanupServices)
			docker.GET("/status", r.handler.GetServicesStatus)
		}

		// Compose generation endpoints
		compose := v1.Group("/compose")
		{
			compose.GET("/services", r.composeHandler.GetAvailableServices)
			compose.GET("/defaults", r.composeHandler.GetDefaultConfigurations)
			compose.POST("/generate", r.composeHandler.GenerateCompose)
			compose.POST("/validate", r.composeHandler.ValidateConfiguration)
			compose.POST("/preview", r.composeHandler.PreviewGeneration)
		}

		// Installer-specific endpoints for web interface
		installer := v1.Group("/installer")
		{
			installer.GET("/config-schema", r.webHandler.GetConfigSchema)
			installer.POST("/validate-config", r.webHandler.ValidateConfig)
		}
	}
}

// loggerMiddleware provides custom logging
func (r *Router) loggerMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Start timer
		start := c.Request.URL.Path

		// Process request
		c.Next()

		// Log request
		r.logger.LogInfo("HTTP request completed", map[string]interface{}{
			"method":      c.Request.Method,
			"path":        start,
			"status_code": c.Writer.Status(),
			"client_ip":   c.ClientIP(),
			"user_agent":  c.Request.UserAgent(),
			"latency":     c.GetHeader("X-Request-Duration"),
		})
	}
}

// corsMiddleware provides CORS support
func (r *Router) corsMiddleware() gin.HandlerFunc {
	config := cors.DefaultConfig()
	config.AllowOrigins = []string{"*"}
	config.AllowMethods = []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"}
	config.AllowHeaders = []string{"Origin", "Content-Type", "Accept", "Authorization", "X-Requested-With", "X-Request-ID"}
	config.ExposeHeaders = []string{"X-Request-ID"}
	return cors.New(config)
}

// requestIDMiddleware adds unique request ID
func (r *Router) requestIDMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		requestID := c.GetHeader("X-Request-ID")
		if requestID == "" {
			requestID = generateRequestID()
		}
		c.Header("X-Request-ID", requestID)
		c.Set("request_id", requestID)
		c.Next()
	}
}

// generateRequestID generates a unique request ID
func generateRequestID() string {
	// Simple implementation - in production, use a proper UUID library
	return "req-" + randomString(8)
}

// randomString generates a random string of given length
func randomString(length int) string {
	const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	b := make([]byte, length)
	for i := range b {
		b[i] = charset[len(charset)/2] // Simplified for now
	}
	return string(b)
} 