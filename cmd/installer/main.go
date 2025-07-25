// @title ShuDL Docker Installer API
// @version 1.0.0
// @description REST API for managing ShuDL Docker services with intelligent configuration generation
// @host localhost:8084
// @BasePath /api/v1
package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/shudl/shudl/internal/api/handlers/compose"
	"github.com/shudl/shudl/internal/api/handlers/docker"
	"github.com/shudl/shudl/internal/api/handlers/health"
	"github.com/shudl/shudl/internal/api/handlers/web"
	"github.com/shudl/shudl/internal/api/routes"
	"github.com/shudl/shudl/internal/pkg/logger"
	"github.com/shudl/shudl/internal/services/config"
	dockerService "github.com/shudl/shudl/internal/services/docker"
)

func main() {
	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		fmt.Printf("Failed to load configuration: %v\n", err)
		os.Exit(1)
	}

	// Initialize logger
	log := logger.New(cfg.Logger)
	log.LogInfo("Starting ShuDL Docker Installer", map[string]interface{}{
		"version":     "1.0.0",
		"environment": cfg.Logger.Environment,
		"port":        cfg.Server.Port,
	})

	// Initialize services
	dockerSvc := dockerService.NewService(&cfg.Docker, log)

	// Validate Docker installation
	log.LogInfo("Validating Docker installation", nil)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	validationResult, err := dockerSvc.ValidateDockerInstallation(ctx)
	if err != nil {
		log.LogError(err, "Docker validation failed", map[string]interface{}{
			"error": err.Error(),
		})
		// Continue anyway - validation failures are logged but not fatal
	} else if validationResult.Valid {
		log.LogInfo("Docker validation successful", map[string]interface{}{
			"details": validationResult.Details,
		})
	} else {
		log.LogWarn("Docker validation issues found", map[string]interface{}{
			"errors": validationResult.Errors,
		})
	}

	// Initialize handlers
	healthHandler := health.NewHandler(log)
	dockerHandler := docker.NewHandler(dockerSvc, log)
	composeHandler := compose.NewHandler("./generated", log) // TODO: Make configurable
	webHandler := web.NewHandler(log)

	// Initialize router
	router := routes.NewRouter(
		healthHandler,
		dockerHandler,
		composeHandler,
		webHandler,
		&cfg.Server,
		log,
	)

	// Setup routes and middleware
	router.Setup()

	// Create HTTP server
	server := &http.Server{
		Addr:    fmt.Sprintf(":%d", cfg.Server.Port),
		Handler: router.GetEngine(),
	}

	// Start server in a goroutine
	go func() {
		log.LogInfo("Starting HTTP server", map[string]interface{}{
			"port": cfg.Server.Port,
			"addr": server.Addr,
		})

		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.LogError(err, "Failed to start server", nil)
			os.Exit(1)
		}
	}()

	// Wait for interrupt signal to gracefully shutdown the server
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.LogInfo("Shutting down server...", nil)

	// Gracefully shutdown the server with a 30 second timeout
	ctx, cancel = context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.LogError(err, "Server forced to shutdown", nil)
		os.Exit(1)
	}

	log.LogInfo("Server gracefully stopped", nil)
}
