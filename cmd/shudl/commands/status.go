package commands

import (
	"fmt"
	"net"
	"net/http"
	"time"

	"github.com/spf13/cobra"
)

var statusCmd = &cobra.Command{
	Use:   "status",
	Short: "Check ShuDL platform status",
	Long: `Check the status of ShuDL Data Lakehouse platform.
	
This command checks if ShuDL is deployed and provides information about:
- Service health and status
- Platform deployment state
- Available management endpoints`,
	RunE: runStatus,
}

func init() {
	rootCmd.AddCommand(statusCmd)
}

type PlatformStatus struct {
	Deployed   bool              `json:"deployed"`
	Services   map[string]string `json:"services,omitempty"`
	Endpoints  map[string]string `json:"endpoints,omitempty"`
	Health     string            `json:"health"`
	LastCheck  time.Time         `json:"last_check"`
	Management string            `json:"management_url"`
}

func runStatus(cmd *cobra.Command, args []string) error {
	fmt.Println("🔍 Checking ShuDL Platform Status...")
	fmt.Println()

	// Check if services are deployed
	deploymentStatus := checkDeploymentStatus()

	// Determine overall platform status
	status := determinePlatformStatus(deploymentStatus)

	// Display status
	displayStatus(status)

	return nil
}

func checkDeploymentStatus() map[string]string {
	services := make(map[string]string)

	// Check HTTP-based services
	httpServices := map[string]string{
		"Trino":        "8080",
		"MinIO":        "9000",
		"Nessie":       "19120",
		"Spark Master": "4040",
		"Spark Worker": "4041",
	}

	client := &http.Client{Timeout: 3 * time.Second}

	for service, port := range httpServices {
		// Try to connect to the port
		resp, err := client.Get(fmt.Sprintf("http://localhost:%s", port))
		if err == nil {
			services[service] = "running"
			resp.Body.Close()
		} else {
			services[service] = "not running"
		}
	}

	// Check PostgreSQL using TCP connection
	if checkTCPPort("localhost", "5432") {
		services["PostgreSQL"] = "running"
	} else {
		services["PostgreSQL"] = "not running"
	}

	return services
}

func checkTCPPort(host, port string) bool {
	conn, err := net.DialTimeout("tcp", fmt.Sprintf("%s:%s", host, port), 3*time.Second)
	if err != nil {
		return false
	}
	defer conn.Close()
	return true
}

func determinePlatformStatus(deploymentServices map[string]string) *PlatformStatus {
	status := &PlatformStatus{
		Services:  make(map[string]string),
		Endpoints: make(map[string]string),
		LastCheck: time.Now(),
	}

	// Add deployment services to status
	for service, state := range deploymentServices {
		status.Services[service] = state
	}

	// Determine overall health
	healthyServices := 0
	totalServices := len(deploymentServices)

	for _, state := range deploymentServices {
		if state == "running" {
			healthyServices++
		}
	}

	if healthyServices == totalServices {
		status.Health = "fully operational"
		status.Deployed = true
	} else if healthyServices > 0 {
		status.Health = "partially operational"
		status.Deployed = true
	} else {
		status.Health = "not deployed"
		status.Deployed = false
	}

	return status
}

func displayStatus(status *PlatformStatus) {
	fmt.Println("📊 ShuDL Platform Status")
	fmt.Println("=" + string(make([]byte, 50)))

	if status.Deployed {
		fmt.Printf("✅ Platform Status: %s\n", status.Health)
		fmt.Printf("🕒 Last Check: %s\n", status.LastCheck.Format("2006-01-02 15:04:05"))
		fmt.Println()

		fmt.Println("📦 Service Status:")
		for service, state := range status.Services {
			icon := "✅"
			if state != "running" {
				icon = "❌"
			}
			fmt.Printf("   %s %s: %s\n", icon, service, state)
		}
		fmt.Println()

		fmt.Println("🔗 Available Services:")
		fmt.Println("   • Trino: http://localhost:8080")
		fmt.Println("   • MinIO: http://localhost:9000")
		fmt.Println("   • Spark Master: http://localhost:4040")
		fmt.Println("   • Spark Worker: http://localhost:4041")
		fmt.Println("   • Nessie: http://localhost:19120")
		fmt.Println()

		fmt.Println("🎯 Day 2 Activities Available:")
		fmt.Println("   • CLI: Status checking and configuration management")
		fmt.Println("   • Docker: Direct container management")

	} else {
		fmt.Println("❌ Platform Status: Not deployed")
		fmt.Println()
		fmt.Println("🚀 Day 1 Activities Required:")
		fmt.Println("   • Deploy the ShuDL platform")
		fmt.Println("   • Use: ./bin/shudl inst deploy")
	}

	fmt.Println()
	fmt.Println("💡 Usage:")
	fmt.Println("   Deploy: ./bin/shudl inst deploy")
	fmt.Println("   Status: ./bin/shudl ctl status")
	fmt.Println("   Help:   ./bin/shudl ctl --help")
} 