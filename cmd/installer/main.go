// @title Shudl Docker Installer API
// @version 1.0
// @description A Docker installer API that provides endpoints to manage Docker services through a web interface
// @termsOfService http://swagger.io/terms/

// @contact.name API Support
// @contact.url http://www.swagger.io/support
// @contact.email support@swagger.io

// @license.name MIT
// @license.url https://opensource.org/licenses/MIT

// @host localhost:8080
// @BasePath /api/v1
// @schemes http https

package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/shudl/shudl/internal/api"
	"github.com/shudl/shudl/internal/config"
	"github.com/shudl/shudl/internal/docker"
	"github.com/shudl/shudl/internal/logger"
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
	log.LogInfo("Starting Shudl Docker Installer", map[string]interface{}{
		"version":     "1.0.0",
		"environment": cfg.Server.Environment,
		"port":        cfg.Server.Port,
	})

	// Initialize Docker service
	dockerService := docker.NewService(&cfg.Docker, log)

	// Validate Docker installation
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	validationResult, err := dockerService.ValidateDockerInstallation(ctx)
	if err != nil {
		log.LogError(err, "Failed to validate Docker installation", nil)
		os.Exit(1)
	}

	if !validationResult.Success {
		log.LogError(nil, "Docker validation failed", map[string]interface{}{
			"error":   validationResult.Error,
			"message": validationResult.Message,
		})
		log.LogInfo("Please ensure Docker and Docker Compose are installed and accessible", nil)
		os.Exit(1)
	}

	log.LogInfo("Docker installation validated successfully", map[string]interface{}{
		"output": validationResult.Output,
	})

	// Initialize API handler
	apiHandler := api.NewHandler(dockerService, log)

	// Initialize compose handler
	composeHandler := api.NewComposeHandler("./generated", log)

	// Initialize router
	router := api.NewRouter(apiHandler, composeHandler, &cfg.Server, log)
	router.Setup()

	// Create HTTP server
	server := &http.Server{
		Addr:         fmt.Sprintf("%s:%d", cfg.Server.Host, cfg.Server.Port),
		Handler:      router.GetEngine(),
		ReadTimeout:  time.Duration(cfg.Server.ReadTimeout) * time.Second,
		WriteTimeout: time.Duration(cfg.Server.WriteTimeout) * time.Second,
	}

	// Start server in a goroutine
	go func() {
		log.LogInfo("Starting HTTP server", map[string]interface{}{
			"address": server.Addr,
		})

		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.LogError(err, "Failed to start HTTP server", nil)
			os.Exit(1)
		}
	}()

	log.LogInfo("Server started successfully", map[string]interface{}{
		"address":    server.Addr,
		"swagger":    fmt.Sprintf("http://%s:%d/swagger/index.html", cfg.Server.Host, cfg.Server.Port),
		"health":     fmt.Sprintf("http://%s:%d/health", cfg.Server.Host, cfg.Server.Port),
	})

	// Wait for interrupt signal to gracefully shutdown the server
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.LogInfo("Shutting down server...", nil)

	// Create context with timeout for shutdown
	ctx, cancel = context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Shutdown server
	if err := server.Shutdown(ctx); err != nil {
		log.LogError(err, "Server forced to shutdown", nil)
		os.Exit(1)
	}

	log.LogInfo("Server shutdown complete", nil)
} 