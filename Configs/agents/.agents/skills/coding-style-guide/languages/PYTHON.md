# Python Style Guide - Visual Aesthetics

This guide focuses on the visual presentation and layout of Python code—whitespace placement, comment positioning, and code organization for maximum readability. It does not cover which functions to use or language feature choices.

## Table of Contents

1. [Whitespace and Visual Breathing Room](#whitespace-and-visual-breathing-room)
2. [Early Returns and Flat Structure](#early-returns-and-flat-structure)
3. [Variable Declaration and Grouping](#variable-declaration-and-grouping)
4. [Comment Placement](#comment-placement)
5. [Extraction Patterns](#extraction-patterns)
6. [Documentation Aesthetics](#documentation-aesthetics)
7. [Security and Performance Comments](#security-and-performance-comments)

---

## Whitespace and Visual Breathing Room

### The Rule

Blank lines are semantic. They separate concepts and give the reader time to process.

### Where to Add Blank Lines

**1. Before control flow statements:**

```python
# Good
config = load_config()

if config.is_valid():
  process_config(config)

# Bad - cramped
config = load_config()
if config.is_valid():
  process_config(config)
```

**2. Between logical groups:**

```python
# Good: Three distinct groups separated by blank lines
def initialize_app():
  # Group 1: Configuration
  config = load_config()
  validate_config(config)

  # Group 2: Resource initialization
  db = connect_database(config.db)
  cache = init_cache(config.cache)

  # Group 3: Service construction
  services = Services(db, cache)

  return App(services)
```

**3. After complex variable declarations:**

```python
# Good: Breathing room after complex declaration
query = f"""
    SELECT * FROM users
    WHERE id = {user_id}
    AND status = '{status}'
"""

result = execute_query(query)

# Bad - no breathing room
query = f"SELECT * FROM users WHERE id = {user_id} AND status = '{status}'"
result = execute_query(query)
```

**4. Before return statements (when there's prior logic):**

```python
# Good
def calculate_total(items: list[Item]) -> float:
  subtotal = sum(item.price for item in items)
  tax = subtotal * 0.08

  return subtotal + tax


# Bad - cramped return
def calculate_total(items: list[Item]) -> float:
  subtotal = sum(item.price for item in items)
  tax = subtotal * 0.08
  return subtotal + tax
```

### Grouping Related Code

Group related operations, then separate groups with blank lines:

```python
# Good: Three clear groups
def process_order(order: Order) -> None:
  # Validation group
  if not order.items:
    return
  if order.total <= 0:
    return

  # Calculation group
  discount = calculate_discount(order)
  final_total = order.total - discount

  # Persistence group
  save_order(order)
  send_confirmation(order)
```

---

## Early Returns and Flat Structure

### The Orange Flag: Deep Nesting

Indentation is a code smell. If you see more than 2-3 levels of nesting, refactor.

### Guard Clauses First

Handle error cases and edge conditions at the start, then proceed with the main logic.

```python
# ❌ Avoid: Deep nesting
def process_payment(payment: Payment) -> Receipt:
  if payment.amount > 0:
    if payment.user is not None:
      if payment.user.is_active:
        if payment.user.card is not None:
          if payment.user.card.is_valid:
            # Finally the actual logic...
            return charge_card(payment.user.card, payment.amount)
          else:
            raise PaymentError("Invalid card")
        else:
          raise PaymentError("No card")
      else:
        raise PaymentError("Inactive user")
    else:
      raise PaymentError("No user")
  else:
    raise PaymentError("Invalid amount")


# ✅ Prefer: Guard clauses with early returns
def process_payment(payment: Payment) -> Receipt:
  # Guard clauses first - each on its own for clarity
  if payment.amount <= 0:
    raise PaymentError("Invalid amount")

  user = payment.user
  if user is None:
    raise PaymentError("No user")

  if not user.is_active:
    raise PaymentError("Inactive user")

  card = user.card
  if card is None:
    raise PaymentError("No card")

  if not card.is_valid:
    raise PaymentError("Invalid card")

  # Main logic is now flat and obvious
  return charge_card(card, payment.amount)
```

### Using Early Continue in Loops

```python
# ❌ Avoid: Deeply nested loop processing
def process_records(records: list[Record]) -> list[ProcessedRecord]:
  results = []
  for record in records:
    if record.is_valid:
      if record.status == "active":
        if not record.is_duplicate:
          processed = process(record)
          if processed is not None:
            results.append(processed)
  return results


# ✅ Prefer: Early continue
def process_records(records: list[Record]) -> list[ProcessedRecord]:
  results = []
  for record in records:
    if not record.is_valid:
      continue

    if record.status != "active":
      continue

    if record.is_duplicate:
      continue

    processed = process(record)
    if processed is None:
      continue

    results.append(processed)

  return results
```

---

## Variable Declaration and Grouping

### Variables at the Top

Declare variables at the start of functions when their values don't depend on intermediate computations.

```python
# Good: State established upfront
def handle_request(req: Request) -> Response:
  user_id = req.user_id()
  path = req.path
  method = req.method

  # Now use them...
  logging.info(f"{method} {path} {user_id}")

  return process_request(req)
```

### Declaration Proximity

When a variable depends on prior computation, declare it near where it's used:

```python
# Good: Declaration follows computation
def process_data(input: str) -> Data:
  parsed = parse_input(input)

  # validated depends on parsed, so declared after
  validated = validate_parsed(parsed)

  transformed = transform_validated(validated)

  return transformed
```

---

## Comment Placement

### Inline Comments

Place inline comments on their own line above the code they describe, not at the end of lines:

```python
# Good
# Security: Validate token before accessing protected resource
if not token.is_valid():
  raise UnauthorizedError()

# Bad - hard to read, easy to miss
if not token.is_valid():  # Security check
  raise UnauthorizedError()
```

### Section Comments

Use comments to mark sections of related code:

```python
def initialize_server():
  # === Configuration Loading ===
  config = load_config()

  # === Middleware Setup ===
  auth = AuthMiddleware(config.auth)
  logging = LoggingMiddleware()

  # === Route Registration ===
  router = Router()
  router.add_middleware(auth)
  router.add_middleware(logging)

  # === Server Start ===
  server.bind(config.port).serve(router)
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

```python
# Good
def process_order(order: Order) -> None:
    validate_order(order)
    price = calculate_price(order)
    save_to_database(order, price)

def validate_order(order: Order) -> None:
    if not order.items:
        raise ValueError("Empty order")
    if order.total < 0:
        raise ValueError("Negative total")

# Bad - vague names
def check_stuff(order: Order):
    # ...
```

---

## Documentation Aesthetics

### Docstring Structure

```python
def my_function(x: int) -> int:
  """Brief summary of what this does.

  Why This Exists:
      Explanation of why this code exists and what problem it solves.

  Example:
      >>> result = my_function(42)
      >>> result
      42
  """
  return x
```

---

## Security and Performance Comments

### When to Comment

Always add comments when code exists for security or performance reasons:

```python
# Security: Use parameterized queries to prevent SQL injection
cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))

# Performance: Pre-allocate list to avoid reallocations
# This matters when processing thousands of items
results = [None] * expected_count
for i, item in enumerate(items):
  results[i] = process(item)

# Security: Disable dangerous built-ins in sandboxed environment
del __builtins__.eval
del __builtins__.exec
```

### Format

```python
# Category: Brief explanation of why this is needed
# Optional: Additional context or constraints
code_here()
```

Categories: `Security:`, `Performance:`, `Optimization:`

---

## Formatter and Linter

### Python-Specific Tools

**Formatter**: `black` (or `ruff format`)

```bash
# Format specific files with black
black src/main.py src/utils.py

# Or format the entire project
black .

# Using ruff (faster)
ruff format src/main.py
```

**Linter**: `ruff` (or `pylint`, `flake8`)

```bash
# Run ruff check with auto-fix first
ruff check --fix .

# Run ruff again to catch remaining issues
ruff check .

# Treat warnings as errors
ruff check --select ALL .
```

### Workflow After Editing Python Files

1. **Edit**: Make your changes
2. **Format**: `black <files>` or `ruff format <files>`
3. **Auto-fix**: `ruff check --fix .`
4. **Check**: `ruff check .` - fix any remaining issues manually
5. **Commit**: Only commit when ruff reports clean

**Note**: Always fix all linter warnings. If a warning shouldn't exist, disable it in `pyproject.toml` or setup.cfg with a comment explaining why.
