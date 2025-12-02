# Datalyptica Data Platform - Control Plane Makefile
# ====================================================
# Single entry point for all operations

# Variables
COMPOSE_FILE := ./deploy/compose/docker-compose.yml
ENV_FILE := ./deploy/compose/.env
COMPOSE := docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE)

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

.PHONY: help
help: ## Show this help message
	@echo "$(GREEN)Datalyptica Data Platform - Control Plane$(NC)"
	@echo "==============================================="
	@echo ""
	@echo "$(YELLOW)Usage:$(NC) make [target]"
	@echo ""
	@echo "$(YELLOW)Core Commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Parameterized Commands:$(NC)"
	@echo "  $(GREEN)make logs s=<service>$(NC)    Tail logs for specific service"
	@echo "  $(GREEN)make shell s=<service>$(NC)   Open shell in specific service"
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make logs s=kafka"
	@echo "  make shell s=trino"
	@echo "  make restart s=spark-master"

.PHONY: check-env
check-env:
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "$(RED)ERROR: Environment file not found at $(ENV_FILE)$(NC)"; \
		echo "$(YELLOW)Please create it from .env.example$(NC)"; \
		exit 1; \
	fi

# ==========================================
# Core Stack Operations
# ==========================================

.PHONY: up
up: check-env ## Start the full Datalyptica stack
	@echo "$(GREEN)Starting Datalyptica Data Platform...$(NC)"
	$(COMPOSE) up -d
	@echo "$(GREEN)Stack started successfully!$(NC)"
	@echo "Run 'make ps' to see service status"

.PHONY: down
down: check-env ## Stop all services
	@echo "$(YELLOW)Stopping Datalyptica Data Platform...$(NC)"
	$(COMPOSE) down
	@echo "$(GREEN)Stack stopped successfully!$(NC)"

.PHONY: restart
restart: check-env ## Restart all services (or specific service with s=<service>)
ifdef s
	@echo "$(YELLOW)Restarting service: $(s)...$(NC)"
	$(COMPOSE) restart $(s)
	@echo "$(GREEN)Service $(s) restarted!$(NC)"
else
	@echo "$(YELLOW)Restarting all services...$(NC)"
	$(COMPOSE) restart
	@echo "$(GREEN)All services restarted!$(NC)"
endif

.PHONY: ps
ps: check-env ## Show status of all services
	$(COMPOSE) ps

.PHONY: logs
logs: check-env ## Tail logs for all services (or specific service with s=<service>)
ifdef s
	@echo "$(GREEN)Tailing logs for: $(s)$(NC)"
	$(COMPOSE) logs -f $(s)
else
	@echo "$(GREEN)Tailing logs for all services$(NC)"
	$(COMPOSE) logs -f
endif

.PHONY: stop
stop: check-env ## Stop services without removing containers
	@echo "$(YELLOW)Stopping services...$(NC)"
	$(COMPOSE) stop
	@echo "$(GREEN)Services stopped!$(NC)"

.PHONY: start
start: check-env ## Start stopped services
	@echo "$(GREEN)Starting services...$(NC)"
	$(COMPOSE) start
	@echo "$(GREEN)Services started!$(NC)"

# ==========================================
# Data Management
# ==========================================

.PHONY: clean
clean: check-env ## Stop services and remove containers
	@echo "$(YELLOW)Cleaning up containers...$(NC)"
	$(COMPOSE) down --remove-orphans
	@echo "$(GREEN)Cleanup complete!$(NC)"

.PHONY: nuke
nuke: ## DANGEROUS: Stop services, remove containers AND delete all volumes
	@echo "$(RED)WARNING: This will DELETE ALL DATA in the Data Platform!$(NC)"
	@echo "$(RED)Press Ctrl+C within 5 seconds to cancel...$(NC)"
	@sleep 5
	@echo "$(RED)Nuking the Data Platform...$(NC)"
	$(COMPOSE) down -v --remove-orphans
	@echo "$(GREEN)Data Platform reset complete!$(NC)"

.PHONY: prune
prune: ## Remove unused Docker resources
	@echo "$(YELLOW)Pruning Docker system...$(NC)"
	docker system prune -f
	@echo "$(GREEN)Prune complete!$(NC)"

# ==========================================
# Shell Access
# ==========================================

.PHONY: shell
shell: check-env ## Open shell in a service (requires s=<service>)
ifndef s
	@echo "$(RED)ERROR: Service name required$(NC)"
	@echo "$(YELLOW)Usage: make shell s=<service>$(NC)"
	@echo "$(YELLOW)Example: make shell s=trino$(NC)"
	@exit 1
endif
	@echo "$(GREEN)Opening shell in: $(s)$(NC)"
	$(COMPOSE) exec $(s) /bin/bash || $(COMPOSE) exec $(s) /bin/sh

# ==========================================
# Service-Specific Helpers
# ==========================================

.PHONY: trino-cli
trino-cli: check-env ## Launch Trino CLI
	@echo "$(GREEN)Launching Trino CLI...$(NC)"
	$(COMPOSE) exec trino trino --server localhost:8080

.PHONY: spark-sql
spark-sql: check-env ## Launch Spark SQL shell
	@echo "$(GREEN)Launching Spark SQL...$(NC)"
	$(COMPOSE) exec spark-master spark-sql

.PHONY: spark-shell
spark-shell: check-env ## Launch Spark Scala shell
	@echo "$(GREEN)Launching Spark Shell...$(NC)"
	$(COMPOSE) exec spark-master spark-shell

.PHONY: flink-sql
flink-sql: check-env ## Launch Flink SQL client
	@echo "$(GREEN)Launching Flink SQL...$(NC)"
	$(COMPOSE) exec flink-jobmanager sql-client.sh

.PHONY: kafka-topics
kafka-topics: check-env ## List Kafka topics
	@echo "$(GREEN)Listing Kafka topics...$(NC)"
	$(COMPOSE) exec kafka kafka-topics.sh --bootstrap-server localhost:9092 --list

.PHONY: psql
psql: check-env ## Connect to PostgreSQL
	@echo "$(GREEN)Connecting to PostgreSQL...$(NC)"
	$(COMPOSE) exec postgresql psql -U postgres

.PHONY: clickhouse-client
clickhouse-client: check-env ## Launch ClickHouse client
	@echo "$(GREEN)Launching ClickHouse client...$(NC)"
	$(COMPOSE) exec clickhouse clickhouse-client

# ==========================================
# Monitoring & Health
# ==========================================

.PHONY: health
health: check-env ## Check health status of all services
	@echo "$(GREEN)Checking service health...$(NC)"
	$(COMPOSE) ps --format "table {{.Service}}\t{{.Status}}\t{{.Health}}"

.PHONY: stats
stats: ## Show Docker resource usage
	@echo "$(GREEN)Docker resource usage:$(NC)"
	docker stats --no-stream

.PHONY: top
top: check-env ## Show running processes in containers
ifdef s
	$(COMPOSE) top $(s)
else
	$(COMPOSE) top
endif

# ==========================================
# Build & Update
# ==========================================

.PHONY: pull
pull: check-env ## Pull latest images
	@echo "$(GREEN)Pulling latest images...$(NC)"
	$(COMPOSE) pull

.PHONY: build
build: check-env ## Rebuild images
	@echo "$(GREEN)Building images...$(NC)"
	$(COMPOSE) build

.PHONY: rebuild
rebuild: check-env ## Rebuild images without cache
	@echo "$(GREEN)Rebuilding images without cache...$(NC)"
	$(COMPOSE) build --no-cache

# ==========================================
# Configuration
# ==========================================

.PHONY: config
config: check-env ## Validate and view docker-compose configuration
	@echo "$(GREEN)Docker Compose configuration:$(NC)"
	$(COMPOSE) config

.PHONY: env
env: ## Show environment file path
	@echo "$(GREEN)Environment file:$(NC) $(ENV_FILE)"
	@if [ -f $(ENV_FILE) ]; then \
		echo "$(GREEN)✓ File exists$(NC)"; \
	else \
		echo "$(RED)✗ File not found$(NC)"; \
	fi

# ==========================================
# Quick Access URLs
# ==========================================

.PHONY: urls
urls: ## Display service URLs
	@echo "$(GREEN)Datalyptica Data Platform - Service URLs:$(NC)"
	@echo "════════════════════════════════════════"
	@echo "$(YELLOW)Query Engines:$(NC)"
	@echo "  Trino UI:        http://localhost:8080"
	@echo "  Spark UI:        http://localhost:4040"
	@echo "  Flink UI:        http://localhost:8081"
	@echo "  ClickHouse:      http://localhost:8123"
	@echo ""
	@echo "$(YELLOW)Storage & Catalog:$(NC)"
	@echo "  MinIO Console:   http://localhost:9001"
	@echo "  Nessie API:      http://localhost:19120"
	@echo ""
	@echo "$(YELLOW)Streaming:$(NC)"
	@echo "  Kafka UI:        http://localhost:8090"
	@echo "  Schema Registry: http://localhost:8085"
	@echo ""
	@echo "$(YELLOW)Orchestration & ML:$(NC)"
	@echo "  Airflow:         http://localhost:8082"
	@echo "  JupyterHub:      http://localhost:8000"
	@echo "  MLflow:          http://localhost:5000"
	@echo "  Superset:        http://localhost:8088"
	@echo ""
	@echo "$(YELLOW)Monitoring:$(NC)"
	@echo "  Grafana:         http://localhost:3000"
	@echo "  Prometheus:      http://localhost:9090"
	@echo ""
	@echo "$(YELLOW)Identity:$(NC)"
	@echo "  Keycloak:        http://localhost:8180"

# Default target
.DEFAULT_GOAL := help
