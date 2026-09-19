# Storage management

Manage cookies, localStorage, sessionStorage, and browser storage state.

## Storage state

Save and restore complete browser state including cookies and storage.

### Save storage state

```bash
# Save to auto-generated filename (storage-state-{timestamp}.json)
playwright-cli state-save

# Save to specific filename
playwright-cli state-save my-auth-state.json
```

### Restore storage state

```bash
# Load storage state from file
playwright-cli state-load my-auth-state.json

# Reload page to apply cookies
playwright-cli open https://example.com
```

### Storage state file format

The saved file contains:

```json
{
  "cookies": [
    {
      "name": "session_id",
      "value": "abc123",
      "domain": "example.com",
      "path": "/",
      "expires": 1893456000,
      "httpOnly": true,
      "secure": true,
      "sameSite": "Lax"
    }
  ],
  "origins": [
    {
      "origin": "https://example.com",
      "localStorage": [
        { "name": "theme", "value": "dark" },
        { "name": "user_id", "value": "12345" }
      ]
    }
  ]
}
```

## Cookies

### List all cookies

```bash
playwright-cli cookie-list
```

### Filter cookies by domain

```bash
playwright-cli cookie-list --domain=example.com
```

### Filter cookies by path

```bash
playwright-cli cookie-list --path=/api
```

### Get a specific cookie

```bash
playwright-cli cookie-get session_id
```

### Set a cookie

```bash
# Basic cookie
playwright-cli cookie-set session abc123

# Cookie with options
playwright-cli cookie-set session abc123 --domain=example.com --path=/ --httpOnly --secure --sameSite=Lax

# Cookie with expiration (Unix timestamp)
playwright-cli cookie-set remember_me token123 --expires=1893456000
```

### Delete a cookie

```bash
playwright-cli cookie-delete session_id
```

### Clear all cookies

```bash
playwright-cli cookie-clear
```

### Advanced: multiple cookies or custom options

For scenarios like adding multiple cookies at once, use `run-code`:

```bash
playwright-cli run-code "async page => {
  await page.context().addCookies([
    { name: 'session_id', value: 'sess_abc123', domain: 'example.com', path: '/', httpOnly: true },
    { name: 'preferences', value: JSON.stringify({ theme: 'dark' }), domain: 'example.com', path: '/' }
  ]);
}"
```

## Local storage

### List all localStorage items

```bash
playwright-cli localstorage-list
```

### Get a single value

```bash
playwright-cli localstorage-get token
```

### Set a value

```bash
playwright-cli localstorage-set theme dark
```

### Set a JSON value

```bash
playwright-cli localstorage-set user_settings '{"theme":"dark","language":"en"}'
```

### Delete a single item

```bash
playwright-cli localstorage-delete token
```

### Clear all localStorage

```bash
playwright-cli localstorage-clear
```

### Advanced: multiple operations

For scenarios like setting multiple values at once, use `run-code`:

```bash
playwright-cli run-code "async page => {
  await page.evaluate(() => {
    localStorage.setItem('token', 'jwt_abc123');
    localStorage.setItem('user_id', '12345');
    localStorage.setItem('expires_at', Date.now() + 3600000);
  });
}"
```

## Session storage

### List all sessionStorage items

```bash
playwright-cli sessionstorage-list
```

### Get a single value

```bash
playwright-cli sessionstorage-get form_data
```

### Set a value

```bash
playwright-cli sessionstorage-set step 3
```

### Delete a single item

```bash
playwright-cli sessionstorage-delete step
```

### Clear sessionStorage

```bash
playwright-cli sessionstorage-clear
```

## IndexedDB

### List databases

```bash
playwright-cli run-code "async page => {
  return await page.evaluate(async () => {
    const databases = await indexedDB.databases();
    return databases;
  });
}"
```

### Delete a database

```bash
playwright-cli run-code "async page => {
  await page.evaluate(() => {
    indexedDB.deleteDatabase('myDatabase');
  });
}"
```

## Common patterns

### Authentication state reuse

```bash
# Step 1: Login and save state
playwright-cli open https://app.example.com/login
playwright-cli snapshot
playwright-cli fill e1 "user@example.com"
playwright-cli fill e2 "password123"
playwright-cli click e3

# Save the authenticated state
playwright-cli state-save auth.json

# Step 2: Later, restore state and skip login
playwright-cli state-load auth.json
playwright-cli open https://app.example.com/dashboard
# Already logged in!
```

### Save and restore roundtrip

```bash
# Set up authentication state
playwright-cli open https://example.com
playwright-cli eval "() => { document.cookie = 'session=abc123'; localStorage.setItem('user', 'john'); }"

# Save state to file
playwright-cli state-save my-session.json

# ... later, in a new session ...

# Restore state
playwright-cli state-load my-session.json
playwright-cli open https://example.com
# Cookies and localStorage are restored!
```

## Security notes

- Never commit storage state files containing auth tokens
- Add `*.auth-state.json` to `.gitignore`
- Delete state files after automation completes
- Use environment variables for sensitive data
- By default, sessions run in-memory mode which is safer for sensitive operations
