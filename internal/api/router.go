package api

import (
	"context"
	"time"

	"github.com/gin-gonic/gin"
	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"
	"github.com/shudl/shudl/internal/config"
	"github.com/shudl/shudl/internal/logger"
)

// Router holds the gin router and dependencies
type Router struct {
	engine  *gin.Engine
	handler *Handler
	config  *config.ServerConfig
	logger  *logger.Logger
}

// NewRouter creates a new API router
func NewRouter(handler *Handler, serverConfig *config.ServerConfig, log *logger.Logger) *Router {
	// Set gin mode based on environment
	if serverConfig.Environment == "production" {
		gin.SetMode(gin.ReleaseMode)
	} else {
		gin.SetMode(gin.DebugMode)
	}

	engine := gin.New()
	
	return &Router{
		engine:  engine,
		handler: handler,
		config:  serverConfig,
		logger:  log.WithComponent("api-router"),
	}
}

// Setup configures all routes and middleware
func (r *Router) Setup() {
	// Add middleware
	r.addMiddleware()
	
	// Add routes
	r.addRoutes()
}

// GetEngine returns the gin engine
func (r *Router) GetEngine() *gin.Engine {
	return r.engine
}

// addMiddleware sets up all middleware
func (r *Router) addMiddleware() {
	// Custom logger middleware
	r.engine.Use(r.loggerMiddleware())
	
	// Recovery middleware
	r.engine.Use(gin.Recovery())
	
	// CORS middleware
	r.engine.Use(r.corsMiddleware())
	
	// Request ID middleware
	r.engine.Use(r.requestIDMiddleware())
}

// addRoutes sets up all API routes
func (r *Router) addRoutes() {
	// Health check route
	r.engine.GET("/health", r.handler.HealthCheck)
	
	// Swagger documentation
	r.engine.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))
	
	// API v1 routes
	v1 := r.engine.Group("/api/v1")
	{
		// System routes
		system := v1.Group("/system")
		{
			system.GET("/validate", r.handler.ValidateDockerInstallation)
		}
		
		// Docker routes
		docker := v1.Group("/docker")
		{
			docker.POST("/start", r.handler.StartServices)
			docker.POST("/stop", r.handler.StopServices)
			docker.POST("/restart", r.handler.RestartServices)
			docker.POST("/cleanup", r.handler.CleanupServices)
			docker.GET("/status", r.handler.GetServicesStatus)
		}
	}
}

// loggerMiddleware provides structured logging for all requests
func (r *Router) loggerMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		raw := c.Request.URL.RawQuery
		
		// Process request
		c.Next()
		
		// Calculate latency
		latency := time.Since(start)
		
		// Get client IP
		clientIP := c.ClientIP()
		
		// Get request method
		method := c.Request.Method
		
		// Get status code
		statusCode := c.Writer.Status()
		
		// Get error message if any
		errorMessage := c.Errors.ByType(gin.ErrorTypePrivate).String()
		
		// Build full path
		if raw != "" {
			path = path + "?" + raw
		}
		
		// Log request
		fields := map[string]interface{}{
			"method":      method,
			"path":        path,
			"status_code": statusCode,
			"latency":     latency.String(),
			"client_ip":   clientIP,
			"user_agent":  c.Request.UserAgent(),
		}
		
		if errorMessage != "" {
			fields["error"] = errorMessage
		}
		
		if statusCode >= 400 {
			r.logger.LogError(nil, "HTTP request completed with error", fields)
		} else {
			r.logger.LogInfo("HTTP request completed", fields)
		}
	}
}

// corsMiddleware handles CORS headers
func (r *Router) corsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		origin := c.Request.Header.Get("Origin")
		
		// Allow specific origins in production, all in development
		if r.config.Environment == "production" {
			// Add your allowed origins here
			allowedOrigins := map[string]bool{
				"http://localhost:3000":  true,
				"https://localhost:3000": true,
			}
			
			if allowedOrigins[origin] {
				c.Header("Access-Control-Allow-Origin", origin)
			}
		} else {
			// Allow all origins in development
			c.Header("Access-Control-Allow-Origin", "*")
		}
		
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, X-Request-ID")
		c.Header("Access-Control-Expose-Headers", "Content-Length, X-Request-ID")
		c.Header("Access-Control-Allow-Credentials", "true")
		
		// Handle preflight requests
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		
		c.Next()
	}
}

// requestIDMiddleware adds a unique request ID to each request
func (r *Router) requestIDMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		requestID := c.GetHeader("X-Request-ID")
		if requestID == "" {
			requestID = generateRequestID()
		}
		
		// Add request ID to context
		ctx := context.WithValue(c.Request.Context(), "request_id", requestID)
		ctx = context.WithValue(ctx, "timestamp", time.Now().Unix())
		c.Request = c.Request.WithContext(ctx)
		
		// Add request ID to response header
		c.Header("X-Request-ID", requestID)
		
		c.Next()
	}
}

// generateRequestID generates a simple request ID
func generateRequestID() string {
	return time.Now().Format("20060102-150405") + "-" + randomString(8)
}

// randomString generates a random string of specified length
func randomString(length int) string {
	const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	b := make([]byte, length)
	for i := range b {
		b[i] = charset[time.Now().UnixNano()%int64(len(charset))]
	}
	return string(b)
} 