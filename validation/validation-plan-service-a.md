# Validation Plan — Service A: Java 17 → Java 21 Migration

This plan defines how to **prove** the migration in `specs/java17-to-java21.md` is correct.
It is derived independently from that spec and from direct inspection of this repository.
It does **not** use `specs/migration-plan-service-a.md` as a source.

The plan describes checks only. It does not modify production code and does not perform the migration.

---

## 0. Verified current state (pre-migration baseline facts)

These facts were observed directly in the working tree and build output at the time of writing.

| Area | Observed state | Source |
| --- | --- | --- |
| Java source/target | `java.version=17`, `maven.compiler.release=${java.version}` | `pom.xml:20-21` |
| Compiled bytecode | Class file major version `61` (Java 17) | `target/classes/.../Cake.class` |
| Enforcer rule | `<requireJavaVersion>[17,18)</requireJavaVersion>`, Maven `[3.9.11,3.10.0)` | `pom.xml:145-160` |
| Maven | Wrapper pins Maven `3.9.11` (`distributionType=only-script`) | `.mvn/wrapper/maven-wrapper.properties` |
| CI | `actions/setup-java@v3`, `java-version: '17'`, temurin | `.github/workflows/ci.yml` |
| Docker runtime | `eclipse-temurin:17.0.5_8-jdk-focal`, runs packaged jar, exposes 8081 | `Dockerfile` |
| Test inventory | 24 tests across 9 test sets (see Appendix A) | `target/surefire-reports/*.txt` |
| JUnit skew | Direct `junit-platform-suite:6.0.0`; Spring Boot 3.4.x manages JUnit Platform `1.11.4` | `pom.xml:31,120-126`; SB 3.4.4 managed coordinates |
| Test infra | H2 in-memory (`create-drop`), WireMock on random port | `application.properties`, `application-test.properties`, `CakeServiceSpringTest.java` |
| Startup dependency | `ContextRefreshedEvent` fetch of remote gist URL; no local production substitute | `CakeDatabasePopulator.java:27-33`, `application.properties` |
| Security posture | Basic auth only; committed fallback credentials in `application.properties`; no vulnerability/coverage tooling configured | repo inspection |
| Local toolchain | **No JDK is installed in this environment** (`java`/`mvnw -v` both fail) | shell check |

Two implications follow immediately:

1. A clean Java 17 baseline and a Java 21 validation run both require provisioning JDKs first (Section 1).
2. The checked-in `target/` reports are a useful reference but are **not** an authoritative baseline; the baseline must be re-captured from a clean build on a pinned JDK 17.

---

## 1. Preconditions and baseline capture (must happen before any migration change)

Capture a Java 17 golden baseline so post-migration results can be diffed, not eyeballed.

1. Provision two JDKs and select them explicitly per command (never rely on ambient `JAVA_HOME`):
   - JDK 17 (baseline, e.g. Temurin 17.0.x LTS)
   - JDK 21 (target, e.g. Temurin 21.0.x LTS)
2. On **JDK 17**, run and archive:
   ```sh
   mkdir -p validation/evidence/baseline-java17
   ./mvnw -B -ntp clean verify | tee validation/evidence/baseline-java17/build.log
   ./mvnw -B -ntp dependency:tree -Dverbose   > validation/evidence/baseline-java17/dependency-tree.txt
   ./mvnw -B -ntp help:effective-pom           > validation/evidence/baseline-java17/effective-pom.xml
   ./mvnw -B -ntp dependency:list -DincludeScope=test > validation/evidence/baseline-java17/dependency-list.txt
   cp -r target/surefire-reports validation/evidence/baseline-java17/
   ```
3. Capture API golden outputs from a JDK 17 run (Section 5) and archive them.
4. Record the exact JDK build and Maven version used:
   ```sh
   java -version 2>&1 | tee validation/evidence/baseline-java17/toolchain.txt
   ./mvnw -v     2>&1 | tee -a validation/evidence/baseline-java17/toolchain.txt
   ```
5. Record the current git commit (`git rev-parse HEAD`) as the baseline revision.

**Gate:** baseline build is green and all 24 tests pass before the migration branch is evaluated.

---

## 2. Build checks

Goal: prove the project compiles, enforces the right toolchain, and produces Java 21 bytecode.

| # | Check | Command | Pass criterion |
| --- | --- | --- | --- |
| B1 | Toolchain is Java 21 + Maven 3.9.11 | `./mvnw -v` | Reports Maven `3.9.11` and a `21.0.x` JDK |
| B2 | Enforcer accepts Java 21 and rejects others | `./mvnw -B -ntp validate` | `requireJavaVersion` passes under 21; fails under 17/22 with a clear message |
| B3 | Clean deterministic build | `./mvnw -B -ntp clean verify` | `BUILD SUCCESS` |
| B4 | Bytecode targets 21 | `javap -verbose -cp target/classes io.cip.services.cake.CakeServiceApplication \| grep 'major version'` | `major version: 65` |
| B5 | Packaged jar classes target 21 | `unzip -p target/cake-service-0.0.1-SNAPSHOT.jar BOOT-INF/classes/io/cip/services/cake/CakeServiceApplication.class \| xxd -l 8` | Bytes end `00 41` (major 65) |
| B6 | Artifact genuinely requires 21 (negative test) | Run the jar under JDK 17: `$JAVA17/bin/java -jar target/cake-service-0.0.1-SNAPSHOT.jar` | Fails fast with `UnsupportedClassVersionError` (proves it is not a 17 artifact) |
| B7 | Build is reproducible enough to diff | Run `clean verify` twice; compare `dependency:list` output | Identical dependency sets |
| B8 | Wrapper unchanged / still valid | `git diff -- .mvn mvnw mvnw.cmd` | No changes (Maven 3.9.11 already satisfies the enforcer range) |
| B9 | The four Java-version locations move together | `git diff -- pom.xml .github/workflows/ci.yml Dockerfile AGENTS.md README.md` | `java.version`, enforcer range, CI JDK, Docker base all become 21; no location left at 17 |

**Note on B2:** the enforcer range must be deliberately widened (for example `[21,22)` or `[21,)`). If the range is left at `[17,18)`, B3 fails under JDK 21 — that failure is the correct signal, not a reason to relax the build.

**Note on B6:** the expected failure is evidence of correctness. A Java 21-compiled artifact must not run on a Java 17 runtime, which is exactly why the Docker image must move in lockstep.

---

## 3. Unit and integration test checks

Goal: prove behavior is unchanged and every existing test still passes.

| # | Check | Command | Pass criterion |
| --- | --- | --- | --- |
| T1 | Full suite passes | `./mvnw -B -ntp clean verify` | 24 tests, 0 failures, 0 errors, 0 skipped |
| T2 | Test set inventory unchanged | Compare `target/surefire-reports/*.txt` against baseline | Same 9 test sets, same per-set counts (Appendix A) |
| T3 | Controller contract tests | `./mvnw -B -ntp -Dtest=CakeControllerTest test` | All 19 nested tests pass |
| T4 | Startup-populator integration test | `./mvnw -B -ntp -Dtest=CakeDatabasePopulatorTest test` | Passes via WireMock stub; no real network call |
| T5 | OpenAPI + Swagger tests | `./mvnw -B -ntp -Dtest=OpenApiTest,SwaggerUITest test` | `/v3/api-docs` returns `openapi=3.0.1`, `info.title=OpenAPI definition`; Swagger UI title present |
| T6 | Cucumber scenarios | `./mvnw -B -ntp -Dtest=RunCucumberTest test` | 2 scenarios pass; `target/reports/cucumber.html` and `target/reports/timeline/` produced |
| T7 | No new test skips/quarantines | `grep -R "@Disabled\|@Ignore\|assumeTrue" src/test` | No additions versus baseline |
| T8 | Flakiness check | Run `clean verify` at least 3 times | Identical results each run |
| T9 | Deprecation review | Inspect compiler output for new `deprecation`/`removal` warnings | No new **errors**; any new warnings triaged and recorded (expected: pre-existing `new URL(String)` deprecation in `CakeDatabasePopulator`) |

**Watch item (T1/T2/T6):** the direct `junit-platform-suite:6.0.0` declaration can resolve against Spring Boot-managed platform components at `1.11.4`. The suite aggregator artifact carries no engine classes itself, which is the likely reason the current build passes, but the mixed versions must be confirmed via the dependency checks in Section 4 before treating T1/T6 as trustworthy.

**Test isolation watch item:** several test classes share the in-memory database name `jdbc:h2:mem:cake-service` (`application.properties`) with `ddl-auto=create-drop`, and `CakeControllerTest` mutates shared state. Confirm the same ordering assumptions hold under JDK 21; a passing multi-run (T8) is the evidence.

---

## 4. Dependency and plugin compatibility checks

Goal: prove every build plugin and runtime dependency actually supports Java 21, and that the migration introduces no version drift.

| # | Check | Command | Pass criterion |
| --- | --- | --- | --- |
| D1 | Full resolved tree captured | `./mvnw -B -ntp dependency:tree -Dverbose > .../dependency-tree-java21.txt` | Command succeeds |
| D2 | Tree diff vs baseline | `diff baseline/dependency-tree.txt java21/dependency-tree.txt` | Differences limited to Java-related/plugin entries; no unexplained upgrades |
| D3 | Version convergence | Inspect `-Dverbose` output for `omitted for conflict`/multiple versions; optionally run enforcer `dependencyConvergence` via a temporary uncommitted profile | No conflicting versions of the same artifact |
| D4 | JUnit Platform alignment (highest-risk item) | `./mvnw -B -ntp dependency:tree -Dincludes=org.junit.platform,org.junit.jupiter` | Explicitly confirm resolved versions of `junit-platform-suite`, `-suite-api`, `-suite-engine`, `-engine`, `-commons`, `-launcher`; document any 6.0.0 vs 1.11.4 skew and its effect |
| D5 | Cucumber ↔ JUnit Platform | `./mvnw -B -ntp dependency:tree -Dincludes=io.cucumber` | Cucumber 7.20.1 resolves against a compatible platform engine; no duplicate engines |
| D6 | Lombok supports JDK 21 | `./mvnw -B -ntp clean compile` with annotations enabled | Compiles with no annotation-processing failure; Lombok resolves to a JDK-21-capable release (1.18.30+) |
| D7 | Byte Buddy / Mockito support JDK 21 | `./mvnw -B -ntp -Dtest=CakeControllerTest test` | No `Unsupported class file major version` / instrumentation errors |
| D8 | Plugin compatibility | `./mvnw -B -ntp help:effective-pom`; review `maven-compiler-plugin`, `maven-surefire-plugin`, `maven-enforcer-plugin`, `spring-boot-maven-plugin` | All run under JDK 21; no plugin pinned to a Java-17-only release |
| D9 | Explicit overrides still valid | Review `springdoc-openapi-starter-webmvc-ui 2.7.0`, `hibernate-validator 8.0.2.Final`, `assertj-core 3.27.3`, `cucumber 7.20.1`, `junit-platform-suite 6.0.0` | Each is Java-21-capable; if not, a deliberate, documented version change is required (out of the "no dependency modernization" scope unless strictly necessary) |
| D10 | Unused/undeclared dependencies | `./mvnw -B -ntp dependency:analyze` | No new undeclared/used-transitive dependencies introduced by the migration |
| D11 | Effective POM diff | `diff baseline/effective-pom.xml java21/effective-pom.xml` | Changes limited to Java version, enforcer range, and any documented necessity |
| D12 | No test-scope leakage into runtime | `./mvnw -B -ntp dependency:list -DincludeScope=runtime` | Runtime classpath unchanged except for Java-version-driven entries |

**Expected compatibility (must still be verified, not assumed):** Spring Boot 3.4.x / Spring Framework 6.2.x, Spring Security 6.4.x, Hibernate, H2 2.3.232, Lombok 1.18.36, Byte Buddy 1.15.11, and Maven 3.9.11 are all JDK-21-capable. The genuinely uncertain item is the JUnit Platform version skew (D4); treat it as the primary dependency risk.

---

## 5. Runtime verification and API contract regression

Goal: prove the service starts and behaves identically on a Java 21 runtime, including the packaged artifact and the Docker image.

### 5.1 Local runtime

1. Build with JDK 21, then start with an explicit Java 21 binary:
   ```sh
   set -a; source .env; set +a
   $JAVA21/bin/java -jar target/cake-service-0.0.1-SNAPSHOT.jar
   ```
2. Confirm startup evidence in the log:
   - Tomcat starts on port `8081`.
   - `populating cake database from <url>` and `cake database populated with N cakes` appear.
   - No `UnsupportedClassVersionError`, no bean-creation failure, no new stack traces.
3. Because startup performs a live fetch of the configured gist URL, validation must declare its network mode:
   - **Network allowed:** use the production URL and confirm N cakes populate.
   - **Network restricted/airgapped:** override `cakes.populator.url` to a local stub (WireMock or a static file server) and record that production startup was *not* exercised — this is a residual, explicitly documented gap.

### 5.2 API contract comparison (golden diff)

For each endpoint, capture status, `Content-Type`, and body under JDK 17 (baseline) and JDK 21, normalizing generated IDs and timestamps, then diff:

| Endpoint | Auth case | Expected |
| --- | --- | --- |
| `GET /cakes` | valid / missing / wrong | 200 JSON ordered by title / 401 empty / 401 empty |
| `GET /cakes/{id}` | valid / unknown id / missing | 200 JSON / 404 empty / 401 empty |
| `POST /cakes` | valid / missing | 201 JSON with id / 401 empty |
| `PUT /cakes/{id}` | valid / unknown id | 204 empty / 404 empty |
| `DELETE /cakes/{id}` | valid / unknown id | 204 empty / 404 empty |
| `GET /v3/api-docs` | none | 200, `openapi=3.0.1`, `info.title=OpenAPI definition` |
| `GET /swagger-ui/index.html` | none | 200 containing `<title>Swagger UI</title>` |

Example smoke commands:
```sh
curl -s -o /dev/null -w '%{http_code}\n' -u "$U:$P" localhost:8081/cakes
curl -s -o /dev/null -w '%{http_code}\n' localhost:8081/cakes            # expect 401
curl -s localhost:8081/v3/api-docs | sha256sum                          # compare to baseline hash
```

**Pass criterion:** identical status codes and equivalent JSON (structure, field names, ordering, null handling). Any difference is a public API regression and blocks completion.

### 5.3 Docker runtime

```sh
docker build -t cake-service:java21 .
docker run --rm -d --name cake-java21 -p 8081:8081 \
  -e CAKES_AUTHENTICATION_USERNAME="$U" -e CAKES_AUTHENTICATION_PASSWORD="$P" \
  cake-service:java21
docker exec cake-java21 java -version        # must report 21.0.x
# rerun the Section 5.2 smoke matrix against the container
docker stop cake-java21
```

Pass criteria:
- Base image is a **pinned, supported Java 21 LTS** tag (replace `eclipse-temurin:17.0.5_8-jdk-focal`), not a floating tag.
- Container reports Java 21 and starts the packaged jar successfully.
- Smoke matrix passes from outside the container.
- Image digest recorded as evidence; base image change does not alter locale/timezone/CA trust in a way that breaks the startup fetch.

### 5.4 CI runtime

- CI uses Java 21 (`actions/setup-java`), runs `./mvnw -B -ntp clean verify`, and builds the image.
- The pipeline is green on the migration branch, with logs/artifacts archived as evidence.
- Confirm CI does not silently still use JDK 17 (check the `Set up JDK` step and the `mvn -v` line in the log).

---

## 6. Security checks

Goal: satisfy "no new critical security findings" and confirm security behavior is unchanged.

| # | Check | How | Pass criterion |
| --- | --- | --- | --- |
| S1 | Vulnerability scan, before vs after | Run a pinned scanner on the baseline and post-migration dependency sets (e.g. OWASP Dependency-Check or `trivy fs`/`osv-scanner` on `pom.xml` + lockfile) | No new critical/high findings attributable to the migration; report archived |
| S2 | No new components | Section 4 D2/D12 diffs | No new dependencies beyond Java-version-driven changes |
| S3 | Auth still enforced | 401 tests plus manual curls (5.2) | Unauthenticated and wrong-credential requests rejected on all endpoints |
| S4 | No new exposed surface | Compare `/v3/api-docs` and app config | No actuator/health/debug endpoints added; permitted paths unchanged (`/v3/api-docs*`, `/swagger-ui*`) |
| S5 | No secret leakage in the change | `git diff` review + `git status` | `.env` still ignored; no credentials, tokens, or keys added; committed fallback credentials unchanged (pre-existing issue, must not worsen) |
| S6 | Container hardening not weakened | Inspect `Dockerfile` | No new privileged mode, no `latest` base, no embedded secrets; note the pre-existing root-user default as a known gap |
| S7 | Remote-fetch trust unchanged | Review `cakes.populator.url` and TLS behavior | Still HTTPS to the same host; no trust-all, no disabled certificate validation introduced |
| S8 | Dependency integrity | Maven checksum/verification (`-C` or wrapper verification) | Artifacts resolve with valid checksums |

**Residual risk to state explicitly:** no vulnerability scanner, formatter, linter, or coverage threshold is configured today, so S1 depends on tooling introduced *for validation only* and must be reported as a temporary measure, not a permanent control.

---

## 7. Regression risk register

| Risk | Why it matters here | Detection | Mitigation |
| --- | --- | --- | --- |
| R1. Artifact/runtime mismatch | Java 21 bytecode (major 65) cannot run on the Java 17 Docker base | B6, 5.3 | Move `java.version`, enforcer, CI, and Docker base together (B9) |
| R2. Enforcer range left at 17 | Build fails under JDK 21 | B2, B3 | Deliberately widen the range as part of the migration |
| R3. JUnit Platform version skew | `junit-platform-suite:6.0.0` alongside managed `1.11.4` can produce mixed engines | D3, D4, T1, T6 | Verify resolved versions; align suite with the Spring Boot-managed platform if skew is real |
| R4. Cucumber engine incompatibility | Cucumber 7.20.1 must run on the resolved platform | D5, T6 | Pin/document a compatible combination |
| R5. Annotation processing / instrumentation | Lombok and Byte Buddy must understand JDK 21 class files | D6, D7 | Keep JDK-21-capable releases; do not bump versions unnecessarily |
| R6. API contract drift | OpenAPI/Swagger assertions and JSON shape are contract | T5, 5.2 | Golden-diff before/after; freeze dependency versions |
| R7. Startup remote fetch | Production start fails if the gist is unreachable; no local substitute | 5.1 | Declare network mode; use stub only when network is unavailable, and record the gap |
| R8. Test flakiness / shared H2 state | Shared in-memory DB and mutating tests can reorder | T8 | Repeated runs; investigate any nondeterminism |
| R9. Dependency drift | Dependabot may pull Java-incompatible versions | D2, D8, D9 | Review Dependabot PRs against Java 21; freeze during migration |
| R10. Docker base change side effects | New base image may change locale, CA certs, timezone | 5.3 | Pin tag/digest; re-run runtime and TLS checks |
| R11. Silent scope creep | Non-goals forbid refactors/formatting/dependency modernization | Source-diff review (Section 8) | Keep diff minimal; reject unrelated changes |

---

## 8. Evidence required before the migration is considered complete

All of the following must exist and be reviewed. Missing evidence means "not complete", regardless of a green build.

**Build**
- [ ] `./mvnw -v` output showing Maven 3.9.11 and JDK 21.0.x.
- [ ] Full `clean verify` log with `BUILD SUCCESS` under JDK 21.
- [ ] Enforcer output proving the Java range now accepts 21 (and rejects 17).
- [ ] Bytecode evidence: major version 65 for `target/classes` and the packaged jar (B4/B5).
- [ ] Negative test: the Java 21 jar fails under JDK 17 with `UnsupportedClassVersionError` (B6).

**Tests**
- [ ] Complete surefire results: 24 tests, 0 failures/errors/skips, matching the baseline inventory (Appendix A).
- [ ] Cucumber HTML/timeline artifacts from the JDK 21 run.
- [ ] Repeated-run results demonstrating stability (T8).
- [ ] Compiler warning triage (T9).

**Dependencies and configuration**
- [ ] `dependency:tree -Dverbose`, `dependency:list`, and `help:effective-pom` for both baseline and Java 21, with a diff.
- [ ] Explicit resolved-version evidence for all `org.junit.platform` and `io.cucumber` artifacts (D4/D5), plus a statement on any version skew.
- [ ] Plugin version list for both runs (D8).

**Source diff**
- [ ] `git diff` limited to the expected migration files (`pom.xml`, `.github/workflows/ci.yml`, `Dockerfile`, `README.md`, `AGENTS.md`); **zero changes under `src/main` and `src/test`** unless strictly required and independently justified.
- [ ] No formatting-only churn, no unrelated dependency modernization.

**Runtime**
- [ ] JDK 21 local startup log showing port 8081 and populator messages.
- [ ] Golden API diff for every endpoint (status, headers, body) versus the JDK 17 baseline.
- [ ] Docker image build log, recorded image digest, `java -version` inside the container = 21, and the smoke matrix passing against the container.
- [ ] CI run on the migration branch: green, with Java 21 confirmed in logs, artifacts/links archived.

**Security**
- [ ] Vulnerability scan report for baseline and post-migration, showing no new critical/high findings (S1).
- [ ] Auth and exposed-surface verification (S3/S4).
- [ ] Secret/diff review confirming no credentials added and `.env` still ignored (S5).

**Process**
- [ ] Independent review of the migration diff and this evidence package, with sign-off.
- [ ] Documented residual gaps: production-database behavior (H2 only), production external-service behavior (WireMock only), and any network-restricted startup validation.
- [ ] Rollback plan: revert the migration commit(s); the prior Java 17 artifact/image remains deployable and the four version locations revert together.

---

## 9. Abort / stop conditions

Stop and treat the migration as failed if any of the following occur:

- Any existing test fails, errors, or is skipped without written justification.
- Any public API response changes versus the golden baseline.
- The resolved dependency graph contains conflicting or incompatible versions that cannot be reconciled without a scope-expanding dependency change.
- The Docker container does not run the Java 21 artifact, or the image is not pinned/supported.
- A new critical/high security finding is attributable to the migration.
- The source diff contains unrelated refactoring, formatting, or dependency modernization.

---

## Appendix A — Baseline test inventory (Java 17)

| Test set | Tests |
| --- | ---: |
| `io.cip.services.cake.OpenApiTest` | 1 |
| `io.cip.services.cake.SwaggerUITest` | 1 |
| `io.cip.services.cake.controller.CakeControllerTest$GetCakes` | 4 |
| `io.cip.services.cake.controller.CakeControllerTest$GetCakeById` | 4 |
| `io.cip.services.cake.controller.CakeControllerTest$CreateCake` | 3 |
| `io.cip.services.cake.controller.CakeControllerTest$UpdateCake` | 4 |
| `io.cip.services.cake.controller.CakeControllerTest$DeleteCake` | 4 |
| `io.cip.services.cake.populator.CakeDatabasePopulatorTest` | 1 |
| `io.cip.services.cake.cucumber.RunCucumberTest` (2 Cucumber scenarios) | 2 |
| **Total** | **24** |

## Appendix B — Relevant source references

- Build and toolchain: `pom.xml:20-31`, `pom.xml:141-165`; `.mvn/wrapper/maven-wrapper.properties`; `AGENTS.md`.
- CI: `.github/workflows/ci.yml`.
- Runtime image: `Dockerfile`.
- Startup dependency: `src/main/java/io/cip/services/cake/populator/CakeDatabasePopulator.java:27-33`; `src/main/resources/application.properties`.
- Security: `src/main/java/io/cip/services/cake/config/SecurityConfig.java`; `src/main/java/io/cip/services/cake/CakeServiceApplication.java:20-22`.
- Test entry points: `src/test/java/io/cip/services/cake/CakeServiceSpringTest.java`; `.../controller/CakeControllerTest.java`; `.../populator/CakeDatabasePopulatorTest.java`; `.../cucumber/RunCucumberTest.java`; `src/test/resources/application-test.properties`.
