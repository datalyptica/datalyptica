# JupyterHub Multi-User Platform

FROM jupyterhub/jupyterhub:4.0.2

# Set working directory
WORKDIR /srv/jupyterhub

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    postgresql-client \
    vim \
    gosu \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages for spawner and authenticator
RUN pip install --no-cache-dir \
    dockerspawner==13.0.0 \
    jupyterhub-nativeauthenticator==1.2.0 \
    jupyterhub-idle-culler==1.2.1 \
    psycopg2-binary==2.9.9 \
    sqlalchemy==2.0.23 \
    oauthlib==3.2.2 \
    requests==2.31.0

# Create configuration directory
RUN mkdir -p /srv/jupyterhub/config

# Set environment
ENV JUPYTERHUB_CONFIG_DIR=/srv/jupyterhub/config
ENV JUPYTERHUB_DATA_DIR=/srv/jupyterhub/data

# Create non-root user
RUN groupadd -r -g 1000 shusr && \
    useradd -r -u 1000 -g shusr -s /bin/bash -m shusr && \
    chown -R shusr:shusr /srv/jupyterhub

# Expose JupyterHub port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/hub/health || exit 1

# Copy entrypoint
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["jupyterhub", "-f", "/srv/jupyterhub/config/jupyterhub_config.py"]
