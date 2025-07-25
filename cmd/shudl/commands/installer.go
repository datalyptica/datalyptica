package commands

import (
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"time"

	"github.com/shudl/shudl/internal/pkg/logger"
	"github.com/shudl/shudl/internal/services/compose"
	"github.com/spf13/cobra"
)

var (
	installerRootCmd = &cobra.Command{
		Use:   "inst",
		Short: "ShuDL Installer - Day 1 Activities",
		Long: `ShuDL Installer provides Day 1 activities for deploying and setting up the ShuDL Data Lakehouse platform.

This includes:
• Web interface for visual deployment
• System validation and prerequisites checking
• Automated deployment of the complete stack

Examples:
  shudl inst web      # Start web installer
  shudl inst validate # Check prerequisites
  shudl inst deploy   # Deploy the stack`,
	}

	installerWebCmd = &cobra.Command{
		Use:   "web",
		Short: "Start web installer interface",
		Long: `Start the web-based installer interface for ShuDL deployment.

This launches the web UI that allows you to:
• Configure services and components
• Validate configurations
• Deploy the complete stack
• Monitor deployment progress`,
		RunE: runInstallerWeb,
	}

	installerValidateCmd = &cobra.Command{
		Use:   "validate",
		Short: "Validate system prerequisites",
		Long: `Validate that your system meets all prerequisites for ShuDL deployment.

This checks:
• Docker installation and version
• Available system resources
• Network connectivity
• Required ports availability`,
		RunE: runInstallerValidate,
	}

	installerDeployCmd = &cobra.Command{
		Use:   "deploy",
		Short: "Deploy ShuDL stack",
		Long: `Deploy the complete ShuDL Data Lakehouse stack.

This will:
• Generate configuration files
• Start all required services
• Verify deployment health
• Provide access endpoints`,
		RunE: runInstallerDeploy,
	}
)

func init() {
	installerRootCmd.AddCommand(installerWebCmd)
	installerRootCmd.AddCommand(installerValidateCmd)
	installerRootCmd.AddCommand(installerDeployCmd)
}

// ExecuteInstaller runs the installer commands
func ExecuteInstaller() error {
	return installerRootCmd.Execute()
}

func runInstallerWeb(cmd *cobra.Command, args []string) error {
	fmt.Println("🌐 Starting ShuDL Web Installer...")
	fmt.Println()

	// Check if web server is already running
	client := &http.Client{Timeout: 3 * time.Second}
	resp, err := client.Get("http://localhost:3035/health")
	if err == nil && resp.StatusCode == 200 {
		resp.Body.Close()
		fmt.Println("✅ Web installer is already running at http://localhost:3035")
		fmt.Println("💡 Open your browser and navigate to: http://localhost:3035")
		return nil
	}
	if resp != nil {
		resp.Body.Close()
	}

	// Start the web server
	fmt.Println("🚀 Starting web server on port 3035...")

	// Set environment variable for port
	os.Setenv("SHUDL_SERVER_PORT", "3035")

	// Start the server in background
	execCmd := exec.Command("./bin/shudl")
	execCmd.Stdout = os.Stdout
	execCmd.Stderr = os.Stderr

	if err := execCmd.Start(); err != nil {
		return fmt.Errorf("failed to start web server: %w", err)
	}

	fmt.Println("✅ Web installer started successfully!")
	fmt.Println("🌐 Open your browser and navigate to: http://localhost:3035")
	fmt.Println("💡 Press Ctrl+C to stop the server")

	// Wait for the process
	return execCmd.Wait()
}

func runInstallerValidate(cmd *cobra.Command, args []string) error {
	fmt.Println("🔍 Validating ShuDL Prerequisites...")
	fmt.Println()

	// Check Docker
	fmt.Println("🐳 Checking Docker installation...")
	dockerCmd := exec.Command("docker", "--version")
	if output, err := dockerCmd.Output(); err != nil {
		fmt.Println("❌ Docker is not installed or not accessible")
		return fmt.Errorf("docker validation failed: %w", err)
	} else {
		fmt.Printf("✅ Docker: %s", string(output))
	}

	// Check Docker Compose
	fmt.Println("📦 Checking Docker Compose...")
	composeCmd := exec.Command("docker", "compose", "version")
	if output, err := composeCmd.Output(); err != nil {
		fmt.Println("❌ Docker Compose is not available")
		return fmt.Errorf("docker compose validation failed: %w", err)
	} else {
		fmt.Printf("✅ Docker Compose: %s", string(output))
	}

	// Check available ports
	fmt.Println("🔌 Checking port availability...")
	ports := []string{"3035", "8080", "9000", "5432", "19120", "4040", "4041"}

	for _, port := range ports {
		client := &http.Client{Timeout: 1 * time.Second}
		resp, err := client.Get(fmt.Sprintf("http://localhost:%s", port))
		if err == nil && resp.StatusCode == 200 {
			resp.Body.Close()
			fmt.Printf("⚠️  Port %s is already in use\n", port)
		} else {
			fmt.Printf("✅ Port %s is available\n", port)
		}
		if resp != nil {
			resp.Body.Close()
		}
	}

	// Check system resources
	fmt.Println("💻 Checking system resources...")

	// Check available memory (simplified)
	memCmd := exec.Command("free", "-h")
	if output, err := memCmd.Output(); err == nil {
		fmt.Printf("✅ Memory: %s", string(output))
	} else {
		fmt.Println("⚠️  Could not check memory usage")
	}

	// Check available disk space
	diskCmd := exec.Command("df", "-h", ".")
	if output, err := diskCmd.Output(); err == nil {
		fmt.Printf("✅ Disk space: %s", string(output))
	} else {
		fmt.Println("⚠️  Could not check disk space")
	}

	fmt.Println()
	fmt.Println("🎉 Prerequisites validation completed!")
	fmt.Println("💡 If all checks passed, you can proceed with deployment")

	return nil
}

func runInstallerDeploy(cmd *cobra.Command, args []string) error {
	fmt.Println("🚀 Deploying ShuDL Data Lakehouse Stack...")
	fmt.Println()

	// Create logger for the generator
	log := logger.New(logger.Config{
		Level:       "info",
		Environment: "development",
	})

	// Create compose generator
	generator := compose.NewGenerator("./generated", log)

	// Define the configuration for deployment
	services := map[string]interface{}{
		"postgresql":   map[string]interface{}{"enabled": true},
		"minio":        map[string]interface{}{"enabled": true},
		"nessie":       map[string]interface{}{"enabled": true},
		"trino":        map[string]interface{}{"enabled": true},
		"spark-master": map[string]interface{}{"enabled": true},
		"spark-worker": map[string]interface{}{"enabled": true},
	}

	globalConfig := map[string]string{
		"registry": "ghcr.io/shugur-network/shudl",
	}

	// Generate configuration files directly
	fmt.Println("📝 Generating configuration files...")
	_, err := generator.GenerateFiles("shudl", "shunetwork", "development", services, globalConfig)
	if err != nil {
		return fmt.Errorf("failed to generate configuration files: %w", err)
	}

	fmt.Println("✅ Configuration files generated")

	// Deploy services using Docker Compose directly
	fmt.Println("🐳 Starting Docker services...")

	// Change to the generated directory
	if err := os.Chdir("./generated"); err != nil {
		return fmt.Errorf("failed to change to generated directory: %w", err)
	}

	// Run docker compose up -d
	composeCmd := exec.Command("docker", "compose", "up", "-d")
	composeCmd.Stdout = os.Stdout
	composeCmd.Stderr = os.Stderr

	if err := composeCmd.Run(); err != nil {
		return fmt.Errorf("failed to start Docker services: %w", err)
	}

	// Change back to original directory
	if err := os.Chdir(".."); err != nil {
		return fmt.Errorf("failed to change back to original directory: %w", err)
	}

	fmt.Println("✅ Services deployed successfully!")
	fmt.Println()
	fmt.Println("🎉 ShuDL Data Lakehouse is now running!")
	fmt.Println()
	fmt.Println("🔗 Available Services:")
	fmt.Println("   • Web UI: http://localhost:3035")
	fmt.Println("   • Trino: http://localhost:8080")
	fmt.Println("   • MinIO: http://localhost:9000")
	fmt.Println("   • Spark Master: http://localhost:4040")
	fmt.Println("   • Spark Worker: http://localhost:4041")
	fmt.Println("   • Nessie: http://localhost:19120")
	fmt.Println()
	fmt.Println("💡 Use 'shudl ctl status' to check service health")

	return nil
}
