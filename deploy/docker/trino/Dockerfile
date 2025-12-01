FROM eclipse-temurin:24-jre-alpine-3.21

LABEL maintainer="devops@datalyptica.com"
LABEL description="Custom Trino container for data stack"
LABEL version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/datalyptica/datalyptica"
LABEL org.opencontainers.image.vendor="Datalyptica"
LABEL org.opencontainers.image.title="Trino"
LABEL org.opencontainers.image.description="Trino distributed SQL query engine for Datalyptica lakehouse analytics"

# Set environment variables
ENV TRINO_VERSION=476
ENV TRINO_HOME=/opt/trino

# Switch to root for installation
USER root

# Install dependencies, download Trino, create directories and user in one layer
RUN apk add --no-cache \
        curl \
        wget \
        less \
        python3 \
        py3-pip \
        bash \
    && ln -sf /usr/bin/python3 /usr/bin/python \
    && mkdir -p ${TRINO_HOME} ${TRINO_HOME}/etc/catalog ${TRINO_HOME}/data /var/log/trino /data \
    && cd /tmp \
    && wget -q https://repo1.maven.org/maven2/io/trino/trino-server/${TRINO_VERSION}/trino-server-${TRINO_VERSION}.tar.gz \
    && tar -xzf trino-server-${TRINO_VERSION}.tar.gz \
    && mv trino-server-${TRINO_VERSION}/* ${TRINO_HOME}/ \
    && rm -rf /tmp/trino-server-* \
    && wget -q -O ${TRINO_HOME}/bin/trino https://repo1.maven.org/maven2/io/trino/trino-cli/${TRINO_VERSION}/trino-cli-${TRINO_VERSION}-executable.jar \
    && chmod +x ${TRINO_HOME}/bin/trino \
    && addgroup -g 1000 -S trino \
    && adduser -u 1000 -S -G trino -h /opt/trino -s /bin/sh trino \
    && chown -R trino:trino ${TRINO_HOME} /var/log/trino /data

# Copy entrypoint script
COPY scripts/entrypoint.sh /opt/trino/bin/entrypoint.sh

# Create launcher script
RUN echo '#!/bin/sh' > ${TRINO_HOME}/bin/run-trino && \
    echo 'exec ${TRINO_HOME}/bin/launcher run' >> ${TRINO_HOME}/bin/run-trino && \
    chmod +x ${TRINO_HOME}/bin/run-trino && \
    chmod +x /opt/trino/bin/entrypoint.sh

# Switch to trino user
USER trino

# Set working directory
WORKDIR ${TRINO_HOME}

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/v1/status || exit 1

# Start Trino with entrypoint
CMD ["/opt/trino/bin/entrypoint.sh"] 