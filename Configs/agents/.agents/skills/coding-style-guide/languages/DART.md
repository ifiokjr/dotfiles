# Dart Style Guide - Visual Aesthetics

This guide focuses on the visual presentation and layout of Dart code—whitespace placement, comment positioning, and code organization for maximum readability. It does not cover which functions to use or language feature choices.

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

```dart
// Good
final config = loadConfig();

if (config.isValid()) {
  processConfig(config);
}

// Bad - cramped
final config = loadConfig();
if (config.isValid()) {
  processConfig(config);
}
```

**2. Between logical groups:**

```dart
// Good: Three distinct groups separated by blank lines
void initializeApp() {
  // Group 1: Configuration
  final config = loadConfig();
  validateConfig(config);

  // Group 2: Resource initialization  
  final db = connectDatabase(config.db);
  final cache = initCache(config.cache);

  // Group 3: Service construction
  final services = Services(db, cache);

  return App(services);
}
```

**3. After complex variable declarations:**

```dart
// Good: Breathing room after complex declaration
final query = '''
  SELECT * FROM users
  WHERE id = \${userId}
  AND status = '\${status}'
''';

final result = executeQuery(query);

// Bad - no breathing room
final query = 'SELECT * FROM users WHERE id = \${userId} AND status = "\${status}"';
final result = executeQuery(query);
```

**4. Before return statements (when there's prior logic):**

```dart
// Good
double calculateTotal(List<Item> items) {
  final subtotal = items.fold(0, (sum, item) => sum + item.price);
  final tax = subtotal * 0.08;

  return subtotal + tax;
}

// Bad - cramped return
double calculateTotal(List<Item> items) {
  final subtotal = items.fold(0, (sum, item) => sum + item.price);
  final tax = subtotal * 0.08;
  return subtotal + tax;
}
```

### Grouping Related Code

Group related operations, then separate groups with blank lines:

```dart
// Good: Three clear groups
void processOrder(Order order) {
  // Validation group
  if (order.items.isEmpty) {
    return;
  }
  if (order.total <= 0) {
    return;
  }

  // Calculation group
  final discount = calculateDiscount(order);
  final finalTotal = order.total - discount;

  // Persistence group
  saveOrder(order);
  sendConfirmation(order);
}
```

---

## Early Returns and Flat Structure

### The Orange Flag: Deep Nesting

Indentation is a code smell. If you see more than 2-3 levels of nesting, refactor.

### Guard Clauses First

Handle error cases and edge conditions at the start, then proceed with the main logic.

```dart
// ❌ Avoid: The "arrow" anti-pattern
Receipt processPayment(Payment payment) {
  if (payment.amount > 0) {
    if (payment.user != null) {
      if (payment.user!.isActive) {
        if (payment.user!.card != null) {
          if (payment.user!.card!.isValid) {
            // Finally the actual logic...
            return chargeCard(payment.user!.card!, payment.amount);
          } else {
            throw PaymentError('Invalid card');
          }
        } else {
          throw PaymentError('No card');
        }
      } else {
        throw PaymentError('Inactive user');
      }
    } else {
      throw PaymentError('No user');
    }
  } else {
    throw PaymentError('Invalid amount');
  }
}

// ✅ Prefer: Guard clauses with early returns
Receipt processPayment(Payment payment) {
  // Guard clauses first - each on its own for clarity
  if (payment.amount <= 0) {
    throw PaymentError('Invalid amount');
  }

  final user = payment.user;
  if (user == null) {
    throw PaymentError('No user');
  }

  if (!user.isActive) {
    throw PaymentError('Inactive user');
  }

  final card = user.card;
  if (card == null) {
    throw PaymentError('No card');
  }

  if (!card.isValid) {
    throw PaymentError('Invalid card');
  }

  // Main logic is now flat and obvious
  return chargeCard(card, payment.amount);
}
```

### Using Pattern Matching (Dart 3+)

```dart
// Good: Using switch for flat structure
String getStatusDescription(OrderStatus status) {
  return switch (status) {
    OrderStatus.pending => 'Waiting for payment',
    OrderStatus.processing => 'Preparing for shipment',
    OrderStatus.shipped => 'In transit',
    OrderStatus.delivered => 'Delivered',
    OrderStatus.cancelled => 'Cancelled',
  };
}

// Good: Using pattern matching with guard clauses
Future<Result> processOrder(Order order) async {
  // Validate with early returns
  if (order.items.isEmpty) {
    return Result.failure('Empty order');
  }

  // Pattern match on order type
  return switch (order.type) {
    OrderType.standard => await _processStandardOrder(order),
    OrderType.express => await _processExpressOrder(order),
    OrderType.subscription => await _processSubscriptionOrder(order),
  };
}
```

---

## Variable Declaration and Grouping

### Variables at the Top

Declare variables at the start of functions when their values don't depend on intermediate computations.

```dart
// Good: State established upfront
Response handleRequest(Request req) {
  final userId = req.userId();
  final path = req.path;
  final method = req.method;

  // Now use them...
  log.info('$method $path $userId');

  return processRequest(req);
}
```

### Declaration Proximity

When a variable depends on prior computation, declare it near where it's used:

```dart
// Good: Declaration follows computation
Data processData(String input) {
  final parsed = parseInput(input);

  // validated depends on parsed, so declared after
  final validated = validateParsed(parsed);

  final transformed = transformValidated(validated);

  return transformed;
}
```

---

## Comment Placement

### Inline Comments

Place inline comments on their own line above the code they describe, not at the end of lines:

```dart
// Good
// Security: Validate token before accessing protected resource
if (!token.isValid()) {
  throw UnauthorizedError();
}

// Bad - hard to read, easy to miss
if (!token.isValid()) { // Security check
  throw UnauthorizedError();
}
```

### Section Comments

Use comments to mark sections of related code:

```dart
void initializeServer() {
  // === Configuration Loading ===
  final config = loadConfig();

  // === Middleware Setup ===
  final auth = AuthMiddleware(config.auth);
  final logging = LoggingMiddleware();

  // === Route Registration ===
  final router = Router()
    ..use(auth)
    ..use(logging);

  // === Server Start ===
  server.bind(config.port).serve(router);
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

```dart
// Good
void processOrder(Order order) {
  validateOrder(order);
  final price = calculatePrice(order);
  saveToDatabase(order, price);
}

void validateOrder(Order order) {
  if (order.items.isEmpty) {
    throw StateError('Empty order');
  }
  if (order.total < 0) {
    throw StateError('Negative total');
  }
}

// Bad - vague names
void checkStuff(Order order) {
  // ...
}
```

---

## Documentation Aesthetics

### Doc Comment Structure

````dart
/// Brief summary of what this does.
///
/// ## Why This Exists
///
/// Explanation of why this code exists and what problem it solves.
///
/// ## Example
///
/// ```dart
/// final result = myFunction(42);
/// assert(result == 42);
/// ```
int myFunction(int x) {
  return x;
}
````

### Using Documentation Macros

Reuse documentation with Dart macros:

```dart
// Define in a central location
/// {@template why-validation}
/// Validates input to prevent invalid state from propagating.
/// {@endtemplate}

// Use in multiple places
/// Validates user input.
/// {@macro why-validation}
void validateUserInput(String input) { }

/// Validates order data.
/// {@macro why-validation}
void validateOrderData(Order order) { }
```

---

## Security and Performance Comments

### When to Comment

Always add comments when code exists for security or performance reasons:

```dart
// Security: Validate JWT signature before trusting claims
// This prevents token forgery attacks
if (!verifySignature(token)) {
  throw UnauthorizedError('Invalid token');
}

// Performance: Use a map for O(1) lookups instead of list scan
// This method is called in a hot loop during data processing
final lookupMap = {for (final item in items) item.id: item};

// Security: Sanitize user input to prevent XSS
final cleanInput = HtmlEscape().convert(userInput);
```

### Format

```dart
// Category: Brief explanation of why this is needed
// Optional: Additional context or constraints
codeHere();
```

Categories: `Security:`, `Performance:`, `Optimization:`

---

## Formatter and Linter

### Dart/Flutter-Specific Tools

**Formatter**: `dart format` (built-in)

```bash
# Format specific files
dart format lib/main.dart lib/utils.dart

# Or format the entire project
dart format .

# Using flutter
flutter format lib/
```

**Linter**: `dart analyze` (built-in)

```bash
# Run analyzer (no auto-fix, but shows issues)
dart analyze

# Using flutter
flutter analyze

# Treat warnings as errors
dart analyze --fatal-warnings
```

### Workflow After Editing Dart Files

1. **Edit**: Make your changes
2. **Format**: `dart format <files>` or `flutter format`
3. **Analyze**: `dart analyze` or `flutter analyze`
4. **Fix**: Address all warnings and errors manually (Dart analyzer has limited auto-fix)
5. **Commit**: Only commit when analyzer reports clean

**Note**: Always fix all analyzer warnings. Configure lint rules in `analysis_options.yaml`. If a rule shouldn't apply, disable it with a comment explaining why.
