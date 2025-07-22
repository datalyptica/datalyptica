FROM eclipse-temurin:24-jre-alpine-3.21

LABEL maintainer="devops@shugur.com"
LABEL description="Custom Trino container for data stack"
LABEL version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/Shugur-Network/shudl"
LABEL org.opencontainers.image.vendor="Shugur Network"
LABEL org.opencontainers.image.title="Trino"
LABEL org.opencontainers.image.description="Trino distributed SQL query engine for ShuDL lakehouse analytics"

# Set environment variables
ENV TRINO_VERSION=476
ENV TRINO_HOME=/opt/trino

# Switch to root for installation
USER root

# Install dependencies
RUN apk add --no-cache \
        curl \
        wget \
        less \
        python3 \
        py3-pip \
        bash \
    && ln -sf /usr/bin/python3 /usr/bin/python

# Download and install Trino
RUN mkdir -p ${TRINO_HOME} && \
    cd /tmp && \
    wget -q https://repo1.maven.org/maven2/io/trino/trino-server/${TRINO_VERSION}/trino-server-${TRINO_VERSION}.tar.gz && \
    tar -xzf trino-server-${TRINO_VERSION}.tar.gz && \
    mv trino-server-${TRINO_VERSION}/* ${TRINO_HOME}/ && \
    rm -rf /tmp/trino-server-*

# Install Trino CLI
RUN wget -q -O ${TRINO_HOME}/bin/trino https://repo1.maven.org/maven2/io/trino/trino-cli/${TRINO_VERSION}/trino-cli-${TRINO_VERSION}-executable.jar && \
    chmod +x ${TRINO_HOME}/bin/trino

# Create necessary directories
RUN mkdir -p ${TRINO_HOME}/etc/catalog && \
    mkdir -p ${TRINO_HOME}/data && \
    mkdir -p /var/log/trino && \
    mkdir -p /data

    
# Create trino user with standard UID (1000 - standard application user)
RUN addgroup -g 1000 -S trino && \
    adduser -u 1000 -S -G trino -h /opt/trino -s /bin/sh trino
    
# Set ownership
RUN chown -R trino:trino ${TRINO_HOME} && \
    chown -R trino:trino /var/log/trino && \
    chown -R trino:trino /data

# Copy entrypoint script
COPY services/trino/scripts/entrypoint.sh /opt/trino/bin/entrypoint.sh

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