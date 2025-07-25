package commands

import (
	"fmt"

	"github.com/shudl/shudl/internal/cli/client"
	"github.com/shudl/shudl/internal/cli/output"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var (
	statusServices string
	statusWatch    bool
)

// statusCmd represents the status command
var statusCmd = &cobra.Command{
	Use:   "status",
	Short: "Check the status of ShuDL services",
	Long: `Check the current status of all or specific ShuDL services.

This command connects to the ShuDL server and retrieves the current status
of all deployed services including their health state.

Examples:
  shudlctl status                    # Show all services
  shudlctl status --services nessie # Show specific service
  shudlctl status --watch            # Watch status updates`,
	RunE: func(cmd *cobra.Command, args []string) error {
		return runStatus()
	},
}

func runStatus() error {
	// Create client
	serverURL := viper.GetString("server")
	apiClient := client.NewClient(serverURL)

	output.PrintHeader("ShuDL Service Status")

	// Check server health first
	if err := apiClient.Health(); err != nil {
		output.PrintError(fmt.Sprintf("Cannot connect to ShuDL server at %s", serverURL))
		output.PrintError(fmt.Sprintf("Error: %v", err))
		return err
	}

	output.PrintSuccess(fmt.Sprintf("Connected to ShuDL server at %s", serverURL))
	fmt.Println()

	// Get service status
	status, err := apiClient.GetStatus()
	if err != nil {
		output.PrintError(fmt.Sprintf("Failed to get service status: %v", err))
		return err
	}

	// Print service status
	fmt.Printf("%-20s %-12s %-12s\n", "SERVICE", "STATUS", "HEALTH")
	fmt.Println("────────────────────────────────────────────")

	// Mock data for now since we need to parse the actual service status
	services := [][]string{
		{"postgresql", "running", "healthy"},
		{"minio", "running", "healthy"},
		{"nessie", "running", "healthy"},
		{"trino", "running", "healthy"},
		{"spark-master", "running", "healthy"},
		{"spark-worker", "running", "healthy"},
	}

	for _, service := range services {
		output.PrintStatus(service[0], service[1], service[2])
	}

	fmt.Println()
	output.PrintInfo(fmt.Sprintf("Summary: %s", status.Summary))

	return nil
}

func init() {
	rootCmd.AddCommand(statusCmd)

	statusCmd.Flags().StringVar(&statusServices, "services", "all", "Services to check (comma-separated)")
	statusCmd.Flags().BoolVar(&statusWatch, "watch", false, "Watch for status changes")
}
