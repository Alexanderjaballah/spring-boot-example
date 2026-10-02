# Java 17 to Java 21 Migration Plan, Service A

## Scope

This plan implements the bounded migration defined in
[`java17-to-java21.md`](java17-to-java21.md). It updates the Java runtime
baseline without adding features, redesigning the application, broadly
modernizing dependencies, or refactoring unrelated code.

## Files likely to change

| File | Planned change |
| --- | --- |
| `pom.xml` | Change `java.version` from 17 to 21 and change the Maven Enforcer Java range from `[17,18)` to `[21,22)`. The existing `maven.compiler.release` follows `java.version`. |
| `.github/workflows/ci.yml` | Change the setup step label and `java-version` from 17 to 21. |
| `Dockerfile` | Replace the Java 17 Temurin base image with an approved Java 21 Temurin image. |
| `README.md` | Update Java version references in the tech stack and prerequisites. |
| `AGENTS.md` | Update the Java baseline and Enforcer guidance after the migration. |
| `specs/java17-to-java21.md` | Update only if evidence or an approved decision changes the migration specification. |

No application source or test source changes are expected unless Java 21
validation identifies a genuine compatibility defect.

## Required build and plugin changes

1. Update `pom.xml` Java version and Enforcer range in the same change.
2. Keep Maven Wrapper 3.9.11. It supports Java 21 and does not need a version
   change.
3. Keep the existing Spring Boot Maven plugin and Maven Enforcer plugin unless
   validation identifies an incompatibility. Spring Boot 3.4.4 and
   `maven-enforcer-plugin` 3.5.0 are expected to run on Java 21.
4. Update CI, Maven compilation, and Docker runtime together. A Java 21
   artifact will not run in the existing Java 17 container.

## Dependency compatibility risks

- The direct `junit-platform-suite` 6.0.0 declaration overrides the
  Spring Boot-managed JUnit Platform 1.11.x components. Cucumber 7.20.1 uses
  the JUnit Platform engine and must be specifically validated on Java 21.
- If that suite fails, first investigate alignment with the Spring Boot BOM.
  Removing the direct override or upgrading Cucumber would be a dependency
  decision outside the normal bounded migration and requires approval.
- Spring Boot 3.4.4, Spring Cloud 2024.0.1, Lombok, H2, Hibernate, WireMock,
  springdoc, and the Boot-managed proxy stack are expected to support Java 21,
  but the resolved dependency tree must still be validated in the Java 21
  build.
- `CakeDatabasePopulator` uses `new URL(String)`, which is deprecated on
  modern JDKs but remains functional on Java 21. Do not refactor it unless it
  blocks the migration.

## Test impact

- Run `./mvnw -B -ntp clean verify` using Java 21. It is the required full
  build and test command.
- Confirm all existing tests run, especially:
  - `CakeControllerTest`
  - `CakeDatabasePopulatorTest`
  - `OpenApiTest`
  - `SwaggerUITest`
  - `RunCucumberTest`
- The Cucumber suite is the highest compatibility risk because of the JUnit
  Platform version mix.
- H2, WireMock, random ports, and existing database cleanup provide current
  test isolation. No production-database coverage exists.

## Runtime compatibility risks

- A Java 21 class file (major version 65) fails on the current Java 17 Docker
  runtime (major version 61). The Docker base image must change with the build
  target.
- The current image is an old Java 17 Focal image. Select a supported Java 21
  Temurin image and record the approved tag.
- The application fetches remote cake data at startup. No controlled local
  replacement exists for this production startup dependency.
- CI builds the Docker image but does not start it, so Java 21 container
  startup needs explicit smoke validation.
- No JVM flags, alternate GC settings, or JDK-internal APIs are present.
  Virtual threads must not be introduced as part of this migration.

## Recommended migration sequence

1. Confirm the Java 21 Docker image tag and JUnit Platform compatibility
   strategy with the responsible maintainer.
2. Change `pom.xml` from Java 17 to Java 21 and update the Enforcer range in
   the same change.
3. Update the CI Java version and Docker base image in that same change set.
4. Update Java-version references in `README.md` and `AGENTS.md`.
5. Run `./mvnw -B -ntp clean verify` on Java 21 and retain the full output.
6. Build and start the Java 21 Docker image, then verify `/v3/api-docs` and
   authenticated `GET /cakes`.
7. Review the dependency/configuration diff and source diff for scope control.
8. Obtain an independent review before merging.

## Required evidence

- Java 21 build output.
- Complete test results.
- Dependency and configuration diff.
- Source diff.
- Docker build and smoke-test output.
- CI result using Java 21.
- Independent review.

## Human confirmation required

- The exact Java 21 Temurin Docker tag and whether changing from JDK to JRE is
  approved.
- Whether the direct JUnit Platform Suite 6.0.0 override should remain if
  Cucumber tests expose an incompatibility.
- Whether `actions/checkout@v3` and `actions/setup-java@v3` should be updated.
  This is unrelated dependency modernization and is out of scope unless
  explicitly approved.
- The required Java 21 patch level and distribution policy for CI and runtime.
- Whether the uncommitted migration specification and plan should be committed
  with the migration work or separately.

## Out of scope

- New features.
- Architecture redesign.
- Broad formatting changes.
- Unrelated dependency modernization.
- Observability, release automation, feature flags, DAST, analytics, and
  broader enterprise-readiness work.
