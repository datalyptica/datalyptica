package main

import (
	"fmt"
	"os"

	"github.com/shudl/shudl/cmd/shudlctl/commands"
)

// Version information
var (
	Version   = "1.0.0"
	GitCommit = "dev"
	BuildDate = "unknown"
)

func main() {
	// Set version information for the CLI
	commands.SetVersion(Version, GitCommit, BuildDate)

	// Execute the root command
	if err := commands.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
