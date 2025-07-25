# ShuDL Configuration Migration Guide

## 🚀 What Changed

ShuDL has migrated from file-based configuration to a modern environment-based configuration system.

### Before (Old System)
```
shudl/
├── .env                     # Root environment file
├── docker-compose.yml       # Root Docker Compose
├── configure.sh             # Old configuration script
└── docker/
    └── config/              # Separate config files
        ├── postgresql/
        ├── trino/
        ├── spark/
        └── nessie/
```

### After (New System)
```
shudl/
├── README.md               # Updated documentation
└── docker/                 # All Docker-related files
    ├── .env                # Environment configuration
    ├── docker-compose.yml  # Main Docker Compose
    ├── env-manager.sh      # Environment management
    ├── test-config.sh      # Configuration validation
    └── config/             # Legacy files (reference only)
```

## 🔄 Migration Steps

If you're upgrading from the old system:

1. **Navigate to docker directory:**
   ```bash
   cd docker/
   ```

2. **Setup new environment:**
   ```bash
   ./env-manager.sh setup dev    # For development
   # or
   ./env-manager.sh setup prod   # For production
   ```

3. **Start services with new system:**
   ```bash
   docker compose up -d
   ```

4. **Validate configuration:**
   ```bash
   ./test-config.sh
   ```

## ✅ Benefits of New System

- **Centralized Configuration**: All settings in one `.env` file
- **Environment Management**: Easy dev/staging/prod switching
- **Comprehensive Coverage**: 160+ configuration parameters
- **Built-in Validation**: Configuration testing and validation
- **Security**: No hardcoded credentials
- **Maintainability**: Single source of truth for all settings

## 🗑️ Removed Files

The following files have been removed from the root directory:
- `.env` (moved to `docker/.env`)
- `docker-compose.yml` (moved to `docker/docker-compose.yml`)
- `configure.sh` (replaced by `docker/env-manager.sh`)
- Environment templates (moved to `docker/`)

## 📚 Documentation

- Main configuration guide: [`docker/README-config.md`](docker/README-config.md)
- Complete migration details: [`docker/COMPLETE-CONFIG-MIGRATION.md`](docker/COMPLETE-CONFIG-MIGRATION.md)
- Updated main README: [`README.md`](../README.md)
