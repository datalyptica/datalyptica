# ShuDL Docker Run Script

An alternative to `docker-compose` for running the ShuDL Data Lakehouse using plain Docker commands.

## Overview

The `run-docker.sh` script provides the same functionality as `docker-compose` but uses individual `docker run` commands instead. This gives you more control over each container and can be useful in environments where docker-compose is not available or preferred.

## Features

- ✅ **Complete Container Management**: Start, stop, restart, and check status of all services
- ✅ **Dependency Handling**: Proper startup order and health checks
- ✅ **Environment Variables**: Full support for all configuration from `.env` file
- ✅ **Network & Volume Management**: Automatic creation and cleanup
- ✅ **Health Monitoring**: Container health status reporting
- ✅ **Clean Shutdown**: Graceful stop with proper dependency order
- ✅ **Resource Cleanup**: Option to remove all containers, networks, and volumes

## Quick Start

### 1. Start the entire ShuDL platform:
```bash
cd docker
./run-docker.sh start
```

### 2. Check status:
```bash
./run-docker.sh status
```

### 3. Stop everything:
```bash
./run-docker.sh stop
```

## Available Commands

| Command | Description |
|---------|-------------|
| `start` | Start all ShuDL containers in proper order |
| `stop` | Stop all containers gracefully |
| `restart` | Stop and then start all containers |
| `status` | Show detailed status of all containers, networks, and volumes |
| `cleanup` | Remove all containers, networks, and volumes (destructive!) |
| `help` | Show usage information |

## Examples

### Start the platform
```bash
./run-docker.sh start
```

Output:
```
===============================================================================
🚀 Starting ShuDL Data Lakehouse with Docker Commands
===============================================================================
ℹ️  Loading environment variables from ./docker/.env
✅ Environment variables loaded
🔄 Creating Docker network: shunetwork
✅ Network shunetwork created
🔄 Creating Docker volumes
✅ Volume minio_data created
✅ Volume postgresql_data created
🔄 Starting infrastructure containers (MinIO, PostgreSQL)...
🔄 Starting MinIO container: shudl-minio
✅ MinIO container started
🔄 Starting PostgreSQL container: shudl-postgresql
✅ PostgreSQL container started
🔄 Waiting for shudl-minio to be healthy (max 300s)...
✅ shudl-minio is healthy
🔄 Waiting for shudl-postgresql to be healthy (max 300s)...
✅ shudl-postgresql is healthy
...
🎉 ShuDL Data Lakehouse Started Successfully!
```

### Check status
```bash
./run-docker.sh status
```

Output:
```
===============================================================================
📊 ShuDL Data Lakehouse Status
===============================================================================
  ✅ shudl-minio - Running (Healthy)
  ✅ shudl-postgresql - Running (Healthy)
  ✅ shudl-nessie - Running (Healthy)
  ✅ shudl-trino - Running (Healthy)
  ✅ shudl-spark-master - Running (Healthy)
  ✅ shudl-spark-worker - Running (Healthy)

📊 Network Status:
  ✅ Network 'shunetwork' - Exists

💾 Volume Status:
  ✅ Volume 'minio_data' - Exists
  ✅ Volume 'postgresql_data' - Exists
```

### Stop everything
```bash
./run-docker.sh stop
```

### Complete cleanup (removes data!)
```bash
./run-docker.sh cleanup
```

## Service Endpoints

Once started, the following services will be available:

| Service | Endpoint | Credentials |
|---------|----------|-------------|
| **MinIO Console** | http://localhost:9001 | admin / password123 |
| **MinIO API** | http://localhost:9000 | - |
| **PostgreSQL** | localhost:5432 | nessie / nessie123 |
| **Nessie API** | http://localhost:19120 | - |
| **Trino** | http://localhost:8080 | - |
| **Spark Master UI** | http://localhost:4040 | - |
| **Spark Worker UI** | http://localhost:4041 | - |

## Container Dependencies

The script manages container startup in the correct order:

1. **Infrastructure**: MinIO, PostgreSQL
2. **Catalog**: Nessie (depends on MinIO + PostgreSQL)
3. **Query Engines**: Trino (depends on MinIO + Nessie)
4. **Compute**: Spark Master (depends on MinIO + Nessie)
5. **Workers**: Spark Worker (depends on Spark Master)

## Environment Configuration

The script automatically loads all configuration from `docker/.env`. All the same environment variables from docker-compose are supported:

- Database configurations (PostgreSQL, Nessie)
- Object storage settings (MinIO, S3)
- Query engine settings (Trino)
- Compute engine settings (Spark)
- Network and security settings

## Differences from docker-compose

| Feature | docker-compose | run-docker.sh |
|---------|----------------|---------------|
| **Syntax** | YAML configuration | Bash script with docker commands |
| **Dependencies** | Requires docker-compose | Only requires Docker |
| **Customization** | Limited to YAML options | Full bash scripting flexibility |
| **Debugging** | Less verbose | Detailed logging and status |
| **Health Checks** | Basic support | Enhanced monitoring |
| **Cleanup** | Manual volume cleanup | Integrated cleanup command |

## Troubleshooting

### Container not starting
```bash
# Check logs for specific container
docker logs shudl-[service-name]

# Example: Check Spark Master logs
docker logs shudl-spark-master
```

### Port conflicts
```bash
# Check if ports are in use
netstat -tlnp | grep -E "9000|9001|5432|19120|8080|4040|7077"

# Stop conflicting services or change ports in .env file
```

### Clean restart
```bash
# Stop everything
./run-docker.sh stop

# Clean restart (keeps data)
./run-docker.sh start

# Or complete cleanup (removes data!)
./run-docker.sh cleanup
./run-docker.sh start
```

### Health check failures
```bash
# Check container status
./run-docker.sh status

# Inspect specific container
docker container inspect shudl-[service-name]

# Check health command manually
docker exec shudl-[service-name] [health-command]
```

## Monitoring

You can monitor the containers using standard Docker commands:

```bash
# List all ShuDL containers
docker ps -f name=shudl

# Monitor resource usage
docker stats $(docker ps -f name=shudl --format="{{.Names}}")

# Follow logs for all containers
docker logs -f shudl-spark-master
```

## Integration with Existing Tools

The script works alongside your existing Docker workflow:

```bash
# Use with docker commands
docker exec -it shudl-spark-master spark-sql
docker exec -it shudl-trino trino

# Network is available for other containers
docker run --network shunetwork your-app:latest

# Volumes can be shared
docker run -v minio_data:/data your-backup-tool:latest
```

## Security Considerations

- All default passwords should be changed for production use
- The script preserves all security settings from the original docker-compose configuration
- Network isolation is maintained through the dedicated `shunetwork` bridge network
- Health checks ensure services are running properly before marking as ready

## Production Usage

For production environments:

1. **Update credentials** in `docker/.env`
2. **Review resource limits** (add `--memory`, `--cpus` flags as needed)
3. **Configure log rotation** (add `--log-driver` options)
4. **Set up monitoring** (integrate with your monitoring stack)
5. **Backup volumes** regularly (especially `postgresql_data` and `minio_data`)

This script provides the same functionality as docker-compose but with more transparency and control over the container lifecycle. 