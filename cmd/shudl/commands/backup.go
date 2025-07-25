package commands

import (
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/spf13/cobra"
)

var backupCmd = &cobra.Command{
	Use:   "backup",
	Short: "Backup ShuDL configuration",
	Long: `Backup ShuDL platform configuration and settings.
	
This command creates a backup of:
- Generated configuration files (.env, docker-compose.yml)
- Platform settings and configurations
- Service configurations`,
	RunE: runBackup,
}

func init() {
	rootCmd.AddCommand(backupCmd)
}

func runBackup(cmd *cobra.Command, args []string) error {
	fmt.Println("💾 Creating ShuDL Configuration Backup...")
	fmt.Println()

	// Create backup directory
	backupDir := fmt.Sprintf("backup_%s", time.Now().Format("20060102_150405"))
	if err := os.MkdirAll(backupDir, 0755); err != nil {
		return fmt.Errorf("failed to create backup directory: %w", err)
	}

	// Files to backup
	filesToBackup := []string{
		"generated/.env",
		"generated/docker-compose.yml",
		"configs/",
	}

	backedUpFiles := []string{}

	for _, file := range filesToBackup {
		if err := backupFile(file, backupDir); err != nil {
			fmt.Printf("⚠️  Warning: Failed to backup %s: %v\n", file, err)
		} else {
			backedUpFiles = append(backedUpFiles, file)
			fmt.Printf("✅ Backed up: %s\n", file)
		}
	}

	// Create backup manifest
	manifest := createBackupManifest(backupDir, backedUpFiles)
	if err := writeBackupManifest(backupDir, manifest); err != nil {
		fmt.Printf("⚠️  Warning: Failed to write backup manifest: %v\n", err)
	}

	fmt.Println()
	fmt.Printf("📦 Backup completed: %s\n", backupDir)
	fmt.Printf("📄 Files backed up: %d\n", len(backedUpFiles))
	fmt.Println()
	fmt.Println("💡 To restore from backup:")
	fmt.Printf("   cp -r %s/* generated/\n", backupDir)

	return nil
}

func backupFile(source, backupDir string) error {
	// Check if source exists
	if _, err := os.Stat(source); os.IsNotExist(err) {
		return fmt.Errorf("source file does not exist: %s", source)
	}

	// Create destination path
	dest := filepath.Join(backupDir, filepath.Base(source))

	// Copy file or directory
	if err := copyFileOrDir(source, dest); err != nil {
		return fmt.Errorf("failed to copy %s: %w", source, err)
	}

	return nil
}

func copyFileOrDir(src, dst string) error {
	// For now, implement a simple file copy
	// In a real implementation, you'd want to handle directories recursively
	input, err := os.ReadFile(src)
	if err != nil {
		return err
	}

	return os.WriteFile(dst, input, 0644)
}

type BackupManifest struct {
	Timestamp   time.Time `json:"timestamp"`
	Version     string    `json:"version"`
	Files       []string  `json:"files"`
	Description string    `json:"description"`
}

func createBackupManifest(backupDir string, files []string) BackupManifest {
	return BackupManifest{
		Timestamp:   time.Now(),
		Version:     "1.0.0",
		Files:       files,
		Description: "ShuDL Platform Configuration Backup",
	}
}

func writeBackupManifest(backupDir string, manifest BackupManifest) error {
	manifestFile := filepath.Join(backupDir, "backup-manifest.json")

	// Simple JSON writing (in real implementation, use proper JSON marshaling)
	content := fmt.Sprintf(`{
  "timestamp": "%s",
  "version": "%s",
  "files": %v,
  "description": "%s"
}`, manifest.Timestamp.Format(time.RFC3339), manifest.Version, manifest.Files, manifest.Description)

	return os.WriteFile(manifestFile, []byte(content), 0644)
} 