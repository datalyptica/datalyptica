FROM  eclipse-temurin:24-jre-alpine-3.21

LABEL maintainer="devops@datalyptica.com"
LABEL description="Custom Nessie container for data stack"
LABEL version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/datalyptica/datalyptica"
LABEL org.opencontainers.image.vendor="Datalyptica"
LABEL org.opencontainers.image.title="Nessie"
LABEL org.opencontainers.image.description="Project Nessie Git-like catalog for Apache Iceberg tables"

# Set environment variables
ENV NESSIE_VERSION=0.104.3
ENV NESSIE_HOME=/opt/nessie

# Switch to root for installation
USER root

# Install dependencies, create directories, and download Nessie in one layer
RUN apk add --no-cache \
        curl \
        wget \
        postgresql-client \
        gettext \
    && mkdir -p ${NESSIE_HOME}/config /var/log/nessie \
    && cd ${NESSIE_HOME} \
    && wget -q https://github.com/projectnessie/nessie/releases/download/nessie-${NESSIE_VERSION}/nessie-quarkus-${NESSIE_VERSION}-runner.jar -O nessie-server.jar

# Copy configuration template
COPY ../../configs/nessie/application.properties.template ${NESSIE_HOME}/config/application.properties.template

# Copy entrypoint script
COPY scripts/entrypoint.sh ${NESSIE_HOME}/entrypoint.sh

    # Create nessie user and set ownership in one layer
    RUN addgroup -g 1000 -S nessie \
    && adduser -u 1000 -S -G nessie -h /opt/nessie -s /bin/sh nessie \
    && chown -R nessie:nessie ${NESSIE_HOME} /var/log/nessie \
    && chmod +x ${NESSIE_HOME}/entrypoint.sh

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