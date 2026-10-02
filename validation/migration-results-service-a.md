# Migration Results — Service A: Java 17 → Java 21

Execution of the approved migration (`validation/migration-approval-service-a.md`), following
`specs/java17-to-java21.md` and `specs/migration-plan-service-a.md`, validated against
`validation/validation-plan-service-a.md`.

Status: **Migration implemented and locally validated. Not committed. Human review before merge required.**

---

## 1. Outcome summary

| Item | Result |
| --- | --- |
| Build on Java 21 | PASS — `BUILD SUCCESS` |
| Full test suite on Java 21 | PASS — 24 tests, 0 failures, 0 errors, 0 skipped (3 consecutive runs) |
| Java 21 bytecode | PASS — class file major version 65 |
| Enforcer | PASS — accepts JDK 21, rejects JDK 17 with `[21,22)` |
| Negative runtime check | PASS — Java 21 jar fails on JDK 17 with `UnsupportedClassVersionError` |
| JUnit Platform skew | RESOLVED — all `org.junit.platform` artifacts now `1.11.4` |
| API contract | PASS — all endpoints match expected status/shape at runtime |
| Docker runtime | PASS — image runs Java 21, app starts, smoke tests pass |
| Source changes | NONE — no changes under `src/` |
| Dependency changes | Only `junit-platform-suite` 6.0.0 → 1.11.4 (empty aggregator) |

---

## 2. Changes made

```
.github/workflows/ci.yml   JDK 17 -> JDK 21 (step name + java-version)
AGENTS.md                  baseline guidance updated to Java 21
Dockerfile                 eclipse-temurin:17.0.5_8-jdk-focal -> eclipse-temurin:21.0.12_8-jdk-noble
README.md                  tech-stack and prerequisite Java version 17 -> 21
pom.xml                    java.version 17 -> 21; enforcer [17,18) -> [21,22);
                           junit-platform-suite explicit 6.0.0 version removed (now BOM-managed)
```

The four Java-version locations are aligned at 21: Maven property (`java.version`), Maven
Enforcer range (`[21,22)`), CI (`java-version: '21'`), and Dockerfile base image (Temurin 21).
`maven.compiler.release` and the Spring Boot-managed Kotlin `jvmTarget` follow `java.version`
and moved to 21 automatically.

**No production or test source was changed.** `git status` shows only the five files above.

---

## 3. JUnit Platform skew — investigation and resolution

**Observed (baseline, Java 17):** `junit-platform-suite` resolved to `6.0.0` (direct
declaration) while every other `org.junit.platform` artifact was managed to `1.11.4`:

```
org.junit.platform:junit-platform-suite:jar:6.0.0:test
   +- junit-platform-suite-api:jar:1.11.4 (version managed from 6.0.0)
   \- junit-platform-suite-engine:jar:1.11.4 (version managed from 6.0.0)
```

**Root cause:** `junit-platform-suite` is an empty aggregator artifact. Inspecting the cached
`6.0.0` jar shows only `META-INF/*` and `module-info.class` — no API or engine classes. Its
transitive `suite-api`/`suite-engine` were already pinned to `1.11.4` by the Spring Boot BOM.
The "skew" was therefore a metadata-only mismatch that happened not to break the build, not a
classpath conflict. It originated from a Dependabot bump (commit `a61feca`, PR #107) that
raised the aggregator to `6.0.0` without changing the actual platform jars.

**Resolution:** removed the explicit `6.0.0` version (and its now-unused property) so the
aggregator aligns with the Spring Boot-managed `1.11.4`. This is the correct, minimal fix
rather than upgrading Cucumber or adding another override. After the change, all platform
artifacts are `1.11.4`, matching what Cucumber `7.20.1` targets.

**Verified after change:**

```
org.junit.platform:junit-platform-suite:jar:1.11.4:test
org.junit.platform:junit-platform-suite-api:jar:1.11.4:test
org.junit.platform:junit-platform-suite-engine:jar:1.11.4:test
org.junit.platform:junit-platform-suite-commons:jar:1.11.4:test
org.junit.platform:junit-platform-engine:jar:1.11.4:test
org.junit.platform:junit-platform-commons:jar:1.11.4:test
org.junit.platform:junit-platform-launcher:jar:1.11.4:test
org.junit.jupiter:*:5.11.4
```

Cucumber scenarios (which exercise this engine) pass on Java 21.

---

## 4. Validation-plan checks

### Build

| Check | Result |
| --- | --- |
| B1 toolchain (Maven 3.9.11 + JDK 21.0.12.1) | PASS |
| B2 enforcer accepts 21 / rejects 17 | PASS (`Detected JDK version 17.0.20-1 ... not in the allowed range [21,22)`) |
| B3 `clean verify` | PASS |
| B4 `target/classes` major version 65 | PASS |
| B5 packaged jar major version 65 | PASS (`cafe babe 0000 0041`) |
| B6 jar fails on JDK 17 | PASS (`UnsupportedClassVersionError: class file version 65.0 ... up to 61.0`) |
| B8 wrapper unchanged | PASS (Maven 3.9.11 retained) |
| B9 four locations aligned | PASS |

### Tests

| Check | Result |
| --- | --- |
| T1 full suite | PASS — 24/24 |
| T2 inventory vs baseline | PASS — identical 9 test sets and per-set counts |
| T3 `CakeControllerTest` | PASS (19 nested) |
| T4 `CakeDatabasePopulatorTest` | PASS (WireMock) |
| T5 `OpenApiTest` + `SwaggerUITest` | PASS |
| T6 Cucumber | PASS — 2 scenarios, 7 steps; HTML/timeline reports generated |
| T7 no new skips | PASS — no `src/test` changes |
| T8 stability | PASS — 3 consecutive green runs |
| T9 warnings | No new errors; pre-existing `new URL(String)` deprecation retained (out of scope) |

### Dependencies

| Check | Result |
| --- | --- |
| D1/D2 tree + list diff | PASS — only difference is `junit-platform-suite` 6.0.0 → 1.11.4 |
| D4 JUnit Platform alignment | PASS — uniform 1.11.4 |
| D5 Cucumber ↔ platform | PASS — Cucumber 7.20.1 engine runs on 1.11.4 |
| D6 Lombok 1.18.36 | PASS — compiles under JDK 21 |
| D7 Byte Buddy 1.15.11 / Mockito | PASS |
| D8 plugin compatibility | PASS — compiler, surefire, enforcer 3.5.0, boot plugin all run on JDK 21 |
| D11 effective POM diff | Only `java.version`, `maven.compiler.release`, Kotlin `jvmTarget`, enforcer range changed |

### Runtime

| Check | Result |
| --- | --- |
| Local start on Java 21 | PASS — Tomcat on 8081, "Started CakeServiceApplication" |
| Startup fetch (live URL) | PASS — "cake database populated with 20 cakes" (network reachable) |
| API contract | PASS — see matrix below |
| Docker build + run | PASS — container reports Java 21.0.12, app starts, smoke passes |
| Image digest | `cake-service@sha256:f163fab670e5b86c183c7dc3f7fba359400ebb12ee74d97c2049cea9de54a637` |

API smoke matrix (Java 21 runtime):

| Endpoint | Result |
| --- | --- |
| `GET /cakes` (auth / no auth / bad auth) | 200 / 401 / 401 |
| `GET /cakes/15` (auth) | 200 |
| `GET /cakes/9999999` (auth) | 404 |
| `POST /cakes` (auth / no auth) | 201 / 401 |
| `PUT /cakes/1` (auth) | 204 |
| `DELETE /cakes/1` (auth) | 204 |
| `GET /v3/api-docs` | 200 — `openapi=3.0.1`, `title=OpenAPI definition` |
| `GET /swagger-ui/index.html` | 200 |

### Security

| Check | Result |
| --- | --- |
| S2 no new components | PASS — no new dependencies; only an empty aggregator downgraded |
| S3 auth enforced | PASS — 401 on missing/bad credentials |
| S4 no new exposed surface | PASS — permitted paths unchanged; no actuator added |
| S5 no secret leakage | PASS — no credentials added; `.env` still ignored |
| S6 container hardening | Unchanged — no privileged mode, no secrets; base now pinned LTS |
| S7 remote-fetch trust | Unchanged — same HTTPS host; no TLS weakening |
| S1 vulnerability scan | **NOT RUN** — no scanner configured in the repo (see residual gaps) |

---

## 5. Evidence locations and reproduction

Raw evidence was generated locally under `validation/evidence/` (baseline on JDK 17, results on
JDK 21). That directory is **gitignored** and not part of the commit; the checks and their
outcomes are recorded inline in Section 4 above and in
`validation/validation-plan-service-a.md`.

To regenerate the evidence, run from the repository root with a JDK 17 and a JDK 21 selected via
`JAVA_HOME`:

```sh
# Baseline (JDK 17), before any change:
./mvnw -B -ntp clean verify
./mvnw -B -ntp dependency:tree -Dverbose
./mvnw -B -ntp dependency:list -DincludeScope=test
./mvnw -B -ntp help:effective-pom

# After the migration (JDK 21):
./mvnw -B -ntp clean verify
./mvnw -B -ntp dependency:list -DincludeScope=test
javap -verbose -cp target/classes io.cip.services.cake.CakeServiceApplication | grep 'major version'
unzip -p target/cake-service-0.0.1-SNAPSHOT.jar BOOT-INF/classes/io/cip/services/cake/CakeServiceApplication.class | xxd -l 8
docker build -t cake-service:java21 . && docker run --rm -d -p 8081:8081 cake-service:java21
```

Recorded evidence files:

- `validation/evidence/baseline-java17/` — toolchain, `build.log`, `dependency-tree.txt`,
  `dependency-list.txt`, `effective-pom.xml`, `surefire-reports/`.
- `validation/evidence/java21/` — toolchain, `build.log`, `verification.txt`, `stability.txt`,
  `dependency-list.txt`, `dependency-tree.txt`, `effective-pom.xml`, `api-smoke.txt`,
  `docker.txt`, `negative-jar-on-jdk17.log`, `enforcer-reject-jdk17.log`, `runtime.log`,
  `repeat-1.log`, `repeat-2.log`, `surefire-reports/`.

---

## 6. Residual gaps and assumptions (for human review)

1. **CI not executed here.** The CI workflow was updated to Java 21 but no GitHub Actions run
   occurred in this environment. Confirm the pipeline is green on the branch.
2. **Vulnerability scan not run (S1).** No scanner is configured. Mitigation: the dependency
   diff shows no new components — only `junit-platform-suite` downgraded to the BOM version.
   Run a scan before merge if required.
3. **Production database not validated.** Tests use in-memory H2 with `create-drop`; no
   production database behavior is covered.
4. **External service behavior.** Startup fetch succeeded against the live gist in this
   environment; production behavior beyond that URL is not covered, and tests use WireMock.
5. **Docker base tag is an assumption.** Chose pinned `eclipse-temurin:21.0.12_8-jdk-noble`
   (JDK, matching the previous JDK-based image and the local Temurin 21.0.12.1). The plan
   flags the exact tag and JDK-vs-JRE choice for maintainer confirmation.
6. **`actions/checkout@v3` / `actions/setup-java@v3` left unchanged** — updating them is out of
   scope (unrelated dependency modernization) per the plan.
7. **Committed fallback credentials** in `application.properties` remain a pre-existing issue,
   unchanged by this migration.

---

## 7. Scope compliance

- No changes under `src/main` or `src/test`.
- No tests weakened, deleted, skipped, or bypassed.
- No unrelated refactoring or dependency modernization.
- Public API behavior preserved (verified by tests on both runtimes and runtime smoke).
- Changes are uncommitted, awaiting human review before merge.
