package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

type Config struct {
	Driver      string
	ClusterMode string
	ImageRepo   string
	Namespace   string
	ReleaseName string
}

func main() {
	fmt.Println("🚀 Lakehouse Platform Installer")
	fmt.Println("================================")

	config := &Config{}

	// Step 1: Driver selection
	config.Driver = selectDriver()

	// Step 2: Cluster mode (for k8s and vm)
	if config.Driver == "k8s" || config.Driver == "vm" {
		config.ClusterMode = selectClusterMode()
	}

	// Step 3: Image repository
	config.ImageRepo = selectImageRepo()

	// Step 4: Namespace/Release name
	config.Namespace = selectNamespace()
	config.ReleaseName = config.Namespace

	// Show summary
	showSummary(config)

	// Confirm and proceed
	if !confirmProceed() {
		fmt.Println("Installation cancelled.")
		os.Exit(0)
	}

	// Execute installation
	if err := executeInstallation(config); err != nil {
		fmt.Printf("❌ Installation failed: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("✅ Installation completed successfully!")
}

func selectDriver() string {
	fmt.Println("\n1. Select deployment driver:")
	fmt.Println("   • docker - Stand-alone (Dev laptops)")
	fmt.Println("   • k8s    - Kubernetes (Any K8s / KinD)")
	fmt.Println("   • vm     - Bare-metal / VMs")

	for {
		fmt.Print("\nDriver? [docker/k8s/vm]: ")
		driver := readInput()
		
		switch driver {
		case "docker", "k8s", "vm":
			return driver
		default:
			fmt.Println("❌ Invalid driver. Please select docker, k8s, or vm.")
		}
	}
}

func selectClusterMode() string {
	fmt.Println("\n2. Select cluster mode:")
	fmt.Println("   • stand-alone      - Single node deployment")
	fmt.Println("   • high-availability - Multi-node HA deployment")

	for {
		fmt.Print("\nCluster mode? [stand-alone/high-availability]: ")
		mode := readInput()
		
		switch mode {
		case "stand-alone", "high-availability":
			return mode
		default:
			fmt.Println("❌ Invalid mode. Please select stand-alone or high-availability.")
		}
	}
}

func selectImageRepo() string {
	defaultRepo := "ghcr.io/Shugur-Network/shudl"
	fmt.Printf("\n3. Image repository (default: %s): ", defaultRepo)
	repo := readInput()
	
	if repo == "" {
		return defaultRepo
	}
	return repo
}

func selectNamespace() string {
	defaultNS := "lakehouse"
	fmt.Printf("\n4. Namespace / Release name (default: %s): ", defaultNS)
	ns := readInput()
	
	if ns == "" {
		return defaultNS
	}
	return ns
}

func showSummary(config *Config) {
	fmt.Println("\n📋 Installation Summary")
	fmt.Println("======================")
	fmt.Printf("Driver:        %s\n", config.Driver)
	if config.Driver == "k8s" || config.Driver == "vm" {
		fmt.Printf("Cluster Mode:  %s\n", config.ClusterMode)
	}
	fmt.Printf("Image Repo:    %s\n", config.ImageRepo)
	fmt.Printf("Namespace:     %s\n", config.Namespace)
	fmt.Printf("Release Name:  %s\n", config.ReleaseName)
}

func confirmProceed() bool {
	fmt.Print("\nProceed? (y/N): ")
	response := strings.ToLower(readInput())
	return response == "y" || response == "yes"
}

func executeInstallation(config *Config) error {
	fmt.Printf("\n🔧 Installing lakehouse platform...\n")

	switch config.Driver {
	case "docker":
		return executeDockerInstallation(config)
	case "k8s":
		return executeK8sInstallation(config)
	case "vm":
		return executeVMInstallation(config)
	default:
		return fmt.Errorf("unsupported driver: %s", config.Driver)
	}
}

func executeDockerInstallation(config *Config) error {
	fmt.Println("📦 Docker installation (stub)")
	fmt.Println("   → Would write docker-compose.yml")
	fmt.Println("   → Would run: docker compose up -d")
	return nil
}

func executeK8sInstallation(config *Config) error {
	fmt.Printf("☸️  Installing on Kubernetes (mode: %s)\n", config.ClusterMode)
	
	// Check if kubectl is available
	if err := exec.Command("kubectl", "version", "--client").Run(); err != nil {
		return fmt.Errorf("kubectl not found: %v", err)
	}

	// Check if helm is available
	if err := exec.Command("helm", "version").Run(); err != nil {
		return fmt.Errorf("helm not found: %v", err)
	}

	// Create namespace if it doesn't exist
	fmt.Printf("📁 Creating namespace: %s\n", config.Namespace)
	createNS := exec.Command("kubectl", "create", "namespace", config.Namespace)
	createNS.Run() // Ignore error if namespace already exists

	// Install helm chart
	fmt.Printf("📦 Installing helm chart: %s\n", config.ReleaseName)
	
	helmArgs := []string{
		"install",
		config.ReleaseName,
		"./charts/lakehouse",
		"--namespace", config.Namespace,
		"--set", fmt.Sprintf("global.imageRepo=%s", config.ImageRepo),
		"--set", fmt.Sprintf("global.clusterMode=%s", config.ClusterMode),
		"--wait",
		"--timeout", "10m",
	}

	helmCmd := exec.Command("helm", helmArgs...)
	helmCmd.Stdout = os.Stdout
	helmCmd.Stderr = os.Stderr

	if err := helmCmd.Run(); err != nil {
		return fmt.Errorf("helm install failed: %v", err)
	}

	// Wait for pods to be ready
	fmt.Println("⏳ Waiting for pods to be ready...")
	waitCmd := exec.Command("kubectl", "wait", "--for=condition=ready", 
		fmt.Sprintf("pod -l app.kubernetes.io/instance=%s", config.ReleaseName),
		"--namespace", config.Namespace,
		"--timeout=600s")
	waitCmd.Stdout = os.Stdout
	waitCmd.Stderr = os.Stderr

	if err := waitCmd.Run(); err != nil {
		return fmt.Errorf("waiting for pods failed: %v", err)
	}

	fmt.Println("✅ Kubernetes installation completed!")
	return nil
}

func executeVMInstallation(config *Config) error {
	fmt.Println("🖥️  VM installation (stub)")
	fmt.Println("   → Would call Ansible playbook")
	return nil
}

func readInput() string {
	scanner := bufio.NewScanner(os.Stdin)
	scanner.Scan()
	return strings.TrimSpace(scanner.Text())
}