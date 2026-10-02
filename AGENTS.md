# Agent Guide

## Baseline

This repository targets **Java 21**. The Maven Enforcer rule rejects JDKs outside the Java 21 range and Maven versions outside the checked-in wrapper baseline. Do not change `java.version`, the Enforcer ranges, CI Java version, or Docker Java image independently. Any future JDK migration must update and validate those four places together.

Use the checked-in Maven Wrapper. It pins Maven 3.9.11 and removes the need for a system Maven installation.

## Commands

Run all commands from the repository root.

```sh
# Full deterministic build and test suite
./mvnw -B -ntp clean verify

# Run one test class
./mvnw -B -ntp -Dtest=CakeControllerTest test

# Start the API
./mvnw -B -ntp spring-boot:run

# Package and start the Docker image
./mvnw -B -ntp clean package
docker build -t cake-service .
docker run --rm -p 8081:8081 cake-service
```

The API listens on port 8081. Swagger is at `/swagger-ui/index.html` and OpenAPI is at `/v3/api-docs`.

## Local configuration

Copy `.env.example` to `.env`; `.env` is ignored by Git. Export it before starting the application:

```sh
set -a
source .env
set +a
```

`CAKES_AUTHENTICATION_USERNAME` and `CAKES_AUTHENTICATION_PASSWORD` configure basic authentication. Never commit real credentials.

## Repository conventions

- Keep production code in `src/main/java` and tests in `src/test/java`.
- Use records for request and response DTOs. Keep persistence entities in `repository/model`.
- Controller tests use `WebTestClient`; integration tests use `@CakeServiceSpringTest`, H2, and WireMock.
- Run `./mvnw -B -ntp clean verify` before handing off a change.
- Do not edit generated `target/` files or commit `.env`, IDE metadata, or build artifacts.
