FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline
COPY src ./src
RUN mvn clean package -DskipTests

FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Install JAXB dependencies (removed in Java 9+, needed by Hibernate)
RUN apk add --no-cache wget && \
    mkdir -p /app/lib && \
    wget -q -O /app/lib/jaxb-api.jar https://repo1.maven.org/maven2/javax/xml/bind/jaxb-api/2.3.1/jaxb-api-2.3.1.jar && \
    wget -q -O /app/lib/jaxb-runtime.jar https://repo1.maven.org/maven2/org/glassfish/jaxb/jaxb-runtime/2.3.1/jaxb-runtime-2.3.1.jar && \
    apk del wget

COPY --from=build /app/target/*.jar app.jar
EXPOSE 8083
ENTRYPOINT ["java", "--add-opens", "java.base/java.lang=ALL-UNNAMED", "--add-opens", "java.base/java.lang.reflect=ALL-UNNAMED", "--add-opens", "java.base/java.util=ALL-UNNAMED", "-cp", "app.jar:/app/lib/*", "org.springframework.boot.loader.JarLauncher"]