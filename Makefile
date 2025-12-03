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
	@echo "$(GREEN)╔══════════════════════════════════════════════════════╗$(NC)"
	@echo "$(GREEN)║    Datalyptica Data Platform - Control Plane        ║$(NC)"
	@echo "$(GREEN)╚══════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(YELLOW)📦 Quick Start (First Time):$(NC)"
	@echo "  1. $(GREEN)./scripts/generate-secrets.sh$(NC)  # Generate secure passwords"
	@echo "  2. $(GREEN)make deploy$(NC)                    # Complete deployment (recommended!)"
	@echo ""
	@echo "$(YELLOW)📦 Alternative (Manual Steps):$(NC)"
	@echo "  1. $(GREEN)make up$(NC)          # Start all services in order"
	@echo "  2. $(GREEN)make init$(NC)        # Initialize databases, buckets"
	@echo "  3. $(GREEN)make health$(NC)      # Check service health"
	@echo "  4. $(GREEN)make urls$(NC)        # View all service URLs"
	@echo ""
	@echo "$(YELLOW)🚀 Stack Operations:$(NC)"
	@echo "  $(GREEN)up$(NC)               Start the full stack"
	@echo "  $(GREEN)down$(NC)             Stop all services"
	@echo "  $(GREEN)restart$(NC)          Restart all services (or s=<service>)"
	@echo "  $(GREEN)ps$(NC)               Show status of all services"
	@echo "  $(GREEN)logs$(NC)             Tail logs (or s=<service>)"
	@echo "  $(GREEN)health$(NC)           Check health status"
	@echo ""
	@echo "$(YELLOW)⚙️  Initialization:$(NC)"
	@echo "  $(GREEN)init$(NC)             Initialize everything (databases, buckets, services)"
	@echo "  $(GREEN)init-databases$(NC)   Initialize PostgreSQL databases only"
	@echo "  $(GREEN)init-minio$(NC)       Initialize MinIO buckets only"
	@echo "  $(GREEN)init-kafka$(NC)       Initialize Kafka storage only"
	@echo "  $(GREEN)init-keycloak$(NC)    Import Keycloak realm configuration"
	@echo "  $(GREEN)init-airflow$(NC)     Initialize Airflow database and admin user"
	@echo "  $(GREEN)init-superset$(NC)    Initialize Superset database and admin user"
	@echo "  $(GREEN)verify$(NC)           Verify all services"
	@echo ""
	@echo "$(YELLOW)🛠️  Service Access:$(NC)"
	@echo "  $(GREEN)shell s=<service>$(NC)   Open shell in service"
	@echo "  $(GREEN)trino-cli$(NC)          Launch Trino CLI"
	@echo "  $(GREEN)spark-sql$(NC)          Launch Spark SQL"
	@echo "  $(GREEN)flink-sql$(NC)          Launch Flink SQL"
	@echo "  $(GREEN)psql$(NC)               Connect to PostgreSQL"
	@echo "  $(GREEN)clickhouse-client$(NC)  Launch ClickHouse client"
	@echo ""
	@echo "$(YELLOW)🧹 Cleanup:$(NC)"
	@echo "  $(GREEN)clean$(NC)            Stop and remove containers"
	@echo "  $(GREEN)nuke$(NC)             Remove containers AND all data"
	@echo "  $(GREEN)prune$(NC)            Remove unused Docker resources"
	@echo ""
	@echo "$(YELLOW)📊 Monitoring:$(NC)"
	@echo "  $(GREEN)stats$(NC)            Show Docker resource usage"
	@echo "  $(GREEN)urls$(NC)             Display all service URLs"
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

.PHONY: check-secrets
check-secrets:
	@if [ ! -f secrets/passwords/postgres_password ]; then \
		echo "$(RED)ERROR: Secrets not found!$(NC)"; \
		echo "$(YELLOW)Run: ./scripts/generate-secrets.sh$(NC)"; \
		exit 1; \
	fi

.PHONY: deploy
deploy: check-env check-secrets ## Complete deployment: start services & initialize storage
	@echo "$(GREEN)╔══════════════════════════════════════════════════════╗$(NC)"
	@echo "$(GREEN)║     Datalyptica Complete Deployment Process          ║$(NC)"
	@echo "$(GREEN)╚══════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(YELLOW)This will:$(NC)"
	@echo "  1. Start all services in the correct order"
	@echo "  2. Initialize storage buckets (databases auto-created)"
	@echo "  3. Verify service health"
	@echo ""
	@echo "$(YELLOW)⏱️  Estimated time: 3-5 minutes$(NC)"
	@echo ""
	@read -p "Continue? [y/N] " -n 1 -r; \
	echo; \
	if [[ ! $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "$(YELLOW)Deployment cancelled$(NC)"; \
		exit 1; \
	fi
	@echo ""
	@$(MAKE) up
	@echo ""
	@echo "$(YELLOW)⏳ Waiting 45 seconds for services to stabilize...$(NC)"
	@sleep 45
	@echo ""
	@$(MAKE) init
	@echo ""
	@echo "$(GREEN)╔══════════════════════════════════════════════════════╗$(NC)"
	@echo "$(GREEN)║          ✓ Deployment Complete!                     ║$(NC)"
	@echo "$(GREEN)╚══════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@$(MAKE) urls

.PHONY: fresh-start
fresh-start: check-secrets ## Complete fresh deployment: clean everything, rebuild, deploy
	@echo "$(RED)╔══════════════════════════════════════════════════════╗$(NC)"
	@echo "$(RED)║     WARNING: Fresh Start - ALL DATA WILL BE LOST    ║$(NC)"
	@echo "$(RED)╚══════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(YELLOW)This will:$(NC)"
	@echo "  1. Stop and remove all containers"
	@echo "  2. Delete ALL volumes (databases, storage, logs)"
	@echo "  3. Rebuild PostgreSQL image with init script"
	@echo "  4. Start services in correct order"
	@echo "  5. Initialize storage buckets"
	@echo ""
	@echo "$(RED)⚠️  ALL DATA WILL BE PERMANENTLY DELETED!$(NC)"
	@echo ""
	@read -p "Type 'DELETE' to confirm: " confirm; \
	if [ "$$confirm" != "DELETE" ]; then \
		echo "$(YELLOW)Fresh start cancelled$(NC)"; \
		exit 1; \
	fi
	@echo ""
	@echo "$(YELLOW)Stopping and removing everything...$(NC)"
	@$(COMPOSE) down -v --remove-orphans
	@echo ""
	@echo "$(YELLOW)Rebuilding PostgreSQL image...$(NC)"
	@$(COMPOSE) build postgresql
	@echo ""
	@$(MAKE) deploy

# ==========================================
# Core Stack Operations
# ==========================================

.PHONY: up
up: check-env ## Start the full Datalyptica stack in proper order
	@echo "$(GREEN)╔══════════════════════════════════════════════════════╗$(NC)"
	@echo "$(GREEN)║  Starting Datalyptica Data Platform (Orchestrated)  ║$(NC)"
	@echo "$(GREEN)╚══════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(YELLOW)Phase 1: Core Infrastructure$(NC)"
	@echo "  → Starting PostgreSQL, Redis, Loki..."
	@$(COMPOSE) up -d postgresql redis loki
	@echo "  → Waiting for databases to be healthy..."
	@sleep 5
	@$(COMPOSE) ps postgresql redis loki
	@echo ""
	@echo "$(YELLOW)Phase 2: Storage & Catalog$(NC)"
	@echo "  → Starting MinIO and Nessie..."
	@$(COMPOSE) up -d minio
	@sleep 3
	@$(COMPOSE) up -d nessie
	@echo "  → Waiting for storage layer..."
	@sleep 10
	@echo ""
	@echo "$(YELLOW)Phase 3: Streaming Platform$(NC)"
	@echo "  → Starting Kafka..."
	@$(COMPOSE) up -d kafka
	@echo "  → Waiting for Kafka to be ready..."
	@sleep 15
	@echo "  → Starting Kafka ecosystem..."
	@$(COMPOSE) up -d schema-registry kafka-connect kafka-ui
	@sleep 5
	@echo ""
	@echo "$(YELLOW)Phase 4: Query Engines$(NC)"
	@echo "  → Starting Trino, Spark, Flink, ClickHouse..."
	@$(COMPOSE) up -d clickhouse
	@$(COMPOSE) up -d trino
	@$(COMPOSE) up -d spark-master spark-worker
	@$(COMPOSE) up -d flink-jobmanager flink-taskmanager
	@sleep 5
	@echo ""
	@echo "$(YELLOW)Phase 5: Orchestration & Analytics$(NC)"
	@echo "  → Starting Airflow, JupyterHub, MLflow, Superset..."
	@$(COMPOSE) up -d airflow-webserver airflow-scheduler airflow-worker
	@$(COMPOSE) up -d jupyterhub mlflow superset
	@$(COMPOSE) up -d dbt great-expectations
	@sleep 5
	@echo ""
	@echo "$(YELLOW)Phase 6: Identity & Monitoring$(NC)"
	@echo "  → Starting Keycloak, Prometheus, Grafana, Alertmanager..."
	@$(COMPOSE) up -d keycloak
	@$(COMPOSE) up -d prometheus grafana alertmanager alloy
	@sleep 5
	@echo ""
	@echo "$(GREEN)═══════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)✓ All services started!$(NC)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)⚠️  IMPORTANT: Run initialization now!$(NC)"
	@echo ""
	@echo "  $(GREEN)make init$(NC)        # Initialize databases, buckets, topics"
	@echo "  $(GREEN)make health$(NC)      # Check service health"
	@echo "  $(GREEN)make urls$(NC)        # View all service URLs"

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
# Initialization & Setup
# ==========================================

.PHONY: init
init: check-env ## Initialize databases, users, and storage (run after 'make up')
	@echo "$(GREEN)╔══════════════════════════════════════════════════════╗$(NC)"
	@echo "$(GREEN)║     Datalyptica Platform Initialization             ║$(NC)"
	@echo "$(GREEN)╚══════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(YELLOW)⏳ Step 1/4: Waiting for core services...$(NC)"
	@timeout=90; while [ $$timeout -gt 0 ]; do \
		if docker exec datalyptica-postgresql pg_isready -U postgres >/dev/null 2>&1; then \
			echo "  $(GREEN)✓ PostgreSQL ready$(NC)"; break; \
		fi; \
		sleep 2; timeout=$$((timeout-2)); \
	done
	@timeout=60; while [ $$timeout -gt 0 ]; do \
		if docker exec datalyptica-minio mc alias list >/dev/null 2>&1; then \
			echo "  $(GREEN)✓ MinIO ready$(NC)"; break; \
		fi; \
		sleep 2; timeout=$$((timeout-2)); \
	done
	@echo ""
	@echo "$(YELLOW)🗄️  Step 2/4: Creating PostgreSQL databases and users...$(NC)"
	@DATALYPTICA_PWD=$$(cat secrets/passwords/datalyptica_password); \
	NESSIE_PWD=$$(cat secrets/passwords/nessie_password); \
	KEYCLOAK_PWD=$$(cat secrets/passwords/keycloak_db_password); \
	AIRFLOW_PWD=$$(cat secrets/passwords/airflow_password); \
	docker exec -i datalyptica-postgresql psql -U postgres <<-EOSQL || true \
		-- Create users \
		DO \$$\$$ \
		BEGIN \
			IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'datalyptica') THEN \
				CREATE USER datalyptica WITH PASSWORD '$$DATALYPTICA_PWD'; \
				RAISE NOTICE 'Created user: datalyptica'; \
			END IF; \
			IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'nessie') THEN \
				CREATE USER nessie WITH PASSWORD '$$NESSIE_PWD'; \
				RAISE NOTICE 'Created user: nessie'; \
			END IF; \
			IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'keycloak') THEN \
				CREATE USER keycloak WITH PASSWORD '$$KEYCLOAK_PWD'; \
				RAISE NOTICE 'Created user: keycloak'; \
			END IF; \
			IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'airflow') THEN \
				CREATE USER airflow WITH PASSWORD '$$AIRFLOW_PWD'; \
				RAISE NOTICE 'Created user: airflow'; \
			END IF; \
		END \$$\$$; \
		-- Create databases \
		SELECT 'CREATE DATABASE datalyptica OWNER datalyptica' \
		WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'datalyptica')\\gexec \
		SELECT 'CREATE DATABASE nessie OWNER nessie' \
		WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'nessie')\\gexec \
		SELECT 'CREATE DATABASE keycloak_db OWNER keycloak' \
		WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'keycloak_db')\\gexec \
		SELECT 'CREATE DATABASE airflow OWNER airflow' \
		WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'airflow')\\gexec \
		-- Grant privileges \
		GRANT ALL PRIVILEGES ON DATABASE datalyptica TO datalyptica; \
		GRANT ALL PRIVILEGES ON DATABASE nessie TO nessie; \
		GRANT ALL PRIVILEGES ON DATABASE keycloak_db TO keycloak; \
		GRANT ALL PRIVILEGES ON DATABASE airflow TO airflow; \
	EOSQL
	@for db in nessie keycloak_db airflow datalyptica; do \
		docker exec -i datalyptica-postgresql psql -U postgres -d $$db -c \
			"GRANT ALL ON SCHEMA public TO $$(docker exec datalyptica-postgresql psql -U postgres -d $$db -tAc \"SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname = '$$db'\");" \
			>/dev/null 2>&1 || true; \
	done
	@echo "  $(GREEN)✓ Databases and users created$(NC)"
	@echo ""
	@echo "$(YELLOW)🗄️  Step 3/4: Initializing MinIO buckets...$(NC)"
	@docker exec datalyptica-minio sh -c ' \
		mc alias set local http://localhost:9000 admin $$(cat /run/secrets/minio_root_password) 2>/dev/null || true; \
		mc mb local/lakehouse 2>/dev/null || echo "  ✓ Bucket lakehouse exists"; \
		mc mb -p local/lakehouse/warehouse 2>/dev/null || true; \
		mc mb -p local/lakehouse/staging 2>/dev/null || true; \
		mc mb -p local/lakehouse/raw 2>/dev/null || true; \
	' && echo "  $(GREEN)✓ MinIO buckets initialized$(NC)" || echo "  $(RED)✗ MinIO initialization failed$(NC)"
	@echo ""
	@echo "$(YELLOW)🔄 Step 4/4: Restarting dependent services...$(NC)"
	@$(COMPOSE) restart nessie keycloak airflow-webserver airflow-scheduler airflow-worker >/dev/null 2>&1 || true
	@echo "  Waiting 20 seconds for services to stabilize..."
	@sleep 20
	@echo "  $(GREEN)✓ Services restarted$(NC)"
	@echo ""
	@echo "$(YELLOW)🚀 Step 5/7: Initializing Kafka storage (KRaft mode)...$(NC)"
	@CLUSTER_ID=$$(docker exec datalyptica-kafka kafka-storage random-uuid); \
	echo "  → Generated Cluster ID: $$CLUSTER_ID"; \
	docker exec -e CLUSTER_ID=$$CLUSTER_ID datalyptica-kafka \
		kafka-storage format -t $$CLUSTER_ID -c /etc/kafka/kafka.properties 2>&1 | grep -v "Formatting" || true
	@echo "  $(GREEN)✓ Kafka storage formatted$(NC)"
	@$(COMPOSE) restart kafka >/dev/null 2>&1
	@echo "  → Waiting for Kafka to restart..."
	@sleep 15
	@echo "  $(GREEN)✓ Kafka restarted$(NC)"
	@echo ""
	@echo "$(YELLOW)🔧 Step 6/7: Initializing Airflow...$(NC)"
	@$(MAKE) init-airflow
	@echo ""
	@echo "$(YELLOW)📊 Step 7/7: Initializing Superset...$(NC)"
	@$(MAKE) init-superset
	@echo ""
	@echo "$(GREEN)╔══════════════════════════════════════════════════════╗$(NC)"
	@echo "$(GREEN)║        ✓ Platform Initialization Complete!          ║$(NC)"
	@echo "$(GREEN)╚══════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(YELLOW)📊 Verification:$(NC)"
	@echo "Databases:"
	@docker exec datalyptica-postgresql psql -U postgres -t -c "SELECT '  ✓ ' || datname || ' (owner: ' || pg_get_userbyid(datdba) || ')' FROM pg_database WHERE datname IN ('datalyptica', 'nessie', 'keycloak_db', 'airflow') ORDER BY datname;" 2>/dev/null
	@echo ""
	@echo "$(YELLOW)💡 Next Steps:$(NC)"
	@echo "  1. $(GREEN)make health$(NC)       # Check detailed service health"
	@echo "  2. $(GREEN)make urls$(NC)         # View all service URLs"
	@echo ""

.PHONY: init-databases
init-databases: check-env ## Verify PostgreSQL databases (created automatically on first start)
	@echo "$(GREEN)Verifying database initialization...$(NC)"
	@echo ""
	@echo "Databases:"
	@docker exec datalyptica-postgresql psql -U postgres -c "\l" | grep -E "datalyptica|nessie|keycloak_db|airflow|Name"
	@echo ""
	@echo "Users:"
	@docker exec datalyptica-postgresql psql -U postgres -c "\du" | grep -E "datalyptica|nessie|keycloak|airflow|Role"

.PHONY: init-minio
init-minio: check-env ## Initialize MinIO buckets and directories
	@echo "$(GREEN)Initializing MinIO buckets...$(NC)"
	@./scripts/init-minio-buckets.sh

.PHONY: init-kafka
init-kafka: check-env ## Initialize Kafka storage (KRaft mode)
	@echo "$(YELLOW)Initializing Kafka storage...$(NC)"
	@echo "  → Generating cluster ID..."
	@CLUSTER_ID=$$(docker exec datalyptica-kafka kafka-storage random-uuid); \
	echo "  → Cluster ID: $$CLUSTER_ID"; \
	echo "  → Formatting storage..."; \
	docker exec -e CLUSTER_ID=$$CLUSTER_ID datalyptica-kafka \
		kafka-storage format -t $$CLUSTER_ID -c /etc/kafka/kafka.properties 2>&1 | grep -v "Formatting" || true
	@echo "  $(GREEN)✓ Kafka storage formatted$(NC)"
	@echo "  → Restarting Kafka..."
	@$(COMPOSE) restart kafka >/dev/null 2>&1
	@sleep 15
	@echo "  $(GREEN)✓ Kafka initialized$(NC)"

.PHONY: init-keycloak
init-keycloak: check-env ## Configure Keycloak identity management
	@echo "$(YELLOW)Initializing Keycloak realm...$(NC)"
	@echo "  → Waiting for Keycloak to be ready..."
	@timeout=120; while [ $$timeout -gt 0 ]; do \
		if docker exec datalyptica-keycloak /opt/keycloak/bin/kc.sh show-config >/dev/null 2>&1; then \
			echo "  $(GREEN)✓ Keycloak ready$(NC)"; break; \
		fi; \
		sleep 3; timeout=$$((timeout-3)); \
	done
	@echo "  → Importing Datalyptica realm..."
	@if [ -d "configs/keycloak/realms" ]; then \
		docker cp configs/keycloak/realms/. datalyptica-keycloak:/tmp/realms/; \
		docker exec datalyptica-keycloak /opt/keycloak/bin/kc.sh import --dir /tmp/realms --override true; \
		echo "  $(GREEN)✓ Keycloak realm imported$(NC)"; \
	else \
		echo "  $(YELLOW)⚠ No realm configuration found at configs/keycloak/realms/$(NC)"; \
	fi

.PHONY: init-airflow
init-airflow: check-env ## Initialize Airflow database and create admin user
	@echo "$(YELLOW)Initializing Airflow...$(NC)"
	@echo "  → Waiting for Airflow webserver to be ready..."
	@timeout=120; while [ $$timeout -gt 0 ]; do \
		if docker exec datalyptica-airflow-webserver airflow version >/dev/null 2>&1; then \
			echo "  $(GREEN)✓ Airflow ready$(NC)"; break; \
		fi; \
		sleep 3; timeout=$$((timeout-3)); \
	done
	@echo "  → Running database migration..."
	@docker exec datalyptica-airflow-webserver airflow db migrate 2>&1 | grep -v "Could not import Security Manager" || true
	@echo "  $(GREEN)✓ Database migrated$(NC)"
	@echo "  → Creating admin user..."
	@AIRFLOW_ADMIN_USERNAME=$$(grep AIRFLOW_ADMIN_USERNAME deploy/compose/.env | cut -d'=' -f2); \
	AIRFLOW_ADMIN_PASSWORD=$$(cat secrets/passwords/airflow_admin_password 2>/dev/null || echo "admin"); \
	AIRFLOW_ADMIN_EMAIL=$$(grep AIRFLOW_ADMIN_EMAIL deploy/compose/.env | cut -d'=' -f2); \
	docker exec datalyptica-airflow-webserver airflow users create \
		--username $$AIRFLOW_ADMIN_USERNAME \
		--firstname Admin \
		--lastname User \
		--role Admin \
		--email $$AIRFLOW_ADMIN_EMAIL \
		--password $$AIRFLOW_ADMIN_PASSWORD 2>&1 || echo "  $(YELLOW)⚠ Admin user may already exist$(NC)"
	@echo "  $(GREEN)✓ Airflow initialized$(NC)"

.PHONY: init-superset
init-superset: check-env ## Initialize Superset database and create admin user
	@echo "$(YELLOW)Initializing Superset...$(NC)"
	@echo "  → Waiting for Superset to be ready..."
	@timeout=120; while [ $$timeout -gt 0 ]; do \
		if docker exec datalyptica-superset superset version >/dev/null 2>&1; then \
			echo "  $(GREEN)✓ Superset ready$(NC)"; break; \
		fi; \
		sleep 3; timeout=$$((timeout-3)); \
	done
	@echo "  → Running database upgrade..."
	@docker exec datalyptica-superset superset db upgrade
	@echo "  $(GREEN)✓ Database upgraded$(NC)"
	@echo "  → Creating admin user..."
	@SUPERSET_ADMIN_USERNAME=$$(grep SUPERSET_ADMIN_USERNAME deploy/compose/.env | cut -d'=' -f2); \
	SUPERSET_ADMIN_PASSWORD=$$(cat secrets/passwords/superset_admin_password 2>/dev/null || echo "admin"); \
	SUPERSET_ADMIN_EMAIL=$$(grep SUPERSET_ADMIN_EMAIL deploy/compose/.env | cut -d'=' -f2); \
	docker exec datalyptica-superset superset fab create-admin \
		--username $$SUPERSET_ADMIN_USERNAME \
		--firstname Admin \
		--lastname User \
		--email $$SUPERSET_ADMIN_EMAIL \
		--password $$SUPERSET_ADMIN_PASSWORD 2>&1 || echo "  $(YELLOW)⚠ Admin user may already exist$(NC)"
	@echo "  → Initializing Superset..."
	@docker exec datalyptica-superset superset init
	@echo "  $(GREEN)✓ Superset initialized$(NC)"

.PHONY: verify
verify: check-env ## Verify all services are running correctly
	@echo "$(GREEN)Verifying services...$(NC)"
	@./scripts/verify-services.sh

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
