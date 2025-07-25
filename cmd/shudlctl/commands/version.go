package commands

import (
	"fmt"

	"github.com/fatih/color"
	"github.com/spf13/cobra"
)

// versionCmd represents the version command
var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Show version information",
	Long: `Display version, git commit, and build information for shudlctl.

This command shows detailed version information including:
• Version number
• Git commit hash  
• Build date
• Go version used for compilation`,
	Run: func(cmd *cobra.Command, args []string) {
		showVersion()
	},
}

func showVersion() {
	color.New(color.Bold, color.FgCyan).Println("🚀 ShuDL CLI (shudlctl)")
	color.New(color.Bold, color.FgCyan).Println("=" + fmt.Sprintf("%*s", 22, ""))

	fmt.Printf("Version:    %s\n", color.GreenString(version))
	fmt.Printf("Git Commit: %s\n", color.YellowString(gitCommit))
	fmt.Printf("Build Date: %s\n", color.BlueString(buildDate))
	fmt.Printf("Go Version: %s\n", color.MagentaString("go1.21+"))

	fmt.Println()
	color.New(color.FgCyan).Println("🌟 ShuDL - Shugur Data Lakehouse Platform")
	color.New(color.FgCyan).Println("Built with ❤️  for modern data teams")
}

func init() {
	rootCmd.AddCommand(versionCmd)
}
