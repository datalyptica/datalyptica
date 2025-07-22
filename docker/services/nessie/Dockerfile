FROM  eclipse-temurin:24-jre-alpine-3.21

LABEL maintainer="devops@shugur.com"
LABEL description="Custom Nessie container for data stack"
LABEL version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/Shugur-Network/shudl"
LABEL org.opencontainers.image.vendor="Shugur Network"
LABEL org.opencontainers.image.title="Nessie"
LABEL org.opencontainers.image.description="Project Nessie Git-like catalog for Apache Iceberg tables"

# Set environment variables
ENV NESSIE_VERSION=0.104.3
ENV NESSIE_HOME=/opt/nessie

# Switch to root for installation
USER root

# Install dependencies
RUN apk add --no-cache \
        curl \
        wget \
        postgresql-client \
        gettext


# Create necessary directories
RUN mkdir -p ${NESSIE_HOME} && \
    mkdir -p /var/log/nessie

# Download Nessie server
RUN cd ${NESSIE_HOME} && \
    wget -q https://github.com/projectnessie/nessie/releases/download/nessie-${NESSIE_VERSION}/nessie-quarkus-${NESSIE_VERSION}-runner.jar -O nessie-server.jar

# Create configuration directory
RUN mkdir -p ${NESSIE_HOME}/config

# Copy configuration template
COPY config/nessie/application.properties.template ${NESSIE_HOME}/config/application.properties.template

# Copy entrypoint script
COPY services/nessie/scripts/entrypoint.sh ${NESSIE_HOME}/entrypoint.sh

    # Create nessie user (use existing nessie group)
    RUN addgroup -g 1000 -S nessie && \
        adduser -u 1000 -S -G nessie -h /opt/nessie -s /bin/sh nessie

# Set ownership
RUN chown -R nessie:nessie ${NESSIE_HOME} && \
    chown -R nessie:nessie /var/log/nessie && \
    chmod +x ${NESSIE_HOME}/entrypoint.sh

# Switch to nessie user
USER nessie

# Set working directory
WORKDIR ${NESSIE_HOME}

# Expose port
EXPOSE 19120

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:19120/api/v2/config || exit 1

# Start Nessie
CMD ["sh", "/opt/nessie/entrypoint.sh"] 