# Agent Readiness Baseline

Captured before any remediation for the Java 17 to Java 21 migration experiment.

- **Readiness level:** Level 2
- **Readiness:** 26.4%
- **Evaluated signals passed:** 19/72

## Migration-relevant gaps

- Java version alignment is incomplete: Maven, CI, and the Docker runtime must move to Java 21 together.
- Build reproducibility is weak: there is no Maven Wrapper, toolchain enforcement, or pinned build environment.
- CI packages the application and builds an image but does not start or smoke-test the deployed container.
- Dependency validation is limited: there is no convergence or unused-dependency check, and the JUnit Platform declaration is not clearly aligned with Spring Boot-managed versions.
- Production configuration embeds credentials, uses in-memory H2 with `create-drop`, and performs a startup-time remote data fetch without resilience controls.
- Migration confidence is constrained by missing coverage thresholds, production-database validation, health checks, observability, and security automation.

## Assessment note

This baseline was captured before any remediation. It records the repository's initial readiness state and is not evidence that any identified gap has been fixed.
