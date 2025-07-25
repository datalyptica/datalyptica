package commands

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/shudl/shudl/internal/pkg/logger"
	"github.com/shudl/shudl/internal/services/compose"
	"github.com/spf13/cobra"
)

var (
	deployServices  []string
	deployConfig    string
	deployValidate  bool
	deployNoConfirm bool
)

// deployCmd represents the deploy command
var deployCmd = &cobra.Command{
	Use:   "deploy",
	Short: "Deploy ShuDL services",
	Long: `Deploy one or more ShuDL services to your environment.

This command will start the deployment process for the specified services.
By default, it deploys all core services of the ShuDL Data Lakehouse stack.

Examples:
  shudlctl deploy                           # Deploy all services
  shudlctl deploy --services nessie,trino  # Deploy specific services
  shudlctl deploy --config production.yaml # Deploy with custom config
  shudlctl deploy --validate               # Validate before deployment`,
	RunE: func(cmd *cobra.Command, args []string) error {
		return runDeploy()
	},
}

func runDeploy() error {
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

	// Validate system if requested
	if deployValidate {
		fmt.Println("🔍 Validating system requirements...")
		if err := validateSystem(); err != nil {
			fmt.Printf("❌ System validation failed: %v\n", err)
			return err
		}
		fmt.Println("✅ System validation passed")
		fmt.Println()
	}

	// Default services if none specified
	servicesToDeploy := deployServices
	if len(servicesToDeploy) == 0 {
		servicesToDeploy = []string{"postgresql", "minio", "nessie", "trino", "spark-master", "spark-worker"}
	}

	// Confirm deployment
	if !deployNoConfirm {
		fmt.Printf("📋 About to deploy services: %s\n", strings.Join(servicesToDeploy, ", "))
		if deployConfig != "" {
			fmt.Printf("📄 Using configuration: %s\n", deployConfig)
		}
		fmt.Print("Continue? (y/N): ")

		var response string
		fmt.Scanln(&response)
		if strings.ToLower(response) != "y" && strings.ToLower(response) != "yes" {
			fmt.Println("❌ Deployment cancelled")
			return nil
		}
		fmt.Println()
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
	fmt.Println("   • Trino: http://localhost:8080")
	fmt.Println("   • MinIO: http://localhost:9000")
	fmt.Println("   • Spark Master: http://localhost:4040")
	fmt.Println("   • Spark Worker: http://localhost:4041")
	fmt.Println("   • Nessie: http://localhost:19120")
	fmt.Println()
	fmt.Println("💡 Use 'shudl ctl status' to check service health")

	return nil
}

func validateSystem() error {
	// Check Docker
	dockerCmd := exec.Command("docker", "--version")
	if err := dockerCmd.Run(); err != nil {
		return fmt.Errorf("Docker is not installed or not accessible: %w", err)
	}

	// Check Docker Compose
	composeCmd := exec.Command("docker", "compose", "version")
	if err := composeCmd.Run(); err != nil {
		return fmt.Errorf("Docker Compose is not available: %w", err)
	}

	return nil
}

func init() {
	rootCmd.AddCommand(deployCmd)

	deployCmd.Flags().StringSliceVar(&deployServices, "services", []string{}, "Services to deploy (comma-separated)")
	deployCmd.Flags().StringVar(&deployConfig, "config", "", "Configuration file path")
	deployCmd.Flags().BoolVar(&deployValidate, "validate", true, "Validate system before deployment")
	deployCmd.Flags().BoolVar(&deployNoConfirm, "yes", false, "Skip confirmation prompt")
} 