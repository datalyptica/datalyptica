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
	log.LogInfo("Starting ShuDL Docker Installer", map[string]interface{}{
		"version":     "1.0.0",
		"environment": cfg.Logger.Environment,
		"port":        cfg.Server.Port,
	})

	// Initialize docker service
	dockerService := docker.NewService(&cfg.Docker, log)

	// Validate Docker installation
	log.LogInfo("Validating Docker installation", nil)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	validationResult, err := dockerService.ValidateDockerInstallation(ctx)
	if err != nil {
		log.LogError(err, "Docker validation failed", map[string]interface{}{
			"error": err.Error(),
		})
		os.Exit(1)
	}

	if !validationResult.Success {
		log.LogError(nil, "Docker validation failed", map[string]interface{}{
			"output": validationResult.Output,
			"error":  validationResult.Error,
		})
		os.Exit(1)
	}

	log.LogInfo("Docker validation successful", map[string]interface{}{
		"output": validationResult.Output,
	})

	// Initialize handlers
	apiHandler := api.NewHandler(dockerService, log)
	composeHandler := api.NewComposeHandler("./generated", log)
	webHandler := api.NewWebHandler(log)

	// Initialize router with all handlers
	router := api.NewRouter(apiHandler, composeHandler, webHandler, &cfg.Server, log)
	router.Setup()

	// Create HTTP server
	server := &http.Server{
		Addr:         fmt.Sprintf(":%d", cfg.Server.Port),
		Handler:      router.GetEngine(),
		ReadTimeout:  time.Duration(cfg.Server.ReadTimeout) * time.Second,
		WriteTimeout: time.Duration(cfg.Server.WriteTimeout) * time.Second,
	}

	// Start server in a goroutine
	go func() {
		log.LogInfo("Starting HTTP server", map[string]interface{}{
			"address":    server.Addr,
			"swagger_ui": fmt.Sprintf("http://localhost:%d/swagger/", cfg.Server.Port),
			"installer":  fmt.Sprintf("http://localhost:%d/", cfg.Server.Port),
		})

		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.LogError(err, "Server failed to start", map[string]interface{}{
				"error": err.Error(),
			})
			os.Exit(1)
		}
	}()

	// Wait for interrupt signal to gracefully shutdown the server
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.LogInfo("Shutting down server...", nil)

	// Give outstanding requests 30 seconds to complete
	ctx, cancel = context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.LogError(err, "Server forced to shutdown", map[string]interface{}{
			"error": err.Error(),
		})
		os.Exit(1)
	}

	log.LogInfo("Server gracefully stopped", nil)
} 