FROM eclipse-temurin:17-jdk AS builder

WORKDIR /app

# Copy gradle files first for better caching
COPY gradle/ gradle/
COPY gradlew build.gradle settings.gradle ./
COPY buildSrc/ buildSrc/

# Download dependencies
RUN ./gradlew --no-daemon dependencies

# Copy source code
COPY spring-boot-project/ spring-boot-project/

# Build the project
RUN ./gradlew --no-daemon build -x test

# Create a smaller runtime image
FROM eclipse-temurin:17-jre

WORKDIR /app

# Create a non-root user to run the application
RUN groupadd -r spring && useradd -r -g spring spring

# Set the application directory ownership
RUN mkdir -p /app && chown -R spring:spring /app

# Switch to non-root user
USER spring

# Copy the built artifacts from the builder stage
# Assuming the main application JAR is in spring-boot-project/spring-boot-project/spring-boot-application/build/libs/
COPY --from=builder --chown=spring:spring /app/spring-boot-project/spring-boot-project/spring-boot-application/build/libs/*.jar /app/application.jar

# Expose the application port
EXPOSE 8080

# Set JVM options
ENV JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseG1GC -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/tmp"

# Set the entrypoint
ENTRYPOINT exec java $JAVA_OPTS -jar /app/application.jar