# Style

We write code that is direct, readable, and easy to review. Financial software
benefits more from obvious control flow and explicit boundaries than clever
abstractions. When adding code, first find a similar implementation in Balance
and follow its shape.

## Conditional returns

Prefer expanded conditionals when both outcomes matter. Guard clauses are
appropriate at the start of a method when they leave the main path easy to
follow.

```ruby
# Avoid
return [] unless account_ids
workspace.accounts.find(account_ids)

# Prefer
if account_ids
  workspace.accounts.find(account_ids)
else
  []
end
```

Do not add speculative fallbacks or guards for states the known application
path cannot produce.

## Method order

Order methods as:

1. Class methods
2. Public methods, with `initialize` first
3. Private methods

Within each section, place methods in invocation order so the file reads from
the entry point down through its implementation.

## Bang methods

Use `!` when a non-bang counterpart exists and the distinction is meaningful.
Do not use `!` merely to label a method as destructive. Rails persistence APIs
retain their conventional names.

## Visibility modifiers

Do not add a blank line below a visibility modifier. Indent methods beneath it.

```ruby
class Workspace
  def ready?
    accounts.any?
  end

  private
    def core_accounts
      accounts.where.not(role: nil)
    end
end
```

## Rails resources

Model web endpoints as RESTful resources. When behavior does not fit a standard
CRUD action, introduce a resource instead of adding an action verb.

Keep controllers focused on HTTP concerns. Prefer direct Active Record calls
or intention-revealing domain methods. Services are justified at established
boundaries such as accounting posting and LLM orchestration; do not introduce a
service merely to relay a controller call to a model.

## Accounting code

Keep validation pure and persistence transactional. Never mix database writes
into `Accounting::Engine`. Construct entries explicitly, validate them through
the engine, and persist them through `Accounting::PostingService`.

A balanced entry may still be semantically
wrong, so preserve account taxonomy and workspace checks.

## Asynchronous work

Jobs should be shallow and delegate domain behavior. Use `_later` for methods
that enqueue work and `_now` for their synchronous counterpart when both exist.

## Tests

Test behavior at the narrowest useful boundary. Accounting tests must assert
the accounts, debit and credit amounts, workspace, persistence result, and
immutability or reversal behavior where relevant.

Use `bin/rubocop` for automated Ruby style. Formatting must not be used to hide
unrelated behavioral changes.
