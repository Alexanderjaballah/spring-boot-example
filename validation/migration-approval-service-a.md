# Migration Approval — Service A: Java 17 → Java 21

This document is the **human approval checkpoint** before autonomous execution of the
Java 17 → Java 21 migration for Service A.

Approval is granted to proceed. It does **not** authorize starting the migration in this
document's authoring step; execution begins only when explicitly triggered afterward.

---

## Decision record

| Field | Value |
| --- | --- |
| Change | Java 17 → Java 21 migration for the cake service |
| Scope owner | Service A |
| Governing spec | `specs/java17-to-java21.md` |
| Execution plan | `specs/migration-plan-service-a.md` |
| Validation plan | `validation/validation-plan-service-a.md` |
| **Risk classification** | **Medium** |
| **Decision** | **Approved for autonomous execution with human review before merge** |
| Execution mode | Autonomous, bounded by the constraints below |
| Merge authority | Human review required before merge |

**Risk rationale (Medium):** the migration changes the language/runtime baseline, the build
toolchain gate, CI, and the container runtime, and it carries a known JUnit Platform version
skew and a startup-time remote dependency. It is not a production data or irreversible
change, and the work is bounded by an existing spec, plan, and validation plan, with a
revertible source diff and a preserved Java 17 rollback path. That combination places it at
Medium rather than High or Low.

---

## Approval

The Java 17 → Java 21 migration is **approved to proceed as a medium-risk change**, subject
to the constraints in the next section.

Execution may begin autonomously. A human must review the resulting diff and evidence
package before merge.

---

## Constraints (binding)

The migration must satisfy all of the following. Any deviation is a scope breach and
triggers the stop condition below.

1. **Follow the spec.** `specs/java17-to-java21.md` governs the objective, acceptance
   criteria, and non-goals.
2. **Follow the execution plan.** `specs/migration-plan-service-a.md` is the execution plan
   for how the change is carried out.
3. **Validate against the validation plan.** `validation/validation-plan-service-a.md`
   defines the checks and the evidence required before completion.
4. **Keep the four Java-version locations aligned.** The Maven `java.version` property, the
   Maven Enforcer rule, CI (`.github/workflows/ci.yml`), and the `Dockerfile` must move to
   Java 21 together. No location may be left at 17.
5. **Resolve the JUnit Platform version skew.** Investigate the direct
   `junit-platform-suite:6.0.0` declaration against the Spring Boot-managed JUnit Platform
   components and resolve the incompatibility deliberately. Do not blindly upgrade around it.
6. **Do not weaken, delete, skip, or bypass existing tests.** All 24 existing tests must
   remain present and passing. No `@Disabled`, `@Ignore`, `assumeTrue`, exclusions, or
   quarantine may be introduced to make the build pass.
7. **No unrelated refactoring or dependency modernization.** The change stays limited to
   what the migration requires. No formatting churn, no opportunistic upgrades, no
   architecture changes.
8. **Preserve public API behavior.** Endpoint paths, methods, status codes, headers, JSON
   shape, field names, ordering, and null handling must be unchanged. OpenAPI/Swagger output
   is part of the contract.
9. **Treat the remote startup fetch as an explicit runtime risk.** The `ContextRefreshedEvent`
   fetch in `CakeDatabasePopulator` must be called out as a runtime risk, and any residual
   limitation (for example, validating against a stub instead of the live production URL)
   must be documented.
10. **Stop and request human input** if the migration requires work outside the agreed scope.

---

## Stop condition

Execution must halt and request human input if any of the following occur:

- The migration requires changes beyond the spec, execution plan, or these constraints.
- The JUnit Platform skew cannot be resolved within scope without a dependency change that
  exceeds "no unrelated dependency modernization".
- Any existing test fails, errors, or must be skipped to proceed.
- Public API behavior changes.
- A new critical/high security finding is attributable to the migration.
- The four Java-version locations cannot be kept aligned.

Halting is the correct outcome in these cases, not a workaround.

---

## Acknowledgement

- [ ] Approver confirms risk classification **Medium**.
- [ ] Approver confirms **Approved for autonomous execution with human review before merge**.
- [ ] Approver confirms the binding constraints above.
- [ ] Approver confirms no migration work starts until execution is explicitly triggered.

Approved by: ____________________  Date: __________

---

## References

- `specs/java17-to-java21.md` — governing spec.
- `specs/migration-plan-service-a.md` — execution plan.
- `validation/validation-plan-service-a.md` — validation plan and required evidence.
- `metrics/readiness-baseline.md`, `metrics/readiness-after-remediation.md` — readiness context.
- `AGENTS.md` — repository baseline and command conventions.
