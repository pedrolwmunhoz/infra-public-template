# Build stage
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /app

# Copia pom e baixa dependências (cache em camada separada)
COPY pom.xml .
RUN apk add --no-cache maven && \
    mvn dependency:go-offline -B

# Copia código e faz o build (skip tests no build da imagem; rode testes no CI)
COPY src ./src
RUN mvn package -DskipTests -B && \
    # Ajuste o padrao do nome do JAR conforme seu projeto
    mv target/*.jar target/app.jar

# Run stage
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Usuário não-root
RUN addgroup -g 1000 app && adduser -u 1000 -G app -D app
USER app

COPY --from=builder /app/target/app.jar ./app.jar

# Porta padrão da aplicação (override com PORT no k8s)
ENV PORT=8081
EXPOSE 8081

ENTRYPOINT ["java", "-jar", "app.jar"]
