# Java 17 to Java 21 Migration Specification

## Objective

Upgrade this Spring Boot service from Java 17 to Java 21 while preserving its current behavior, API contract, test suite, and deployment expectations.

## Acceptance criteria

- The application builds successfully on Java 21.
- All existing tests pass on Java 21.
- Required build plugins and dependencies are compatible with Java 21.
- No public API regressions are introduced.
- No unrelated refactoring is included.
- CI passes with the Java 21 configuration.
- No new critical security findings are introduced.

## Non-goals

- No new features.
- No architecture redesign.
- No unrelated dependency modernization.
- No broad formatting changes.

## Required evidence

- Java 21 build output.
- Complete test results.
- Dependency and configuration diff.
- Source diff.
- Independent review of the migration changes.

## Known migration risks

- Maven, CI, and the Docker runtime must move to Java 21 together. A Java 21 artifact cannot run in the current Java 17 container image.
- The Maven Enforcer rule currently requires Java 17 and must be deliberately updated as part of the migration.
- The project has a direct JUnit Platform Suite 6.0.0 declaration alongside Spring Boot-managed JUnit Platform components, requiring compatibility verification.
- The application performs a startup-time request to a remote cake-data URL, with no local substitute for production startup behavior.
- The current test suite uses H2 and WireMock; it does not validate a production database or external service behavior.
- No formatter, linter, coverage threshold, or dependency analysis currently provides additional regression detection.
