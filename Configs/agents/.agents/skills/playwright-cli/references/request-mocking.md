# Request mocking

Intercept, mock, modify, and block network requests.

## CLI route commands

```bash
# Mock with custom status
playwright-cli route "**/*.jpg" --status=404

# Mock with JSON body
playwright-cli route "**/api/users" --body='[{"id":1,"name":"Alice"}]' --content-type=application/json

# Mock with custom headers
playwright-cli route "**/api/data" --body='{"ok":true}' --header="X-Custom: value"

# Remove headers from requests
playwright-cli route "**/*" --remove-header=cookie,authorization

# List active routes
playwright-cli route-list

# Remove a route or all routes
playwright-cli unroute "**/*.jpg"
playwright-cli unroute
```

## URL patterns

```
**/api/users           - Exact path match
**/api/*/details       - Wildcard in path
**/*.{png,jpg,jpeg}    - Match file extensions
**/search?q=*          - Match query parameters
```

## Advanced mocking with run-code

For conditional responses, request body inspection, response modification, or delays:

### Conditional response based on a request

```bash
playwright-cli run-code "async page => {
  await page.route('**/api/login', route => {
    const body = route.request().postDataJSON();
    if (body.username === 'admin') {
      route.fulfill({ body: JSON.stringify({ token: 'mock-token' }) });
    } else {
      route.fulfill({ status: 401, body: JSON.stringify({ error: 'Invalid' }) });
    }
  });
}"
```

### Modify a real response

```bash
playwright-cli run-code "async page => {
  await page.route('**/api/user', async route => {
    const response = await route.fetch();
    const json = await response.json();
    json.isPremium = true;
    await route.fulfill({ response, json });
  });
}"
```

### Simulate network failures

```bash
playwright-cli run-code "async page => {
  await page.route('**/api/offline', route => route.abort('internetdisconnected'));
}"
# Options: connectionrefused, timedout, connectionreset, internetdisconnected
```

### Delayed response

```bash
playwright-cli run-code "async page => {
  await page.route('**/api/slow', async route => {
    await new Promise(r => setTimeout(r, 3000));
    route.fulfill({ body: JSON.stringify({ data: 'loaded' }) });
  });
}"
```
