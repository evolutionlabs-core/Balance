# Contributing to Balance

Balance is financial software. Every change must preserve accounting correctness, data integrity, workspace isolation, security boundaries, and an auditable review trail.

## Development environment

Balance uses Ruby 3.4.13, PostgreSQL, and the dependencies declared in the repository. The supported local setup uses Docker:

```sh
docker compose up --build
```

Open [http://localhost:8080](http://localhost:8080). AI features require the provider configuration described in [README.md](README.md).

Development and production-image validation are separate workflows. Use the default Compose configuration for development and the `prod` profile only to validate the production container.

## Change requirements

1. Create a focused branch with a descriptive name.
2. Reproduce and document the current behaviour before changing it.
3. Keep the implementation limited to the requested concern.
4. Add or update relevant automated coverage.
5. Verify the narrowest affected layer, then run broader checks when the change crosses boundaries.
6. Document migrations, configuration changes, security implications, and operational impact.

Do not weaken validation, bypass review workflows, hardcode model outputs, or alter unrelated code to make a check pass.

## Accounting invariants

The accounting engine performs pure validation, while `Accounting::PostingService` owns persistence. All accounting changes must preserve these guarantees:

- Total debits equal total credits.
- Amounts and account references are valid for the active workspace.
- Posted journal entries and lines are immutable.
- Corrections are recorded through explicit reversals.
- AI-generated accounts and journal entries remain proposals until approved.
- Posting occurs atomically only after engine validation succeeds.

Model-generated interpretation is not a substitute for deterministic accounting enforcement.

## Verification

Run focused checks during development:

```sh
bin/rails test test/lib/accounting/engine_test.rb
bin/rails test test/services/accounting/posting_service_test.rb
bin/rubocop
bin/brakeman --no-pager
```

Run the full suite for changes spanning multiple layers or before requesting review:

```sh
bin/rails test
```

Do not conceal or work around failures. Resolve failures introduced by the change and report any independently reproducible pre-existing failure.

## Live agent benchmark

The benchmark exercises the production application flow against the accounting transaction corpus and makes live model calls. Ensure the configured model provider is available, then run:

```sh
bin/harness-benchmark
```

Optional settings include `HARNESS_EVAL_MODEL`, `HARNESS_EVAL_BASE_URL`, and `HARNESS_EVAL_RUNS`. Reports, case results, and transcripts are written to `tmp/benchmark/harness/` and must be reviewed before claiming an accuracy result.

Never modify the corpus, scoring rules, or expected outcomes merely to improve a benchmark score.

## Pull request standard

Every pull request must include:

- The problem and its operational or user impact.
- The implemented behaviour and key design decisions.
- Verification commands and their results.
- Database, configuration, security, compatibility, and deployment implications.
- Screenshots or recordings for material interface changes.
- Known limitations and follow-up work, where applicable.

Pull requests must not contain environment files, credentials, production data, generated secrets, or unrelated changes.

## Security and responsible disclosure

Do not disclose suspected vulnerabilities in public issues. Report security concerns privately to the project maintainers with reproduction steps, affected versions, and impact where known.

## Issues

Use [GitHub issues](https://github.com/orbit-corp/Balance/issues) for reproducible defects and scoped feature proposals. Include the affected revision, environment, reproduction steps, expected behaviour, actual behaviour, and relevant logs with sensitive information removed.
