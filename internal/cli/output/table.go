package output

import (
	"fmt"

	"github.com/fatih/color"
)

// PrintTable prints a formatted table to stdout
func PrintTable(headers []string, rows [][]string) {
	// Print headers
	color.New(color.Bold, color.FgCyan).Print("┌")
	for i, header := range headers {
		if i > 0 {
			color.New(color.Bold, color.FgCyan).Print("┬")
		}
		color.New(color.Bold, color.FgCyan).Printf("%-20s", header)
	}
	color.New(color.Bold, color.FgCyan).Println("┐")

	// Print rows
	for _, row := range rows {
		fmt.Print("│")
		for i, cell := range row {
			if i > 0 {
				fmt.Print("│")
			}
			fmt.Printf("%-20s", cell)
		}
		fmt.Println("│")
	}

	// Print bottom border
	color.New(color.Bold, color.FgCyan).Print("└")
	for i := range headers {
		if i > 0 {
			color.New(color.Bold, color.FgCyan).Print("┴")
		}
		color.New(color.Bold, color.FgCyan).Print("────────────────────")
	}
	color.New(color.Bold, color.FgCyan).Println("┘")
}

// PrintStatus prints colored status information
func PrintStatus(service, status, health string) {
	var statusColor, healthColor *color.Color

	// Status colors
	switch status {
	case "running":
		statusColor = color.New(color.FgGreen)
	case "stopped", "exited":
		statusColor = color.New(color.FgRed)
	case "starting":
		statusColor = color.New(color.FgYellow)
	default:
		statusColor = color.New(color.FgWhite)
	}

	// Health colors
	switch health {
	case "healthy":
		healthColor = color.New(color.FgGreen)
	case "unhealthy":
		healthColor = color.New(color.FgRed)
	case "starting":
		healthColor = color.New(color.FgYellow)
	default:
		healthColor = color.New(color.FgWhite)
	}

	fmt.Printf("%-20s %s\t%s\n",
		service,
		statusColor.Sprintf("%-10s", status),
		healthColor.Sprintf("%-10s", health),
	)
}

// PrintSuccess prints a success message
func PrintSuccess(message string) {
	color.Green("✅ %s", message)
}

// PrintError prints an error message
func PrintError(message string) {
	color.Red("❌ %s", message)
}

// PrintWarning prints a warning message
func PrintWarning(message string) {
	color.Yellow("⚠️  %s", message)
}

// PrintInfo prints an info message
func PrintInfo(message string) {
	color.Cyan("ℹ️  %s", message)
}

// PrintHeader prints a formatted header
func PrintHeader(title string) {
	color.New(color.Bold, color.FgCyan).Printf("\n🚀 %s\n", title)
	color.New(color.FgCyan).Println("=" + fmt.Sprintf("%*s", len(title)+2, ""))
}
