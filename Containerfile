FROM registry.redhat.io/jboss-eap-7/eap74-openjdk8-runtime-openshift-rhel8:latest

# Copy standalone configuration
COPY standalone-full.xml /opt/eap/standalone/configuration/

# Copy application WAR
COPY target/ROOT.war /opt/eap/standalone/deployments/

# EAP will use environment variables from deployment
# DB_HOST, DB_PORT, DB_NAME, DB_USERNAME, DB_PASSWORD

# Expose ports
EXPOSE 8080 8443 8778

# Run EAP
CMD ["/opt/eap/bin/standalone.sh", "-b", "0.0.0.0", "-c", "standalone-full.xml"]
