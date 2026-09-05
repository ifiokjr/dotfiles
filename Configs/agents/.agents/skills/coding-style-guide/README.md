# @ifi/coding-style-guide

A code aesthetics and layout guide focused on **how code looks**—whitespace placement, comment positioning, visual organization, and readability. This is not about which functions or language features to use; it's about making code visually simple and readable.

> **Note**: This guide does not dictate which functions, methods, or language features to use. Those decisions belong to other skills (e.g., a Rust patterns skill or a Flutter architecture skill). This skill is purely about the _visual presentation_ of code.

## 🎯 Philosophy

**Simple code is better than complex code.**

This is a general truth. Wherever possible, choose the simpler, neater solution—unless it hinders performance or security. Code is read far more often than it is written, so optimize for the reader.

This style guide prioritizes:

1. **Visual breathing room**: Code needs space to be understood
2. **Early clarity**: State what's happening upfront, exit early from bad states
3. **Flat over deep**: Indentation is a code smell; prefer early returns
4. **Explanation of exceptions**: When you must add complexity for security or performance, explain why

## 📚 What's Included

### Core Principles

- **Simplicity First**: Choose the simpler solution unless security or performance require complexity
- **Whitespace Is Semantics**: Blank lines separate concepts and give the reader breathing room
- **Early Returns**: Guard clauses and flat structure over deep nesting
- **Variables at the Top**: Declare state upfront when possible
- **Security/Performance Comments**: Explain why when complexity is required

### Language-Specific Guides

| Language                                | Focus                                               |
| --------------------------------------- | --------------------------------------------------- |
| [Rust](./languages/RUST.md)             | Whitespace, early returns, documentation aesthetics |
| [TypeScript](./languages/TYPESCRIPT.md) | Whitespace, early returns, documentation aesthetics |
| [Python](./languages/PYTHON.md)         | Whitespace, early returns, documentation aesthetics |
| [Dart](./languages/DART.md)             | Whitespace, early returns, documentation aesthetics |

## 🚀 Quick Start

### For New Projects

1. **Read the main guide**: [SKILL.md](./SKILL.md)
2. **Choose your language**: Rust, TypeScript, Python, or Dart
3. **Apply visual patterns**: Whitespace, early returns, flat structure
4. **Set up formatters**: Always use automated formatters (rustfmt, prettier, black, dartfmt)

### For Existing Projects

1. **Review the visual patterns**: Look at examples in your language guide
2. **Apply incrementally**: Start with whitespace and early returns
3. **Document complexity**: Add comments explaining security/performance choices
4. **Extract when nested**: Break deep nesting into smaller functions

## 📖 Key Patterns

### Simplicity First

```
Given two implementations that achieve the same goal,
choose the one that:
- Has fewer lines
- Has less nesting
- Requires less mental effort to follow
- Is easier to explain in words

Exception: When security or performance requires complexity
```

When you must introduce complexity, **always add a comment explaining why**:

```rust
// Security: We must validate the signature before parsing
// to prevent malformed input from causing panic or undefined behavior
if !is_valid_signature(input) {
    return Err(Error::InvalidSignature);
}
```

### Early Returns Example

**❌ Avoid:**

```rust
if let Some(user) = request.user {
    if user.is_active {
        if user.has_permission("write") {
            // ... happy path buried deep
        }
    }
}
```

**✅ Prefer:**

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

### Whitespace Is Semantics

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

## 🔧 Tool Integration

### Formatters

This style guide **complements** automated formatters:

- **Always use**: `rustfmt`, `prettier`, `black`, `dartfmt`, `dprint`
- **This guide covers**: Blank line placement, grouping, early return patterns, comment positioning
- **Formatters cover**: Indentation, trailing commas, spacing around operators, line length

Never fight the formatter on mechanical details. This guide addresses aesthetic choices that formatters don't make.

### Always Run the Formatter After Editing

**Rule**: After editing any code file or markdown file, always run the project's formatter.

- **dprint** - Universal formatter for many languages
- **prettier** - JavaScript, TypeScript, CSS, HTML, Markdown
- **rustfmt** - Rust
- **black** - Python
- **dartfmt** - Dart/Flutter

Run the formatter on the specific files you edited. Auto-formatted code is essential for consistent codebases.

### Always Run the Linter and Fix All Issues

**Rule**: Unless the linter is very slow, run the project's linter after editing files.

**Warnings Are Errors**: Treat all linter warnings as errors. If a warning shouldn't exist, remove it from the lint settings.

**Workflow**:

1. Edit files
2. Run formatter
3. Run linter with auto-fix first
4. Run linter again and fix remaining issues manually

## 📋 Summary

| Principle              | Rule                                            | Exception                                            |
| ---------------------- | ----------------------------------------------- | ---------------------------------------------------- |
| **Simplicity**         | Choose the simpler solution                     | When security or performance requires complexity     |
| **Whitespace**         | Blank lines before control flow, between groups | Short, tightly-coupled operations                    |
| **Variable placement** | Declare at top when possible                    | When value depends on prior computation              |
| **Nesting**            | Avoid more than 2-3 levels deep                 | When language idioms require it                      |
| **Comments**           | Explain why, not what                           | Security and performance require explanation of what |
| **Extraction**         | Break complex logic into small functions        | When it hurts performance                            |
| **Formatting**         | Run formatter after every edit                  | N/A - Always run it                                  |
| **Linting**            | Run linter after edits, fix all issues          | Only skip if linter is very slow                     |

## 📄 License

MIT - See [LICENSE](./LICENSE) for details.

---

_"Code is read far more often than it is written."_ — Write for your future self and your teammates.
