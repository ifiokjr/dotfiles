# TypeScript Style Guide - Visual Aesthetics

This guide focuses on the visual presentation and layout of TypeScript code—whitespace placement, comment positioning, and code organization for maximum readability. It does not cover which functions to use or language feature choices.

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

```typescript
// Good
const config = loadConfig();

if (config.isValid()) {
	processConfig(config);
}

// Bad - cramped
const config = loadConfig();
if (config.isValid()) {
	processConfig(config);
}
```

**2. Between logical groups:**

```typescript
// Good: Three distinct groups separated by blank lines
function initializeApp(): App {
	// Group 1: Configuration
	const config = loadConfig();
	validateConfig(config);

	// Group 2: Resource initialization
	const db = connectDatabase(config.db);
	const cache = initCache(config.cache);

	// Group 3: Service construction
	const services = new Services(db, cache);

	return new App(services);
}
```

**3. After complex variable declarations:**

```typescript
// Good: Breathing room after complex declaration
const query = `
  SELECT * FROM users
  WHERE id = ${userId}
  AND status = '${status}'
`;

const result = executeQuery(query);

// Bad - no breathing room
const query =
	`SELECT * FROM users WHERE id = ${userId} AND status = '${status}'`;
const result = executeQuery(query);
```

**4. Before return statements (when there's prior logic):**

```typescript
// Good
function calculateTotal(items: Item[]): number {
	const subtotal = items.reduce((sum, item) => sum + item.price, 0);
	const tax = subtotal * 0.08;

	return subtotal + tax;
}

// Bad - cramped return
function calculateTotal(items: Item[]): number {
	const subtotal = items.reduce((sum, item) => sum + item.price, 0);
	const tax = subtotal * 0.08;
	return subtotal + tax;
}
```

### Grouping Related Code

Group related operations, then separate groups with blank lines:

```typescript
// Good: Three clear groups
function processOrder(order: Order): void {
	// Validation group
	if (order.items.length === 0) {
		return;
	}
	if (order.total <= 0) {
		return;
	}

	// Calculation group
	const discount = calculateDiscount(order);
	const finalTotal = order.total - discount;

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

```typescript
// ❌ Avoid: The "arrow" anti-pattern
async function processPayment(payment: Payment): Promise<Receipt> {
	if (payment.amount > 0) {
		if (payment.user) {
			if (payment.user.isActive) {
				if (payment.user.card) {
					if (payment.user.card.isValid) {
						// Finally the actual logic...
						return await chargeCard(payment.user.card, payment.amount);
					} else {
						throw new Error("Invalid card");
					}
				} else {
					throw new Error("No card");
				}
			} else {
				throw new Error("Inactive user");
			}
		} else {
			throw new Error("No user");
		}
	} else {
		throw new Error("Invalid amount");
	}
}

// ✅ Prefer: Guard clauses with early returns
async function processPayment(payment: Payment): Promise<Receipt> {
	// Guard clauses first - each on its own for clarity
	if (payment.amount <= 0) {
		throw new Error("Invalid amount");
	}

	const user = payment.user;
	if (!user) {
		throw new Error("No user");
	}

	if (!user.isActive) {
		throw new Error("Inactive user");
	}

	const card = user.card;
	if (!card) {
		throw new Error("No card");
	}

	if (!card.isValid) {
		throw new Error("Invalid card");
	}

	// Main logic is now flat and obvious
	return await chargeCard(card, payment.amount);
}
```

### Using Early Returns with try/catch

```typescript
// ❌ Avoid: Nested try/catch
async function loadData(): Promise<Data> {
	try {
		const response = await fetch("/api/data");
		try {
			const json = await response.json();
			try {
				return validateData(json);
			} catch (e) {
				throw new Error("Invalid data format");
			}
		} catch (e) {
			throw new Error("JSON parse error");
		}
	} catch (e) {
		throw new Error("Fetch failed");
	}
}

// ✅ Prefer: Sequential operations with early error handling
async function loadData(): Promise<Data> {
	let response: Response;
	try {
		response = await fetch("/api/data");
	} catch (e) {
		throw new Error("Fetch failed");
	}

	let json: unknown;
	try {
		json = await response.json();
	} catch (e) {
		throw new Error("JSON parse error");
	}

	try {
		return validateData(json);
	} catch (e) {
		throw new Error("Invalid data format");
	}
}
```

---

## Variable Declaration and Grouping

### Variables at the Top

Declare variables at the start of functions when their values don't depend on intermediate computations.

```typescript
// Good: State established upfront
function handleRequest(req: Request): Response {
	const userId = req.userId();
	const path = req.path;
	const method = req.method;

	// Now use them...
	console.info(`${method} ${path} ${userId}`);

	return processRequest(req);
}
```

### Declaration Proximity

When a variable depends on prior computation, declare it near where it's used:

```typescript
// Good: Declaration follows computation
function processData(input: string): Data {
	const parsed = parseInput(input);

	// validated depends on parsed, so declared after
	const validated = validateParsed(parsed);

	const transformed = transformValidated(validated);

	return transformed;
}
```

---

## Comment Placement

### Inline Comments

Place inline comments on their own line above the code they describe, not at the end of lines:

```typescript
// Good
// Security: Validate token before accessing protected resource
if (!token.isValid()) {
	throw new UnauthorizedError();
}

// Bad - hard to read, easy to miss
if (!token.isValid()) { // Security check
	throw new UnauthorizedError();
}
```

### Section Comments

Use comments to mark sections of related code:

```typescript
function initializeServer(): void {
	// === Configuration Loading ===
	const config = loadConfig();

	// === Middleware Setup ===
	const auth = new AuthMiddleware(config.auth);
	const logging = new LoggingMiddleware();

	// === Route Registration ===
	const router = new Router()
		.use(auth)
		.use(logging);

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

```typescript
// Good
function processOrder(order: Order): void {
	validateOrder(order);
	const price = calculatePrice(order);
	saveToDatabase(order, price);
}

function validateOrder(order: Order): void {
	if (order.items.length === 0) {
		throw new Error("Empty order");
	}
	if (order.total < 0) {
		throw new Error("Negative total");
	}
}

// Bad - vague names
function checkStuff(order: Order): void {
	// ...
}
```

---

## Documentation Aesthetics

### Doc Comment Structure

````typescript
/**
 * Brief summary of what this does.
 *
 * @why
 * Explanation of why this code exists and what problem it solves.
 *
 * @example
 * ```typescript
 * const result = myFunction(42);
 * assert.strictEqual(result, 42);
 * ```
 */
function myFunction(x: number): number {
	return x;
}
````

### Reusable Documentation with MDT

Use MDT templates or JSDoc `@template` for reusable documentation blocks.

---

## Security and Performance Comments

### When to Comment

Always add comments when code exists for security or performance reasons:

```typescript
// Security: Sanitize user input to prevent XSS
const cleanInput = DOMPurify.sanitize(userInput);

// Performance: Pre-allocate array to avoid reallocations during loop
// This reduces GC pressure when processing large datasets
const results: Result[] = new Array(expectedCount);
for (let i = 0; i < items.length; i++) {
	results[i] = process(items[i]);
}

// Security: Disable eval to prevent code injection
// This is a defense-in-depth measure
const sandbox = { eval: undefined };
```

### Format

```typescript
// Category: Brief explanation of why this is needed
// Optional: Additional context or constraints
codeHere();
```

Categories: `Security:`, `Performance:`, `Optimization:`

---

## Formatter and Linter

### TypeScript/JavaScript-Specific Tools

**Formatter**: `prettier` (or `dprint`)

```bash
# Format specific files with prettier
npx prettier --write src/main.ts src/utils.ts

# Or format the entire project
npx prettier --write .

# Using dprint
npx dprint fmt src/main.ts
```

**Linter**: `eslint`

```bash
# Run eslint with auto-fix first
npx eslint . --fix

# Run eslint again to catch remaining issues
npx eslint .

# Treat warnings as errors
npx eslint . --max-warnings 0
```

### Workflow After Editing TypeScript Files

1. **Edit**: Make your changes
2. **Format**: `npx prettier --write <files>`
3. **Auto-fix**: `npx eslint . --fix`
4. **Check**: `npx eslint . --max-warnings 0` - fix any remaining issues manually
5. **Commit**: Only commit when eslint reports clean

**Note**: Always fix all eslint warnings. If a warning shouldn't exist, disable it in `.eslintrc` with a comment explaining why.
