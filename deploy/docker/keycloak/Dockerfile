# Keycloak - Identity and Access Management
FROM quay.io/keycloak/keycloak:23.0

LABEL org.opencontainers.image.title="Datalyptica Keycloak"
LABEL org.opencontainers.image.description="Custom Keycloak for Datalyptica Data Lakehouse IAM"
LABEL org.opencontainers.image.vendor="Datalyptica"
LABEL org.opencontainers.image.source="https://github.com/datalyptica/datalyptica"

# Install custom themes and providers
USER root

# Create custom themes directory
RUN mkdir -p /opt/keycloak/themes/datalyptica

# Copy custom theme (if exists)
COPY themes/datalyptica/ /opt/keycloak/themes/datalyptica/

# Copy custom realm configurations
COPY config/realms/ /opt/keycloak/data/import/

# Set ownership
RUN chown -R keycloak:keycloak /opt/keycloak/themes /opt/keycloak/data

USER keycloak

# Build Keycloak for production
RUN /opt/keycloak/bin/kc.sh build \
    --db=postgres \
    --http-relative-path=/auth \
    --health-enabled=true \
    --metrics-enabled=true

# Expose Keycloak ports
EXPOSE 8080 8443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /opt/keycloak/bin/kc.sh show-config || exit 1

# Set entrypoint
ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
