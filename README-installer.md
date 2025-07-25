# Shudl Docker Installer

A Go-based Docker installer API that provides endpoints to manage Docker services through a web interface. This application allows users to start, stop, restart, and cleanup Docker services with a simple REST API and web interface.

## Features

- ✅ **RESTful API** - Clean REST endpoints for all Docker operations
- ✅ **Dynamic Compose Generation** - Generate docker-compose.yml files based on user preferences
- ✅ **Service Selection** - Choose which services to deploy (MinIO, PostgreSQL, Nessie, Trino, Spark)
- ✅ **Preset Configurations** - Development, Production, and Minimal templates
- ✅ **Configuration Validation** - Automatic dependency resolution and validation
- ✅ **Environment Management** - Auto-generated .env files with proper configurations
- ✅ **Swagger Documentation** - Auto-generated API documentation
- ✅ **Structured Logging** - JSON and console logging with zerolog
- ✅ **Configuration Management** - YAML, environment variables, and defaults
- ✅ **Docker Compose Support** - Full docker-compose integration
- ✅ **Graceful Shutdown** - Proper server shutdown handling
- ✅ **CORS Support** - Cross-origin resource sharing
- ✅ **Health Checks** - Health and validation endpoints
- ✅ **Request Tracing** - Request ID tracking for debugging

## Prerequisites

- Go 1.24+ 
- Docker and Docker Compose installed
- Access to Docker daemon (usually requires user to be in docker group)

## Quick Start

### 1. Clone and Setup

```bash
# Navigate to the project directory
cd /path/to/shudl

# Switch to the feature branch
git checkout feature/docker-installer

# Build the application
go build -o bin/installer cmd/installer/main.go
```

### 2. Configuration

Create a configuration file or use environment variables:

```bash
# Copy example config
cp configs/config.yaml configs/local.yaml

# Or use environment variables
cp configs/environment.example .env
source .env
```

### 3. Run the Application

```bash
# Run directly
./bin/installer

# Or with go run
go run cmd/installer/main.go
```

The server will start on `http://localhost:8080` by default.

## API Documentation

Once the server is running, visit:
- **Swagger UI**: http://localhost:8080/swagger/index.html
- **Health Check**: http://localhost:8080/health

### Available Endpoints

#### System Endpoints
- `GET /health` - Health check
- `GET /api/v1/system/validate` - Validate Docker installation

#### Docker Management
- `POST /api/v1/docker/start` - Start Docker services
- `POST /api/v1/docker/stop` - Stop Docker services  
- `POST /api/v1/docker/restart` - Restart Docker services
- `POST /api/v1/docker/cleanup` - Cleanup Docker resources
- `GET /api/v1/docker/status` - Get services status

#### Compose Generation
- `GET /api/v1/compose/services` - List available services
- `GET /api/v1/compose/defaults` - Get preset configurations
- `POST /api/v1/compose/generate` - Generate docker-compose files
- `POST /api/v1/compose/validate` - Validate configuration
- `POST /api/v1/compose/preview` - Preview generated files

### Example API Calls

#### Generate Compose Files
```bash
curl -X POST http://localhost:8080/api/v1/compose/generate \
  -H "Content-Type: application/json" \
  -d '{
    "project_name": "my-lakehouse",
    "environment": "development",
    "services": {
      "minio": {"name": "minio", "enabled": true},
      "postgresql": {"name": "postgresql", "enabled": true},
      "nessie": {"name": "nessie", "enabled": true},
      "trino": {"name": "trino", "enabled": true}
    }
  }'
```

#### Get Available Services
```bash
curl http://localhost:8080/api/v1/compose/services
```

#### Get Preset Configurations
```bash
curl http://localhost:8080/api/v1/compose/defaults
```

#### Start Services
```bash
curl -X POST http://localhost:8080/api/v1/docker/start \
  -H "Content-Type: application/json" \
  -d '{
    "compose_file": "docker-compose.yml",
    "project_name": "myproject",
    "services": ["web", "db"],
    "environment": {
      "ENV": "development"
    }
  }'
```

#### Get Status
```bash
curl http://localhost:8080/api/v1/docker/status?project_name=myproject
```

#### Cleanup
```bash
curl -X POST http://localhost:8080/api/v1/docker/cleanup \
  -H "Content-Type: application/json" \
  -d '{
    "project_name": "myproject"
  }'
```

## Configuration

The application supports multiple configuration methods (in order of precedence):

1. **Command line flags** (future enhancement)
2. **Environment variables** (prefixed with `SHUDL_`)
3. **Configuration files** (YAML)
4. **Default values**

### Configuration File Example

```yaml
server:
  host: "0.0.0.0"
  port: 8080
  read_timeout: 30
  write_timeout: 30
  environment: "development"

logger:
  level: "info"
  environment: "development"
  time_format: "15:04:05"

docker:
  compose_file: "docker-compose.yml"
  project_name: "shudl"
  timeout: 300
  environment:
    DOCKER_HOST: "unix:///var/run/docker.sock"
```

### Environment Variables

```bash
# Server
SHUDL_SERVER_HOST=0.0.0.0
SHUDL_SERVER_PORT=8080
SHUDL_SERVER_ENVIRONMENT=production

# Logger
SHUDL_LOGGER_LEVEL=info
SHUDL_LOGGER_ENVIRONMENT=production

# Docker
SHUDL_DOCKER_COMPOSE_FILE=docker-compose.prod.yml
SHUDL_DOCKER_PROJECT_NAME=shudl-prod
SHUDL_DOCKER_TIMEOUT=600
```

## Development

### Project Structure

```
.
├── cmd/installer/          # Main application entry point
├── internal/               # Private application code
│   ├── api/               # HTTP handlers and routing
│   ├── config/            # Configuration management
│   ├── docker/            # Docker service implementation
│   └── logger/            # Logging utilities
├── api/swagger/           # Generated Swagger documentation
├── configs/              # Configuration files
└── go.mod               # Go module definition
```

### Building

```bash
# Build for current platform
go build -o bin/installer cmd/installer/main.go

# Build for Linux
GOOS=linux GOARCH=amd64 go build -o bin/installer-linux cmd/installer/main.go

# Build for Windows
GOOS=windows GOARCH=amd64 go build -o bin/installer.exe cmd/installer/main.go
```

### Testing

```bash
# Run tests
go test ./...

# Run tests with coverage
go test -cover ./...

# Run tests with race detection
go test -race ./...
```

### Regenerate Swagger Docs

```bash
# Install swag if not already installed
go install github.com/swaggo/swag/cmd/swag@latest

# Generate documentation
swag init -g cmd/installer/main.go -o api/swagger
```

## Deployment

### Docker Deployment

```dockerfile
FROM golang:1.24-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o installer cmd/installer/main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates docker-cli docker-compose
WORKDIR /root/
COPY --from=builder /app/installer .
COPY --from=builder /app/configs ./configs
CMD ["./installer"]
```

### Systemd Service

```ini
[Unit]
Description=Shudl Docker Installer
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=shudl
WorkingDirectory=/opt/shudl
ExecStart=/opt/shudl/installer
Restart=always
RestartSec=5
Environment=SHUDL_SERVER_ENVIRONMENT=production

[Install]
WantedBy=multi-user.target
```

## Security Considerations

- **Docker Access**: The application needs access to the Docker daemon
- **File Permissions**: Ensure proper permissions for compose files
- **Network Security**: Consider firewall rules for the API port
- **Authentication**: Consider adding authentication for production use
- **CORS**: Configure appropriate CORS origins for production

## Troubleshooting

### Common Issues

1. **Docker not accessible**
   ```bash
   # Add user to docker group
   sudo usermod -aG docker $USER
   # Re-login or run
   newgrp docker
   ```

2. **Port already in use**
   ```bash
   # Change port in config or environment
   SHUDL_SERVER_PORT=8081 ./installer
   ```

3. **Compose file not found**
   ```bash
   # Specify full path in config
   SHUDL_DOCKER_COMPOSE_FILE=/full/path/to/docker-compose.yml ./installer
   ```

### Logs

The application uses structured logging. In development mode, logs are pretty-printed to console. In production mode, logs are output as JSON for log aggregation systems.

```bash
# Set log level
SHUDL_LOGGER_LEVEL=debug ./installer

# Production logging
SHUDL_LOGGER_ENVIRONMENT=production ./installer
```

## Roadmap

- [ ] Web frontend interface
- [ ] Authentication and authorization
- [ ] Service discovery and management
- [ ] Container logs streaming
- [ ] Resource monitoring
- [ ] Multi-compose file support
- [ ] Environment management UI

## Contributing

1. Create a feature branch
2. Make your changes
3. Add tests
4. Update documentation
5. Submit a pull request

## License

MIT License - see LICENSE file for details. 