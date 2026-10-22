# Balance

Balance is a double-entry bookkeeping app for small businesses, built with Rails 8, Hotwire (Turbo and Stimulus), Tailwind and Postgres.

## Style

Follow the code style in STYLE.md for every change:

@STYLE.md

Also:

- Keep code files free of comments. Explain the why in commit messages and pull request descriptions instead.
- Keep UI wording short and plain, use little colour, and don't add success notices.
- Before adding code, find a similar implementation in Balance and follow its shape.

## Commands

- `bin/dev` runs the app on port 3000.
- `bin/rails test` runs the unit, model and controller tests.
- `bin/rails test test/system` runs the system tests.
- `bin/rubocop` checks Ruby style.

## Code review

When reviewing a pull request, check every changed file against STYLE.md and the rules above, and report each violation with the STYLE.md section it breaks. Pay particular attention to:

- conditional returns and speculative guards;
- method order and visibility modifiers;
- RESTful resources instead of custom controller actions, and no services that only relay a call to a model;
- accounting changes going through `AccountingEngine` (pure validation, posting through the command builder, corrections by reversal);
- tests that assert accounts, debit and credit amounts and workspace for accounting behaviour.
