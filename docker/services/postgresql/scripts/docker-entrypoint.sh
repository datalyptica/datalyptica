#!/usr/bin/env bash
# PostgreSQL Docker Entrypoint Script
# Based on standard PostgreSQL Docker patterns

set -Eeo pipefail

# Always start as root to handle Docker volume permissions
if [ "$(id -u)" = '0' ]; then
    # Create and fix permissions on data directory
    mkdir -p "$PGDATA"
    mkdir -p /var/run/postgresql
    
    # Fix ownership for Docker volumes (they may mount as root)
    chown -R postgres:postgres "$PGDATA"
    chown -R postgres:postgres /var/run/postgresql
    chown -R postgres:postgres /var/lib/postgresql
    
    # Set proper permissions
    chmod 700 "$PGDATA"
    chmod 755 /var/run/postgresql
    
    # Switch to postgres user and re-execute this script
    exec su-exec postgres "$BASH_SOURCE" "$@"
fi

# Now running as postgres user

# Directory and permission setup
if [ ! -s "$PGDATA/PG_VERSION" ]; then
    # Initialize database if it doesn't exist
    echo "Initializing PostgreSQL database..."
    
    # Set file creation mask
    file_env() {
        local var="$1"
        local fileVar="${var}_FILE"
        local def="${2:-}"
        if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
            echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
            exit 1
        fi
        local val="$def"
        if [ "${!var:-}" ]; then
            val="${!var}"
        elif [ "${!fileVar:-}" ]; then
            val="$(< "${!fileVar}")"
        fi
        export "$var"="$val"
        unset "$fileVar"
    }
    
    file_env 'POSTGRES_PASSWORD'
    file_env 'POSTGRES_USER' 'postgres'
    file_env 'POSTGRES_DB' "$POSTGRES_USER"
    file_env 'POSTGRES_INITDB_ARGS'
    
    # Initialize database cluster
    eval 'initdb --username="$POSTGRES_USER" --pwfile=<(echo "$POSTGRES_PASSWORD") '"$POSTGRES_INITDB_ARGS"
    
    # Configure PostgreSQL with external config files if available
    # Use mounted config files or fall back to defaults
    if [ -f "/etc/postgresql/postgresql.conf" ]; then
        echo "Using external postgresql.conf"
        cp /etc/postgresql/postgresql.conf "$PGDATA/postgresql.conf"
    else
        echo "Using default PostgreSQL configuration"
        {
            echo
            echo "# Default PostgreSQL configuration for ShuDL"
            echo "listen_addresses = '*'"
            echo "port = 5432"
            echo "max_connections = 200"
            echo "shared_buffers = 256MB"
            echo "effective_cache_size = 1GB"
            echo "maintenance_work_mem = 64MB"
            echo "checkpoint_completion_target = 0.9"
            echo "wal_buffers = 16MB"
            echo "default_statistics_target = 100"
            echo "random_page_cost = 1.1"
            echo "effective_io_concurrency = 200"
            echo "work_mem = 4MB"
            echo "min_wal_size = 1GB"
            echo "max_wal_size = 4GB"
            echo "log_destination = 'stderr'"
            echo "logging_collector = off"
            echo "log_statement = 'none'"
            echo "log_min_duration_statement = -1"
        } >> "$PGDATA/postgresql.conf"
    fi
    
    # Configure authentication with external config or defaults
    if [ -f "/etc/postgresql/pg_hba.conf" ]; then
        echo "Using external pg_hba.conf"
        cp /etc/postgresql/pg_hba.conf "$PGDATA/pg_hba.conf"
    else
        echo "Using default authentication configuration"
        {
            echo "# Default authentication configuration for ShuDL"
            echo "local all all trust"
            echo "host all all all md5"
            echo "host all all 0.0.0.0/0 md5"
            echo "host all all ::1/128 md5"
        } > "$PGDATA/pg_hba.conf"
    fi
    
    # Start PostgreSQL temporarily to create database and user
    pg_ctl -D "$PGDATA" -o "-c listen_addresses='localhost'" -w start
    
    # Create database if specified
    if [ "$POSTGRES_DB" != 'postgres' ]; then
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<-EOSQL
            CREATE DATABASE "$POSTGRES_DB";
EOSQL
    fi
    
    # Run initialization scripts
    for f in /docker-entrypoint-initdb.d/*; do
        case "$f" in
            *.sh)
                if [ -x "$f" ]; then
                    echo "Running $f"
                    "$f"
                fi
                ;;
            *.sql)
                echo "Running $f"
                psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f "$f"
                ;;
            *.sql.gz)
                echo "Running $f"
                gunzip -c "$f" | psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB"
                ;;
            *)
                echo "Ignoring $f"
                ;;
        esac
    done
    
    # Stop temporary PostgreSQL instance
    pg_ctl -D "$PGDATA" -m fast -w stop
    
    echo "PostgreSQL initialization complete"
fi

# If running as postgres and first argument is 'postgres', start the server
if [ "$1" = 'postgres' ]; then
    exec postgres
fi

# Otherwise, execute the command as-is
exec "$@"
