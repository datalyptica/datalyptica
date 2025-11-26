FROM confluentinc/cp-schema-registry:7.5.0

USER root

# Install additional tools (RHEL-based)
RUN microdnf install -y curl jq nmap-ncat && \
    microdnf clean all

# Create necessary directories
RUN mkdir -p /etc/schema-registry/secrets

# Health check script
COPY services/schema-registry/scripts/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/healthcheck.sh

USER appuser

HEALTHCHECK --interval=10s --timeout=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

EXPOSE 8081

CMD ["/etc/confluent/docker/run"]
