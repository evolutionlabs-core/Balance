# Balance

Balance is accounting software for individuals and businesses. It combines a
double-entry ledger with an AI assistant that prepares reviewable proposals.

These instructions are defaults with reasons, not law. When the code in front
of you disagrees, choose the safer path and flag the conflict. Never weaken an
accounting, authorization, or data-integrity invariant to make a change easier.
Attack your own diff before calling it done.

## Feature workflow

Default branch: `main`

Before implementing a feature:

1. Create a concise ticket in the [Balance project](https://github.com/orgs/orbit-corp/projects/2/views/1).
2. Give the ticket only `Problem`, `Outcome`, and `Steps` sections, written as short bullet points.
3. Add direct descendants of an existing feature as sub-issues.
4. Create and switch to a dedicated feature branch. Keep one feature per branch.

## Accounting is the boundary

`Accounting::Engine` validates accounting rules without persistence.
`Accounting::PostingService` is the transactional persistence boundary. Posted
journal entries and lines are immutable; corrections use explicit reversals.

Never bypass balancing, workspace ownership, proposal review, or posting. Money
is stored as integer minor units (`*_kobo`), never floating point.

## Workspaces own financial data

Accounts, journal entries, chats, and proposals belong to a workspace. Resolve
records through `current_workspace` instead of global lookups. Personal and
business workspaces use separate account catalogs; only personal onboarding is
currently available. The supported base currency is NGN.

## AI proposes, users decide

The assistant may interpret requests and prepare proposals, but deterministic
code validates and posts them. Never expose hidden reasoning, invent missing
financial facts, or claim that a transaction was recorded without a persisted
journal entry.

## Docker and deployment

Local Docker development runs on port `8080`; PostgreSQL is internal to the
Compose network. The production image is separate from the development image.
Read [DOCKER.md](DOCKER.md) before changing container or deployment behavior.

## Verification

Use Ruby 3.4.8. Run focused tests while developing, then the full suite for
cross-cutting changes. Report independently reproducible pre-existing failures
instead of hiding them. Read [STYLE.md](STYLE.md) before editing or reviewing
code.

## Validation

Add the minimum validation required for known application paths and domain
invariants. Do not add speculative guards, restrictions, or normalization.

## Controllers

Do not add custom attribute-assignment methods or domain/workspace validation
logic to controllers. Keep assignment direct and place invariants in the model
or an established domain boundary.
