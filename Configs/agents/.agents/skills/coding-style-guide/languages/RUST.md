# Rust Style Guide - Visual Aesthetics

This guide focuses on the visual presentation and layout of Rust code—whitespace placement, comment positioning, and code organization for maximum readability. It does not cover which functions to use or language feature choices.

## Table of Contents

1. [Whitespace and Visual Breathing Room](#whitespace-and-visual-breathing-room)
2. [Sequential Control Flow Statements](#sequential-control-flow-statements)
3. [Early Returns and Flat Structure](#early-returns-and-flat-structure)
4. [Variable Declaration and Grouping](#variable-declaration-and-grouping)
5. [Comment Placement](#comment-placement)
6. [Extraction Patterns](#extraction-patterns)
7. [Documentation Aesthetics](#documentation-aesthetics)
8. [Security and Performance Comments](#security-and-performance-comments)
9. [Formatter and Linter](#formatter-and-linter)

---

## Whitespace and Visual Breathing Room

### The Rule

Blank lines are semantic. They separate concepts and give the reader time to process.

### Where to Add Blank Lines

**1. Before control flow statements:**

```rust
// Good
let config = load_config()?;

if config.is_valid() {
    process_config(config);
}

// Bad - cramped
let config = load_config()?;
if config.is_valid() {
    process_config(config);
}
```

**2. Between logical groups:**

```rust
// Good: Three distinct groups separated by blank lines
fn initialize_app() -> Result<App, Error> {
    // Group 1: Configuration
    let config = load_config()?;
    validate_config(&config)?;

    // Group 2: Resource initialization  
    let db = connect_database(&config.db)?;
    let cache = init_cache(&config.cache)?;

    // Group 3: Service construction
    let services = Services::new(db, cache);

    Ok(App::new(services))
}
```

**3. After complex variable declarations:**

```rust
// Good: Breathing room after complex declaration
let query = format!(
    "SELECT * FROM users WHERE id = {} AND status = '{}'",
    user_id,
    status
);

let result = execute_query(&query)?;

// Bad - no breathing room
let query = format!("SELECT * FROM users WHERE id = {} AND status = '{}'", user_id, status);
let result = execute_query(&query)?;
```

**4. Before return statements (when there's prior logic):**

```rust
// Good
fn calculate_total(items: &[Item]) -> f64 {
    let subtotal: f64 = items.iter().map(|i| i.price).sum();
    let tax = subtotal * 0.08;

    return subtotal + tax;
}

// Bad - cramped return
fn calculate_total(items: &[Item]) -> f64 {
    let subtotal: f64 = items.iter().map(|i| i.price).sum();
    let tax = subtotal * 0.08;
    return subtotal + tax;
}
```

### Grouping Related Code

Group related operations, then separate groups with blank lines:

```rust
// Good: Three clear groups
fn process_order(order: Order) {
    // Validation group
    if order.items.is_empty() {
        return;
    }
    if order.total <= 0.0 {
        return;
    }

    // Calculation group
    let discount = calculate_discount(&order);
    let final_total = order.total - discount;

    // Persistence group
    save_order(order)?;
    send_confirmation(order)?;
}
```

### Sequential Control Flow Statements

**Rule**: Sequential `if` statements, `for` loops, `match` statements, etc. should each have a blank line before them.

**The Principle**: Code should never feel cramped or hurried. Each control flow statement deserves its own space.

```rust
// ❌ Avoid: Cramped sequential control flow
fn validate_input(input: &str) -> Result<(), Error> {
    if input.is_empty() {
        return Err(Error::Empty);
    }
    if !is_valid_format(input) {
        return Err(Error::InvalidFormat);
    }
    if input.len() > MAX_LENGTH {
        return Err(Error::TooLong);
    }
    Ok(())
}

// ✅ Prefer: Each if statement has its own space
fn validate_input(input: &str) -> Result<(), Error> {
    if input.is_empty() {
        return Err(Error::Empty);
    }

    if !is_valid_format(input) {
        return Err(Error::InvalidFormat);
    }

    if input.len() > MAX_LENGTH {
        return Err(Error::TooLong);
    }

    Ok(())
}
```

### The Orange Flag: Deep Nesting

Indentation is a code smell. If you see more than 2-3 levels of nesting, refactor.

### Guard Clauses First

Handle error cases and edge conditions at the start, then proceed with the main logic.

```rust
// ❌ Avoid: The "arrow" anti-pattern
fn process_payment(payment: &Payment) -> Result<Receipt, Error> {
    if payment.amount > 0.0 {
        if let Some(user) = &payment.user {
            if user.is_active {
                if let Some(card) = &user.card {
                    if card.is_valid() {
                        // Finally the actual logic...
                        charge_card(card, payment.amount)
                    } else {
                        Err(Error::InvalidCard)
                    }
                } else {
                    Err(Error::NoCard)
                }
            } else {
                Err(Error::InactiveUser)
            }
        } else {
            Err(Error::NoUser)
        }
    } else {
        Err(Error::InvalidAmount)
    }
}

// ✅ Prefer: Guard clauses with early returns
fn process_payment(payment: &Payment) -> Result<Receipt, Error> {
    // Guard clauses first - each on its own for clarity
    if payment.amount <= 0.0 {
        return Err(Error::InvalidAmount);
    }

    let user = payment.user.as_ref().ok_or(Error::NoUser)?;

    if !user.is_active {
        return Err(Error::InactiveUser);
    }

    let card = user.card.as_ref().ok_or(Error::NoCard)?;

    if !card.is_valid() {
        return Err(Error::InvalidCard);
    }

    // Main logic is now flat and obvious
    charge_card(card, payment.amount)
}
```

### Using the `?` Operator for Flatness

```rust
// ❌ Avoid: Nested match statements
fn load_config() -> Result<Config, Error> {
    match read_file("config.toml") {
        Ok(contents) => {
            match toml::from_str(&contents) {
                Ok(config) => Ok(config),
                Err(e) => Err(Error::ParseError(e)),
            }
        }
        Err(e) => Err(Error::IoError(e)),
    }
}

// ✅ Prefer: Flat with `?`
fn load_config() -> Result<Config, Error> {
    let contents = read_file("config.toml").map_err(Error::IoError)?;
    let config = toml::from_str(&contents).map_err(Error::ParseError)?;
    
    Ok(config)
}
```

### Using `let-else` for Early Returns

`let-else` is a powerful construct for destructuring with an early return in the else branch. Like sequential if statements, each `let-else` should have a blank line before it.

```rust
// ❌ Avoid: Nested match or if-let
fn process_user(user_id: UserId) -> Result<UserProfile, Error> {
    let user = match db.get_user(user_id) {
        Some(u) => u,
        None => return Err(Error::UserNotFound),
    };
    
    if let Some(profile) = db.get_profile(user.id) {
        // Process profile
        if let Some(settings) = db.get_settings(user.id) {
            // Process settings
            Ok(UserProfile { user, profile, settings })
        } else {
            Err(Error::SettingsNotFound)
        }
    } else {
        Err(Error::ProfileNotFound)
    }
}

// ✅ Prefer: let-else with blank lines between them
fn process_user(user_id: UserId) -> Result<UserProfile, Error> {
    let Some(user) = db.get_user(user_id) else {
        return Err(Error::UserNotFound);
    };

    let Some(profile) = db.get_profile(user.id) else {
        return Err(Error::ProfileNotFound);
    };

    let Some(settings) = db.get_settings(user.id) else {
        return Err(Error::SettingsNotFound);
    };

    Ok(UserProfile { user, profile, settings })
}
```

```rust
// ❌ Avoid: Cramped let-else statements
fn extract_config(data: &Value) -> Result<Config, Error> {
    let Value::Object(map) = data else {
        return Err(Error::NotAnObject);
    };
    let Some(name) = map.get("name") else {
        return Err(Error::MissingName);
    };
    let Some(Value::String(name)) = name else {
        return Err(Error::NameNotString);
    };
    Ok(Config::new(name))
}

// ✅ Prefer: Spacious let-else with blank lines
fn extract_config(data: &Value) -> Result<Config, Error> {
    let Value::Object(map) = data else {
        return Err(Error::NotAnObject);
    };

    let Some(name) = map.get("name") else {
        return Err(Error::MissingName);
    };

    let Some(Value::String(name)) = name else {
        return Err(Error::NameNotString);
    };

    Ok(Config::new(name))
}
```

---

## Variable Declaration and Grouping

### Variables at the Top

Declare variables at the start of functions when their values don't depend on intermediate computations.

```rust
// Good: State established upfront
fn handle_request(req: Request) -> Response {
    let user_id = req.user_id();
    let path = req.path();
    let method = req.method();

    // Now use them...
    log::info!("{} {} {}", method, path, user_id);

    process_request(req)
}
```

### Declaration Proximity

When a variable depends on prior computation, declare it near where it's used:

```rust
// Good: Declaration follows computation
fn process_data(input: &str) -> Result<Data, Error> {
    let parsed = parse_input(input)?;

    // validated depends on parsed, so declared after
    let validated = validate_parsed(&parsed)?;

    let transformed = transform_validated(validated);

    Ok(transformed)
}
```

---

## Comment Placement

### Inline Comments

Place inline comments on their own line above the code they describe, not at the end of lines:

```rust
// Good
// Security: Validate token before accessing protected resource
if !token.is_valid() {
    return Err(Error::Unauthorized);
}

// Bad - hard to read, easy to miss
if !token.is_valid() { // Security check
    return Err(Error::Unauthorized);
}
```

### Section Comments

Use comments to mark sections of related code:

```rust
fn initialize_server() {
    // === Configuration Loading ===
    let config = load_config().expect("Config required");

    // === Middleware Setup ===
    let auth = AuthMiddleware::new(&config.auth);
    let logging = LoggingMiddleware::new();

    // === Route Registration ===
    let router = Router::new()
        .with(auth)
        .with(logging);

    // === Server Start ===
    Server::bind(config.port).serve(router);
}
```

---

## Extraction Patterns

### When to Extract

Extract code into functions when:

- The logic is nested more than 2-3 levels deep
- The function body exceeds ~30-40 lines
- A logical unit can be named clearly
- The same pattern appears in multiple places

### Naming Extracted Functions

Name extracted functions for what they do, not how:

```rust
// Good
fn process_order(order: &Order) -> Result {
    validate_order(order)?;
    let price = calculate_price(order);
    save_to_database(order, price)?;
    Ok(())
}

fn validate_order(order: &Order) -> Result {
    if order.items.is_empty() {
        return Err(Error::EmptyOrder);
    }
    if order.total < 0.0 {
        return Err(Error::NegativeTotal);
    }
    Ok(())
}

// Bad - vague names
fn check_stuff(order: &Order) {
    // ...
}
```

---

## Documentation Aesthetics

### Doc Comment Structure

````rust
/// Brief summary of what this does.
///
/// # Why This Exists
/// Explanation of why this code exists and what problem it solves.
///
/// # Examples
/// ```rust
/// let result = my_function(42);
/// assert_eq!(result, 42);
/// ```
fn my_function(x: i32) -> i32 {
    x
}
````

### Using Documentation Macros

Reuse documentation with Rust's `#[doc = ...]` or macro-generated docs.

---

## Security and Performance Comments

### When to Comment

Always add comments when code exists for security or performance reasons:

```rust
// Security: Constant-time comparison to prevent timing attacks
if !constant_time_eq(provided, expected) {
    return Err(Error::Invalid);
}

// Performance: Pre-allocate to avoid reallocations during loop
let mut results = Vec::with_capacity(expected_count);
for item in items {
    results.push(process(item));
}

// Safety: Required invariant for unsafe block below
// The pointer is valid because we checked len > 0 above
unsafe { *ptr.offset(index) }
```

### Format

```rust
// Category: Brief explanation of why this is needed
// Optional: Additional context or constraints
code_here();
```

Categories: `Security:`, `Performance:`, `Safety:`, `Optimization:`

---

## Formatter and Linter

### Rust-Specific Tools

**Formatter**: `rustfmt`

```bash
# Format specific files
cargo fmt -- src/main.rs src/lib.rs

# Or format the entire project
cargo fmt
```

**Linter**: `clippy`

```bash
# Run clippy with auto-fix first
cargo clippy --fix

# Run clippy again to catch remaining issues
cargo clippy

# Treat warnings as errors
cargo clippy -- -D warnings
```

### Workflow After Editing Rust Files

1. **Edit**: Make your changes
2. **Format**: `cargo fmt`
3. **Auto-fix**: `cargo clippy --fix`
4. **Check**: `cargo clippy` - fix any remaining issues manually
5. **Commit**: Only commit when clippy reports clean

**Note**: Always fix all clippy warnings. If a warning shouldn't exist, add an allow attribute with a comment explaining why, or configure it in `.clippy.toml` or `clippy.toml`.
