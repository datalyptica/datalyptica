package commands

import (
	"fmt"
	"os"

	"github.com/fatih/color"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var (
	cfgFile   string
	serverURL string
	version   string
	gitCommit string
	buildDate string
	verbose   bool
)

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "shudlctl",
	Short: "ShuDL Data Lakehouse Platform CLI",
	Long: color.New(color.FgCyan).Sprint(`
🚀 ShuDL CLI - Data Lakehouse Platform Management Tool

shudlctl is the command-line interface for managing ShuDL Data Lakehouse deployments.
It provides a simple way to deploy, manage, and monitor your data platform services.

Inspired by modern platform tools like stackablectl, shudlctl offers:
• Easy deployment and configuration
• Service lifecycle management  
• Real-time status monitoring
• Configuration validation

Examples:
  shudlctl deploy --config production.yaml
  shudlctl status --services all
  shudlctl logs --service nessie --follow
`),
	PersistentPreRun: func(cmd *cobra.Command, args []string) {
		if verbose {
			fmt.Printf("🔧 Server URL: %s\n", serverURL)
			fmt.Printf("🔧 Config file: %s\n", cfgFile)
		}
	},
}

// Execute adds all child commands to the root command and sets flags appropriately.
func Execute() error {
	return rootCmd.Execute()
}

// SetVersion sets the version information for the CLI
func SetVersion(v, commit, date string) {
	version = v
	gitCommit = commit
	buildDate = date
}

func init() {
	cobra.OnInitialize(initConfig)

	// Global flags
	rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.shudlctl.yaml)")
	rootCmd.PersistentFlags().StringVar(&serverURL, "server", "http://localhost:8080", "ShuDL server URL")
	rootCmd.PersistentFlags().BoolVarP(&verbose, "verbose", "v", false, "verbose output")

	// Local flags
	rootCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}

// initConfig reads in config file and ENV variables if set.
func initConfig() {
	if cfgFile != "" {
		// Use config file from the flag.
		viper.SetConfigFile(cfgFile)
	} else {
		// Search config in home directory with name ".shudlctl" (without extension).
		viper.AddConfigPath("$HOME")
		viper.SetConfigName(".shudlctl")
	}

	viper.AutomaticEnv() // read in environment variables that match

	// If a config file is found, read it in.
	if err := viper.ReadInConfig(); err == nil {
		fmt.Fprintln(os.Stderr, "Using config file:", viper.ConfigFileUsed())
	}
} 