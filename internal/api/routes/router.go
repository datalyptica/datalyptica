package routes

import (
	"html/template"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/shudl/shudl/internal/api/handlers/compose"
	"github.com/shudl/shudl/internal/api/handlers/docker"
	"github.com/shudl/shudl/internal/api/handlers/health"
	"github.com/shudl/shudl/internal/api/handlers/web"
	"github.com/shudl/shudl/internal/pkg/logger"
	"github.com/shudl/shudl/internal/services/config"
	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"
)

// Router handles HTTP routing
type Router struct {
	engine         *gin.Engine
	healthHandler  *health.Handler
	dockerHandler  *docker.Handler
	composeHandler *compose.Handler
	webHandler     *web.Handler
	config         *config.ServerConfig
	logger         *logger.Logger
}

// NewRouter creates a new router with all handlers
func NewRouter(
	healthHandler *health.Handler,
	dockerHandler *docker.Handler,
	composeHandler *compose.Handler,
	webHandler *web.Handler,
	serverConfig *config.ServerConfig,
	log *logger.Logger,
) *Router {
	if serverConfig.Environment == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	return &Router{
		engine:         gin.New(),
		healthHandler:  healthHandler,
		dockerHandler:  dockerHandler,
		composeHandler: composeHandler,
		webHandler:     webHandler,
		config:         serverConfig,
		logger:         log.WithComponent("router"),
	}
}

// Setup configures middleware and routes
func (r *Router) Setup() {
	// Load HTML templates
	tmpl := template.Must(template.New("").ParseFiles("web/templates/installer/index.html"))
	r.engine.SetHTMLTemplate(tmpl)

	// Serve static files
	r.engine.Static("/static", "web/static")

	r.setupMiddleware()
	r.setupRoutes()
}

// setupMiddleware configures middleware
func (r *Router) setupMiddleware() {
	// Recovery middleware
	r.engine.Use(gin.Recovery())

	// CORS middleware
	corsConfig := cors.DefaultConfig()
	corsConfig.AllowOrigins = []string{"*"} // TODO: Configure properly for production
	corsConfig.AllowMethods = []string{"GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"}
	corsConfig.AllowHeaders = []string{"Origin", "Content-Length", "Content-Type", "Authorization"}
	r.engine.Use(cors.New(corsConfig))

	// Custom logging middleware
	r.engine.Use(r.loggingMiddleware())
}

// setupRoutes configures all routes
func (r *Router) setupRoutes() {
	// Health check routes (no prefix)
	r.engine.GET("/health", r.healthHandler.Health)
	r.engine.GET("/ready", r.healthHandler.Ready)
	r.engine.GET("/live", r.healthHandler.Live)

	// Web interface routes
	r.engine.GET("/", r.webHandler.ServePage)

	// API routes
	api := r.engine.Group("/api/v1")
	{
		// Web API routes
		webAPI := api.Group("/web")
		{
			webAPI.GET("/config", r.webHandler.GetInstallationConfig)
			webAPI.POST("/save-config", r.webHandler.SaveConfiguration)
			webAPI.GET("/progress", r.webHandler.GetDeploymentProgress)
		}

		// Docker API routes
		dockerAPI := api.Group("/docker")
		{
			dockerAPI.GET("/validate", r.dockerHandler.ValidateInstallation)
			dockerAPI.GET("/status", r.dockerHandler.GetStatus)
			dockerAPI.GET("/logs", r.dockerHandler.GetLogs)
			dockerAPI.POST("/start", r.dockerHandler.StartServices)
			dockerAPI.POST("/stop", r.dockerHandler.StopServices)
			dockerAPI.POST("/restart", r.dockerHandler.RestartServices)
		}

		// Compose API routes
		composeAPI := api.Group("/compose")
		{
			composeAPI.GET("/defaults", r.composeHandler.GetDefaultConfigurations)
			composeAPI.GET("/services", r.composeHandler.GetServices)
			composeAPI.GET("/services/:service/template", r.composeHandler.GetServiceTemplate)
			composeAPI.POST("/generate", r.composeHandler.GenerateFiles)
			composeAPI.POST("/validate", r.composeHandler.ValidateConfiguration)
			composeAPI.POST("/preview", r.composeHandler.PreviewConfiguration)
		}
	}

	// Swagger documentation
	if r.config.Environment == "development" {
		r.engine.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))
	}
}

// loggingMiddleware creates a custom logging middleware
func (r *Router) loggingMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Start timer
		start := time.Now()

		// Process request
		c.Next()

		// Calculate latency
		latency := time.Since(start)

		// Log request
		r.logger.LogInfo("HTTP Request", map[string]interface{}{
			"method":     c.Request.Method,
			"path":       c.Request.URL.Path,
			"status":     c.Writer.Status(),
			"latency":    latency.String(),
			"client_ip":  c.ClientIP(),
			"user_agent": c.Request.UserAgent(),
			"request_id": c.GetHeader("X-Request-ID"),
		})
	}
}

// GetEngine returns the Gin engine
func (r *Router) GetEngine() *gin.Engine {
	return r.engine
}
