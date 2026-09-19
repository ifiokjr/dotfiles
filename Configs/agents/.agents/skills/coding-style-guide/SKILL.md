---
name: "coding-style-guide"
description: "Use when writing, editing, or reviewing code in Dart, TypeScript, Rust, or Python. A code aesthetics and layout guide for how code looks - whitespace, comment placement, early returns, flat structure, and readability."
---

# @ifi/coding-style-guide

This skill defines a code aesthetics and layout guide focused on how code looks rather than what it does. It covers whitespace placement, comment positioning, code simplification patterns, and visual organization to maximize readability.

> Note: This guide does not dictate which functions, methods, or language features to use. Those decisions belong to other skills (e.g., a Rust patterns skill or a Flutter architecture skill). This skill is purely about the _visual presentation_ of code.

## Philosophy

Simple code is better than complex code.

This is a general truth. Wherever possible, choose the simpler, neater solution, unless it hinders performance or security. Code is read far more often than it is written, so optimize for the reader.

This style guide prioritizes:

1. Visual breathing room: code needs space to be understood.
2. Early clarity: state what's happening upfront, and exit early from bad states.
3. Flat over deep: indentation is a code smell, so prefer early returns.
4. Explanation of exceptions: when you must add complexity for security or performance, explain why.

## Core principles

### Simplicity first

```
Given two implementations that achieve the same goal,
choose the one that:
- Has fewer lines
- Has less nesting
- Requires less mental effort to follow
- Is easier to explain in words

Exception: When security or performance requires complexity
```

When you must introduce complexity for security or performance reasons, always add a comment explaining why:

```rust
// Security: We must validate the signature before parsing
// to prevent malformed input from causing panic or undefined behavior
if !is_valid_signature(input) {
    return Err(Error::InvalidSignature);
}
```

```typescript
// Performance: Using a Map instead of an array for O(1) lookups
// This matters because this function is called thousands of times per second
const lookupMap = new Map(items.map((i) => [i.id, i]));
```

### Whitespace is semantics

Blank lines are not decoration. They separate concepts and give the reader time to breathe.

Where to place blank lines:

1. Before control flow statements: add blank lines before `if`, `match`, `for`, `while`, `switch`, etc.
2. Between sequential control flow statements: sequential `if` statements, `for` loops, `match`/`switch` statements, etc. should each have a blank line before them. Code should never feel cramped or hurried.
3. Between logical groups: group related operations, then separate groups with blank lines.
4. After complex declarations: long variable declarations deserve breathing room.
5. Before return statements: unless it's the very next line after a short operation.

```rust
// ❌ Avoid: Cramped sequential control flow - code feels hurried
fn validate_input(input: &Input) -> Result<(), Error> {
    if input.is_empty() {
        return Err(Error::Empty);
    }
    if !input.is_valid_format() {
        return Err(Error::InvalidFormat);
    }
    if input.len() > MAX_LENGTH {
        return Err(Error::TooLong);
    }
    if contains_forbidden_chars(input) {
        return Err(Error::ForbiddenChars);
    }
    Ok(())
}

// ✅ Prefer: Sequential if statements each get their own space
fn validate_input(input: &Input) -> Result<(), Error> {
    if input.is_empty() {
        return Err(Error::Empty);
    }

    if !input.is_valid_format() {
        return Err(Error::InvalidFormat);
    }

    if input.len() > MAX_LENGTH {
        return Err(Error::TooLong);
    }

    if contains_forbidden_chars(input) {
        return Err(Error::ForbiddenChars);
    }

    Ok(())
}
```

### Variables at the top

Declare variables and constants at the start of functions or at the top of files when possible. This establishes the "state" for what's about to happen.

```rust
// Good: State is established upfront
fn configure_server(config: &Config) -> Server {
    // Configuration extraction
    let port = config.port;
    let timeout = config.timeout_secs;
    let max_connections = config.max_connections;

    // Security settings
    let require_tls = config.environment == Environment::Production;

    // Build and return
    Server::builder()
        .port(port)
        .timeout(timeout)
        .max_connections(max_connections)
        .tls(require_tls)
        .build()
}
```

Exception: when a variable's value depends on a prior computation, declare it near where it's computed.

### Early returns over deep nesting

Indentation is an orange flag. Treat deeply nested code as a code smell.

The rule: if you find yourself more than 2-3 levels deep, refactor.

The strategy: guard clauses and early returns

```rust
// ❌ Avoid: Deep nesting
fn handle_request(req: Request) -> Response {
    if let Some(user) = req.user {
        if user.is_active {
            if user.has_permission("read") {
                if let Some(data) = fetch_data() {
                    Response::ok(data)
                } else {
                    Response::not_found()
                }
            } else {
                Response::forbidden()
            }
        } else {
            Response::unauthorized()
        }
    } else {
        Response::unauthorized()
    }
}

// ✅ Prefer: Early returns with blank lines between sequential if statements
fn handle_request(req: Request) -> Response {
    let user = req.user.ok_or_else(|| Response::unauthorized())?;

    if !user.is_active {
        return Response::unauthorized();
    }

    if !user.has_permission("read") {
        return Response::forbidden();
    }

    let data = fetch_data().ok_or_else(|| Response::not_found())?;

    Response::ok(data)
}
```

### Extraction over nesting

When you can't avoid complex logic, extract it into smaller functions.

```rust
// ❌ Avoid: Complex nested logic
fn process_data(data: Data) -> Result {
    if let Some(items) = data.items {
        for item in items {
            if item.is_active {
                if let Some(value) = item.value {
                    if value > threshold {
                        // 20 lines of complex processing...
                    }
                }
            }
        }
    }
}

// ✅ Prefer: Extract into focused functions
fn process_data(data: Data) -> Result {
    let active_items = data.active_items()?;

    for item in active_items {
        if let Some(value) = item.significant_value(threshold) {
            process_significant_item(item, value)?;
        }
    }

    Ok(())
}

fn process_significant_item(item: &Item, value: Value) -> Result {
    // 20 lines of focused processing...
}
```

### Comments explain why, not what

Comments should explain why code exists, not what it does (the code itself should be clear).

Exception: when security or performance requires non-obvious code, explain both what and why:

```rust
// Security: Constant-time comparison to prevent timing attacks
// We compare every byte regardless of mismatches to ensure
// the operation takes the same time regardless of where the
// first difference occurs
if !constant_time_eq(provided_hash, stored_hash) {
    return Err(Error::InvalidCredentials);
}
```

```typescript
// Performance: Pre-allocate array to avoid reallocations
// This reduces GC pressure when processing large datasets
const results = new Array(estimatedSize);
```

### Documentation blocks

Every function, class, and module should have a documentation block explaining:

- Purpose: what does this do?
- Why: why does this exist? What problem does it solve?

Use language-native documentation reuse mechanisms (like Dart macros or Rust doc macros) to keep explanations consistent.

```rust
/// Validates a user session.
///
/// # Why This Exists
/// Session validation is required before any privileged operation
/// to ensure the user is authenticated and their session hasn't expired.
///
/// # Security Considerations
/// - This check must happen before any data access
/// - Session tokens are validated cryptographically
/// - Expired sessions are logged for security monitoring
fn validate_session(token: &str) -> Result<Session, Error> {
    // ...
}
```

## Language-specific visual guides

These guides focus on the aesthetic and layout patterns for each language:

- [Rust style guide](./languages/RUST.md): whitespace patterns, early returns, documentation.
- [TypeScript style guide](./languages/TYPESCRIPT.md): whitespace patterns, early returns, documentation.
- [Python style guide](./languages/PYTHON.md): whitespace patterns, early returns, documentation.
- [Dart style guide](./languages/DART.md): whitespace patterns, early returns, documentation.

## Integration with formatters

This style guide complements automated formatters rather than replacing them:

- Always use: `rustfmt`, `prettier`, `black`, `dartfmt`, etc.
- This guide covers: blank line placement, grouping, early return patterns, comment positioning.
- Formatters cover: indentation, trailing commas, spacing around operators, line length.

Never fight the formatter on mechanical details. This guide addresses aesthetic choices that formatters don't make.

### Always run the formatter after editing

After editing any code file or markdown file, always run the project's formatter.

Different projects use different formatters:

- dprint: many languages
- prettier: JavaScript, TypeScript, CSS, HTML, Markdown
- rustfmt: Rust
- black: Python
- dartfmt: Dart and Flutter

Run the formatter on the specific files you edited. Auto-formatted code is essential for consistent codebases.

### Always run the linter and fix all issues

Unless the linter is very slow, run the project's linter after editing files.

- Run on changed files (for per-file support)
- Or run on the whole project (if per-file isn't supported)

Treat all linter warnings as errors.

- If a warning shouldn't exist, remove it from the lint settings
- Don't leave warnings in the codebase

Auto-fix what you can:

- Formatters auto-correct their own formatting issues
- Linters often have auto-fix for some issues: run the auto-fix first
- For remaining issues that require reasoning: fix them manually

Example workflow:

```bash
# 1. Edit files
vim src/main.rs

# 2. Run formatter
cargo fmt

# 3. Run linter with auto-fix first
cargo clippy --fix

# 4. Run linter again to catch remaining issues
cargo clippy
# Fix any remaining errors manually
```

## README standards

Every project README should answer these questions within 2 minutes:

1. Why does this exist? State the problem it solves.
2. Why should I use it? State the value it provides.
3. What are the use cases? Name the practical scenarios.

Keep README and module documentation in sync by extracting common explanations into reusable documentation patterns.

## Summary

| Principle               | Rule                                                          | Exception                                            |
| ----------------------- | ------------------------------------------------------------- | ---------------------------------------------------- |
| Simplicity              | Choose the simpler solution                                   | When security or performance requires complexity     |
| Whitespace              | Blank lines before control flow, between groups               | Short, tightly coupled operations                    |
| Sequential control flow | Blank lines between sequential `if`, `for`, `match`, `switch` | Never cramped; code should never feel hurried        |
| Variable placement      | Declare at top when possible                                  | When the value depends on a prior computation        |
| Nesting                 | Avoid more than 2-3 levels deep                               | When language idioms require it                      |
| Comments                | Explain why, not what                                         | Security and performance require explanation of what |
| Extraction              | Break complex logic into small functions                      | When it hurts performance                            |
| Formatting              | Run the formatter after every edit                            | Always run it                                        |
| Linting                 | Run the linter after edits, fix all issues                    | Only skip if the linter is very slow                 |

Remember: code is read far more often than it is written. Optimize for the reader.
