package client

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// Client represents the ShuDL API client
type Client struct {
	BaseURL    string
	HTTPClient *http.Client
	UserAgent  string
}

// NewClient creates a new ShuDL API client
func NewClient(baseURL string) *Client {
	return &Client{
		BaseURL: baseURL,
		HTTPClient: &http.Client{
			Timeout: 30 * time.Second,
		},
		UserAgent: "shudlctl/1.0.0",
	}
}

// doRequest performs an HTTP request
func (c *Client) doRequest(method, path string, body interface{}) (*http.Response, error) {
	var bodyReader io.Reader

	if body != nil {
		jsonBody, err := json.Marshal(body)
		if err != nil {
			return nil, fmt.Errorf("failed to marshal request body: %w", err)
		}
		bodyReader = bytes.NewReader(jsonBody)
	}

	req, err := http.NewRequest(method, c.BaseURL+path, bodyReader)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("User-Agent", c.UserAgent)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}

	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}

	return resp, nil
}

// Health checks if the ShuDL server is healthy
func (c *Client) Health() error {
	resp, err := c.doRequest("GET", "/health", nil)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("server unhealthy: status %d", resp.StatusCode)
	}

	return nil
}

// ServiceStatus represents the status of services
type ServiceStatus struct {
	Services []interface{} `json:"services"`
	Summary  string        `json:"summary"`
}

// GetStatus gets the status of all services
func (c *Client) GetStatus() (*ServiceStatus, error) {
	resp, err := c.doRequest("GET", "/api/v1/docker/status", nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to get status: status %d", resp.StatusCode)
	}

	var status ServiceStatus
	if err := json.NewDecoder(resp.Body).Decode(&status); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return &status, nil
}

// ValidateSystem validates the system requirements
func (c *Client) ValidateSystem() error {
	resp, err := c.doRequest("GET", "/api/v1/docker/validate", nil)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("system validation failed: status %d", resp.StatusCode)
	}

	return nil
}

// DeployRequest represents a deployment request
type DeployRequest struct {
	Services []string `json:"services"`
	Config   string   `json:"config,omitempty"`
}

// Deploy starts the deployment of services
func (c *Client) Deploy(services []string, config string) error {
	req := DeployRequest{
		Services: services,
		Config:   config,
	}

	resp, err := c.doRequest("POST", "/api/v1/docker/start", req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("deployment failed: status %d", resp.StatusCode)
	}

	return nil
}

// Stop stops the specified services
func (c *Client) Stop(services []string) error {
	req := map[string][]string{"services": services}

	resp, err := c.doRequest("POST", "/api/v1/docker/stop", req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("stop failed: status %d", resp.StatusCode)
	}

	return nil
}

// GetLogs retrieves logs for a specific service
func (c *Client) GetLogs(service string, lines int, follow bool) error {
	path := fmt.Sprintf("/api/v1/docker/logs?service=%s&lines=%d&follow=%t", service, lines, follow)

	resp, err := c.doRequest("GET", path, nil)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("failed to get logs: status %d", resp.StatusCode)
	}

	// Stream logs to stdout
	_, err = io.Copy(io.Writer(bytes.NewBuffer(nil)), resp.Body)
	return err
}
