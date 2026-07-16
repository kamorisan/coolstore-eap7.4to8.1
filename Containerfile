# Stage 1: Build with Maven
FROM registry.access.redhat.com/ubi8/openjdk-8:latest AS builder

USER root

# Install Maven
RUN microdnf install -y maven && microdnf clean all

# Copy source code
COPY --chown=jboss:jboss . /workspace
WORKDIR /workspace

# Build WAR file
RUN mvn clean package -DskipTests

# Stage 2: Runtime with EAP
FROM registry.redhat.io/jboss-eap-7/eap74-openjdk8-runtime-openshift-rhel8:latest

# Copy standalone configuration
COPY --chown=jboss:jboss standalone-full.xml /opt/eap/standalone/configuration/

# Copy application WAR from builder stage
COPY --chown=jboss:jboss --from=builder /workspace/target/ROOT.war /opt/eap/standalone/deployments/

# EAP will use environment variables from deployment
# DB_HOST, DB_PORT, DB_NAME, DB_USERNAME, DB_PASSWORD

# Set server configuration file
ENV STANDALONE_XML=standalone-full.xml

# Expose ports
EXPOSE 8080 8443 8778
