# Quick Start Guide

Get ShuDL running in under 5 minutes with the easiest deployment method.

## 🚀 Fastest Path to Running ShuDL

### Option 1: Web Installer (Recommended)

**Perfect for**: First-time users, development, and quick testing

```bash
# 1. Clone and build
git clone https://github.com/Shugur-Network/shudl.git
cd shudl
go build -o bin/installer cmd/installer/main.go

# 2. Start web interface
./bin/installer

# 3. Open browser
open http://localhost:8080
```

**Next steps**: Use the web interface to select services and deploy with one click.

### Option 2: Docker Compose (Traditional)

**Perfect for**: Users familiar with Docker Compose

```bash
# 1. Setup environment
cd docker
cp .env.dev .env

# 2. Start services
docker compose up -d

# 3. Check status
docker compose ps
```

## 🎯 Access Your Services

Once running, access these endpoints:

| Service | URL | Purpose |
|---------|-----|---------|
| **Web Installer** | http://localhost:8080 | Management interface |
| **MinIO Console** | http://localhost:9001 | Object storage (admin/password123) |
| **Trino** | http://localhost:8080 | SQL query engine |
| **Spark UI** | http://localhost:4040 | Data processing |
| **Nessie API** | http://localhost:19120 | Data catalog |

## ✅ Verify Everything Works

```bash
# Test Nessie API
curl http://localhost:19120/api/v2/config

# Test MinIO
curl http://localhost:9000/minio/health/live

# View all services
docker ps --filter name=shudl
```

## 🔧 Default Credentials

**Development Environment** (change for production):
- **MinIO**: admin / password123
- **PostgreSQL**: nessie / nessie123

## 🚨 Troubleshooting

**Port conflicts**: Check if ports 8080, 9000, 9001, 5432, 19120, 4040 are free
```bash
netstat -tlnp | grep -E "8080|9000|9001|5432|19120|4040"
```

**Service not starting**: Check logs
```bash
docker logs shudl-[service-name]
```

**Memory issues**: Ensure Docker has at least 8GB RAM allocated

## 📖 Next Steps

- **Configuration**: See [deployment guide](../deployment/deployment-guide.md)
- **Production**: Read [production setup](../examples/production-setup.md)  
- **Development**: Check [development setup](../examples/development-setup.md)
- **Migration**: See [migration guide](migration-guide.md) if upgrading

## 🆘 Need Help?

- 📚 **Full Documentation**: [Main README](../../README.md)
- 🐛 **Issues**: [GitHub Issues](https://github.com/Shugur-Network/shudl/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/Shugur-Network/shudl/discussions) 