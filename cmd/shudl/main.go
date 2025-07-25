// @title ShuDL Data Lakehouse Platform
// @version 1.0.0
// @description Unified platform for ShuDL Data Lakehouse deployment and management
// @host localhost:3035
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

	"github.com/shudl/shudl/cmd/shudl/commands"
	"github.com/shudl/shudl/internal/api/handlers/compose"
	"github.com/shudl/shudl/internal/api/handlers/docker"
	"github.com/shudl/shudl/internal/api/handlers/health"
	"github.com/shudl/shudl/internal/api/handlers/web"
	"github.com/shudl/shudl/internal/api/routes"
	"github.com/shudl/shudl/internal/pkg/logger"
	"github.com/shudl/shudl/internal/services/config"
	dockerService "github.com/shudl/shudl/internal/services/docker"
)

// Version information
var (
	Version   = "1.0.0"
	GitCommit = "dev"
	BuildDate = "unknown"
)

func main() {
	// Check if running in installer mode
	if len(os.Args) > 1 && os.Args[1] == "installer" {
		runInstaller()
		return
	}

	// Check if running in inst mode (short for installer)
	if len(os.Args) > 1 && os.Args[1] == "inst" {
		runInstaller()
		return
	}

	// Check if running in ctl mode (replaces cli)
	if len(os.Args) > 1 && os.Args[1] == "ctl" {
		runCtl()
		return
	}

	// Default: Run as web application (installer + management UI)
	runWebApp()
}

// runInstaller executes the installer commands (Day 1 activities)
func runInstaller() {
	// Set version information for the installer
	commands.SetVersion(Version, GitCommit, BuildDate)

	// Remove "installer" or "inst" from args so commands work properly
	if len(os.Args) > 1 {
		if os.Args[1] == "installer" || os.Args[1] == "inst" {
			os.Args = append(os.Args[:1], os.Args[2:]...)
		}
	}

	// Execute the installer root command
	if err := commands.ExecuteInstaller(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

// runCtl executes the ctl commands (Day 2 activities)
func runCtl() {
	// Set version information for the ctl
	commands.SetVersion(Version, GitCommit, BuildDate)

	// Remove "ctl" from args so commands work properly
	os.Args = append(os.Args[:1], os.Args[2:]...)

	// Execute the root command
	if err := commands.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

// runWebApp runs the web application (Day 1 installer + Day 2 management)
func runWebApp() {
	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		fmt.Printf("Failed to load configuration: %v\n", err)
		os.Exit(1)
	}

	// Initialize logger
	log := logger.New(cfg.Logger)
	log.LogInfo("Starting ShuDL Data Lakehouse Platform", map[string]interface{}{
		"version":     Version,
		"environment": cfg.Logger.Environment,
		"port":        cfg.Server.Port,
		"mode":        "web-application",
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
	composeHandler := compose.NewHandler("./generated", log)
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

	// Create a deadline for server shutdown
	ctx, cancel = context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Attempt graceful shutdown
	if err := server.Shutdown(ctx); err != nil {
		log.LogError(err, "Server forced to shutdown", nil)
	}

	log.LogInfo("Server exited", nil)
}
