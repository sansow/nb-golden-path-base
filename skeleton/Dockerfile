# NB Golden Path - Multi-stage build
# Language: ${{ values.language }}

# Stage 1: Build
FROM registry.access.redhat.com/ubi9/openjdk-${{ values.java_version }}:latest AS builder
WORKDIR /build
COPY . .
RUN mvn package -DskipTests -B

# Stage 2: Runtime
FROM registry.access.redhat.com/ubi9/openjdk-${{ values.java_version }}-runtime:latest
WORKDIR /app

LABEL io.k8s.display-name="${{ values.component_id }}" \
      io.openshift.tags="${{ values.language }},${{ values.system }}" \
      backstage.io/component="${{ values.component_id }}"

COPY --from=builder /build/target/*.jar app.jar

USER 1001
EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
