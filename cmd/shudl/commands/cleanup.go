package commands

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
)

var cleanupCmd = &cobra.Command{
	Use:   "cleanup",
	Short: "Clean up ShuDL environment",
	Long: `Clean up ShuDL Data Lakehouse platform environment.
	
This command performs a complete cleanup of:
- Docker containers and services
- Docker volumes and networks
- Generated configuration files
- Backup files (optional)
- Temporary files and logs

Use with caution as this will remove all ShuDL data and configurations.`,
	RunE: runCleanup,
}

var (
	cleanupBackups bool
	cleanupLogs    bool
	forceCleanup   bool
)

func init() {
	rootCmd.AddCommand(cleanupCmd)

	cleanupCmd.Flags().BoolVar(&cleanupBackups, "backups", false, "Also remove backup directories")
	cleanupCmd.Flags().BoolVar(&cleanupLogs, "logs", false, "Also remove log files")
	cleanupCmd.Flags().BoolVar(&forceCleanup, "force", false, "Skip confirmation prompt")
}

func runCleanup(cmd *cobra.Command, args []string) error {
	fmt.Println("🧹 Starting ShuDL Environment Cleanup...")
	fmt.Println()

	if !forceCleanup {
		fmt.Println("⚠️  WARNING: This will remove all ShuDL containers, data, and configurations!")
		fmt.Println("   This action cannot be undone.")
		fmt.Println()
		fmt.Print("Are you sure you want to continue? (y/N): ")

		var response string
		fmt.Scanln(&response)

		if response != "y" && response != "Y" {
			fmt.Println("❌ Cleanup cancelled.")
			return nil
		}
		fmt.Println()
	}

	// Track cleanup results
	results := make(map[string]bool)

	// 1. Stop and remove Docker containers
	fmt.Println("📦 Cleaning up Docker containers...")
	if err := cleanupDockerContainers(); err != nil {
		fmt.Printf("⚠️  Warning: Docker cleanup failed: %v\n", err)
		results["docker_containers"] = false
	} else {
		fmt.Println("✅ Docker containers cleaned up")
		results["docker_containers"] = true
	}

	// 2. Remove Docker volumes
	fmt.Println("💾 Cleaning up Docker volumes...")
	if err := cleanupDockerVolumes(); err != nil {
		fmt.Printf("⚠️  Warning: Volume cleanup failed: %v\n", err)
		results["docker_volumes"] = false
	} else {
		fmt.Println("✅ Docker volumes cleaned up")
		results["docker_volumes"] = true
	}

	// 3. Remove Docker networks
	fmt.Println("🌐 Cleaning up Docker networks...")
	if err := cleanupDockerNetworks(); err != nil {
		fmt.Printf("⚠️  Warning: Network cleanup failed: %v\n", err)
		results["docker_networks"] = false
	} else {
		fmt.Println("✅ Docker networks cleaned up")
		results["docker_networks"] = true
	}

	// 4. Remove generated files
	fmt.Println("📄 Cleaning up generated files...")
	if err := cleanupGeneratedFiles(); err != nil {
		fmt.Printf("⚠️  Warning: Generated files cleanup failed: %v\n", err)
		results["generated_files"] = false
	} else {
		fmt.Println("✅ Generated files cleaned up")
		results["generated_files"] = true
	}

	// 5. Optional: Remove backups
	if cleanupBackups {
		fmt.Println("🗂️  Cleaning up backup directories...")
		if err := cleanupBackupDirectories(); err != nil {
			fmt.Printf("⚠️  Warning: Backup cleanup failed: %v\n", err)
			results["backups"] = false
		} else {
			fmt.Println("✅ Backup directories cleaned up")
			results["backups"] = true
		}
	}

	// 6. Optional: Remove logs
	if cleanupLogs {
		fmt.Println("📋 Cleaning up log files...")
		if err := cleanupLogFiles(); err != nil {
			fmt.Printf("⚠️  Warning: Log cleanup failed: %v\n", err)
			results["logs"] = false
		} else {
			fmt.Println("✅ Log files cleaned up")
			results["logs"] = true
		}
	}

	// Display cleanup summary
	fmt.Println()
	fmt.Println("📊 Cleanup Summary:")
	fmt.Println("=" + string(make([]byte, 50)))

	successCount := 0
	totalCount := len(results)

	for item, success := range results {
		icon := "✅"
		status := "Success"
		if !success {
			icon = "❌"
			status = "Failed"
		} else {
			successCount++
		}
		fmt.Printf("   %s %s: %s\n", icon, item, status)
	}

	fmt.Println()
	if successCount == totalCount {
		fmt.Println("🎉 Cleanup completed successfully!")
		fmt.Println("💡 To redeploy ShuDL, run: ./bin/shudl")
	} else {
		fmt.Printf("⚠️  Cleanup completed with %d/%d successful operations\n", successCount, totalCount)
		fmt.Println("💡 Some cleanup operations failed. Check the warnings above.")
	}

	return nil
}

func cleanupDockerContainers() error {
	// First, get all running container IDs
	listCmd := exec.Command("docker", "ps", "-q")
	output, err := listCmd.Output()
	if err != nil {
		return fmt.Errorf("failed to list containers: %w", err)
	}

	containerIDs := strings.Fields(string(output))
	if len(containerIDs) == 0 {
		return nil // No containers to clean up
	}

	// Stop all running containers
	stopArgs := append([]string{"stop"}, containerIDs...)
	stopCmd := exec.Command("docker", stopArgs...)
	if err := stopCmd.Run(); err != nil {
		return fmt.Errorf("failed to stop containers: %w", err)
	}

	// Get all container IDs (including stopped ones)
	listAllCmd := exec.Command("docker", "ps", "-aq")
	output, err = listAllCmd.Output()
	if err != nil {
		return fmt.Errorf("failed to list all containers: %w", err)
	}

	allContainerIDs := strings.Fields(string(output))
	if len(allContainerIDs) == 0 {
		return nil // No containers to remove
	}

	// Remove all containers
	removeArgs := append([]string{"rm"}, allContainerIDs...)
	removeCmd := exec.Command("docker", removeArgs...)
	return removeCmd.Run()
}

func cleanupDockerVolumes() error {
	// Remove volumes
	volumeCmd := exec.Command("docker", "volume", "prune", "-f")
	return volumeCmd.Run()
}

func cleanupDockerNetworks() error {
	// Remove networks
	networkCmd := exec.Command("docker", "network", "prune", "-f")
	return networkCmd.Run()
}

func cleanupGeneratedFiles() error {
	filesToRemove := []string{
		"generated/.env",
		"generated/docker-compose.yml",
	}

	for _, file := range filesToRemove {
		if err := os.Remove(file); err != nil && !os.IsNotExist(err) {
			return fmt.Errorf("failed to remove %s: %w", file, err)
		}
	}

	return nil
}

func cleanupBackupDirectories() error {
	// Find and remove backup directories
	entries, err := os.ReadDir(".")
	if err != nil {
		return err
	}

	for _, entry := range entries {
		if entry.IsDir() && len(entry.Name()) > 7 && entry.Name()[:7] == "backup_" {
			if err := os.RemoveAll(entry.Name()); err != nil {
				return fmt.Errorf("failed to remove backup directory %s: %w", entry.Name(), err)
			}
		}
	}

	return nil
}

func cleanupLogFiles() error {
	logPatterns := []string{
		"*.log",
		"installer*.log",
		"test_*.log",
		"deployment_*.log",
	}

	for _, pattern := range logPatterns {
		matches, err := filepath.Glob(pattern)
		if err != nil {
			continue
		}

		for _, match := range matches {
			if err := os.Remove(match); err != nil {
				return fmt.Errorf("failed to remove log file %s: %w", match, err)
			}
		}
	}

	return nil
} 