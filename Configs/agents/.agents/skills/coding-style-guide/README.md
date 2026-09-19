# @ifi/coding-style-guide

A code aesthetics and layout guide focused on how code looks: whitespace placement, comment positioning, visual organization, and readability. This is not about which functions or language features to use; it is about making code visually simple and readable.

> Note: This guide does not dictate which functions, methods, or language features to use. Those decisions belong to other skills (e.g., a Rust patterns skill or a Flutter architecture skill). This skill is purely about the _visual presentation_ of code.

## Philosophy

Simple code is better than complex code.

This is a general truth. Wherever possible, choose the simpler, neater solution, unless it hinders performance or security. Code is read far more often than it is written, so optimize for the reader.

This style guide prioritizes:

1. Visual breathing room: code needs space to be understood.
2. Early clarity: state what's happening upfront, and exit early from bad states.
3. Flat over deep: indentation is a code smell, so prefer early returns.
4. Explanation of exceptions: when you must add complexity for security or performance, explain why.

## What's included

### Core principles

- Simplicity first: choose the simpler solution unless security or performance require complexity.
- Whitespace is semantics: blank lines separate concepts and give the reader breathing room.
- Early returns: use guard clauses and flat structure over deep nesting.
- Variables at the top: declare state upfront when possible.
- Security and performance comments: explain why when complexity is required.

### Language-specific guides

| Language                                | Focus                                               |
| --------------------------------------- | --------------------------------------------------- |
| [Rust](./languages/RUST.md)             | Whitespace, early returns, documentation aesthetics |
| [TypeScript](./languages/TYPESCRIPT.md) | Whitespace, early returns, documentation aesthetics |
| [Python](./languages/PYTHON.md)         | Whitespace, early returns, documentation aesthetics |
| [Dart](./languages/DART.md)             | Whitespace, early returns, documentation aesthetics |

## Quick start

### For new projects

1. Read the main guide: [SKILL.md](./SKILL.md)
2. Choose your language: Rust, TypeScript, Python, or Dart
3. Apply the visual patterns: whitespace, early returns, flat structure
4. Set up formatters: always use automated formatters (rustfmt, prettier, black, dartfmt)

### For existing projects

1. Review the visual patterns in your language guide
2. Apply them incrementally, starting with whitespace and early returns
3. Document complexity with comments explaining security or performance choices
4. Extract deeply nested code into smaller functions

## Key patterns

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

When you must introduce complexity, always add a comment explaining why:

```rust
// Security: We must validate the signature before parsing
// to prevent malformed input from causing panic or undefined behavior
if !is_valid_signature(input) {
    return Err(Error::InvalidSignature);
}
```

### Early returns example

Avoid:

```rust
if let Some(user) = request.user {
    if user.is_active {
        if user.has_permission("write") {
            // ... happy path buried deep
        }
    }
}
```

Prefer:

```rust
let user = request.user.ok_or(Error::NoUser)?;

if !user.is_active {
    return Err(Error::UserInactive);
}

if !user.has_permission("write") {
    return Err(Error::NoPermission);
}

// Happy path is now clear and at top level
```

### Whitespace is semantics

```rust
// Good: Three clear groups
fn process_order(order: Order) {
    // Group 1: Validation
    if order.items.is_empty() {
        return;
    }

    if !order.payment_method.is_valid() {
        return;
    }

    // Group 2: Calculation
    let subtotal = calculate_subtotal(&order.items);
    let tax = calculate_tax(subtotal, order.region);

    // Group 3: Persistence
    save_order(order)?;
    send_confirmation(order)?;
}
```

## Tool integration

### Formatters

This style guide complements automated formatters:

- Always use: `rustfmt`, `prettier`, `black`, `dartfmt`, `dprint`
- This guide covers: blank line placement, grouping, early return patterns, comment positioning.
- Formatters cover: indentation, trailing commas, spacing around operators, line length.

Never fight the formatter on mechanical details. This guide addresses aesthetic choices that formatters don't make.

### Always run the formatter after editing

After editing any code file or markdown file, always run the project's formatter.

- dprint: many languages
- prettier: JavaScript, TypeScript, CSS, HTML, Markdown
- rustfmt: Rust
- black: Python
- dartfmt: Dart and Flutter

Run the formatter on the specific files you edited. Auto-formatted code is essential for consistent codebases.

### Always run the linter and fix all issues

Unless the linter is very slow, run the project's linter after editing files.

Treat all linter warnings as errors. If a warning shouldn't exist, remove it from the lint settings.

Workflow:

1. Edit files
2. Run the formatter
3. Run the linter with auto-fix first
4. Run the linter again and fix remaining issues manually

## Summary

| Principle              | Rule                                            | Exception                                            |
| ---------------------- | ----------------------------------------------- | ---------------------------------------------------- |
| Simplicity             | Choose the simpler solution                     | When security or performance requires complexity     |
| Whitespace             | Blank lines before control flow, between groups | Short, tightly coupled operations                    |
| Variable placement     | Declare at top when possible                    | When the value depends on a prior computation        |
| Nesting                | Avoid more than 2-3 levels deep                 | When language idioms require it                      |
| Comments               | Explain why, not what                           | Security and performance require explanation of what |
| Extraction             | Break complex logic into small functions        | When it hurts performance                            |
| Formatting             | Run the formatter after every edit              | Always run it                                        |
| Linting                | Run the linter after edits, fix all issues      | Only skip if the linter is very slow                 |

## License

MIT. See [LICENSE](./LICENSE) for details.

---

_"Code is read far more often than it is written."_ Write for your future self and your teammates.
