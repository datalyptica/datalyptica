package commands

import (
	"fmt"
	"strings"

	"github.com/shudl/shudl/internal/cli/client"
	"github.com/shudl/shudl/internal/cli/output"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
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
	// Create client
	serverURL := viper.GetString("server")
	apiClient := client.NewClient(serverURL)

	output.PrintHeader("ShuDL Service Deployment")

	// Check server health first
	if err := apiClient.Health(); err != nil {
		output.PrintError(fmt.Sprintf("Cannot connect to ShuDL server at %s", serverURL))
		output.PrintError(fmt.Sprintf("Error: %v", err))
		return err
	}

	output.PrintSuccess(fmt.Sprintf("Connected to ShuDL server at %s", serverURL))

	// Validate system if requested
	if deployValidate {
		output.PrintInfo("Validating system requirements...")
		if err := apiClient.ValidateSystem(); err != nil {
			output.PrintError(fmt.Sprintf("System validation failed: %v", err))
			return err
		}
		output.PrintSuccess("System validation passed")
	}

	// Default services if none specified
	services := deployServices
	if len(services) == 0 {
		services = []string{"postgresql", "minio", "nessie", "trino", "spark-master", "spark-worker"}
	}

	// Confirm deployment
	if !deployNoConfirm {
		output.PrintInfo(fmt.Sprintf("About to deploy services: %s", strings.Join(services, ", ")))
		if deployConfig != "" {
			output.PrintInfo(fmt.Sprintf("Using configuration: %s", deployConfig))
		}
		fmt.Print("Continue? (y/N): ")

		var response string
		fmt.Scanln(&response)
		if strings.ToLower(response) != "y" && strings.ToLower(response) != "yes" {
			output.PrintWarning("Deployment cancelled")
			return nil
		}
	}

	// Start deployment
	output.PrintInfo(fmt.Sprintf("Starting deployment of %d services...", len(services)))

	if err := apiClient.Deploy(services, deployConfig); err != nil {
		output.PrintError(fmt.Sprintf("Deployment failed: %v", err))
		return err
	}

	output.PrintSuccess("Deployment started successfully!")
	output.PrintInfo("Use 'shudlctl status' to monitor deployment progress")

	// Print service endpoints
	fmt.Println()
	output.PrintHeader("Service Endpoints")
	endpoints := [][]string{
		{"Service", "URL", "Purpose"},
		{"Trino Web UI", "http://localhost:8080", "SQL Query Interface"},
		{"Spark Master UI", "http://localhost:4040", "Spark Cluster Management"},
		{"MinIO Console", "http://localhost:9001", "Object Storage Management"},
		{"Nessie API", "http://localhost:19120", "Data Catalog API"},
		{"ShuDL Installer", "http://localhost:8080", "Platform Management"},
	}

	output.PrintTable(endpoints[0], endpoints[1:])

	return nil
}

func init() {
	rootCmd.AddCommand(deployCmd)

	deployCmd.Flags().StringSliceVar(&deployServices, "services", []string{}, "Services to deploy (comma-separated)")
	deployCmd.Flags().StringVar(&deployConfig, "config", "", "Configuration file path")
	deployCmd.Flags().BoolVar(&deployValidate, "validate", true, "Validate system before deployment")
	deployCmd.Flags().BoolVar(&deployNoConfirm, "yes", false, "Skip confirmation prompt")
}
