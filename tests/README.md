# Construkted Reality — Workspace Functional Tests

Black-box HTTP tests for the running WordPress instance and other platform services. These tests make external requests to verify AJAX handlers, REST API endpoints, and overall system behavior. They do not import any PHP code.

## Prerequisites

- **DDEV** running with the WordPress site accessible
- **Node.js 18+** (native `fetch` required)

## Quick Start

```bash
cd tests
npm install
npm test
```

## Scripts

| Command | Description |
|---------|-------------|
| `npm test` | Run all tests once |
| `npm run test:watch` | Run tests in watch mode |
| `npm run test:wordpress` | Run only WordPress tests |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `WP_TEST_URL` | `https://construkted-develop-01.ddev.site` | WordPress base URL |
| `WP_APP_PASSWORD` | _(none)_ | Base64-encoded `user:password` for WP Application Passwords auth |
| `NODE_TLS_REJECT_UNAUTHORIZED` | `1` | Set to `0` to accept self-signed DDEV certificates |

## DDEV Certificates

DDEV uses self-signed TLS certificates that Node.js rejects by default. To work around this, run tests with:

```bash
NODE_TLS_REJECT_UNAUTHORIZED=0 npm test
```

Or install the DDEV CA certificate into your system trust store:

```bash
mkcert -install   # if you used mkcert with DDEV
```

## Directory Structure

```
tests/
├── package.json
├── vitest.config.ts
├── tsconfig.json
├── wordpress/
│   ├── helpers/
│   │   └── wp-client.ts      # HTTP client helper for WP requests
│   └── smoke.test.ts         # Smoke tests (DDEV reachability)
└── README.md
```

## Adding New Tests

1. Create a `.test.ts` file in the appropriate subdirectory (e.g. `wordpress/`)
2. Import the `WpClient` helper:
   ```typescript
   import { createWpClient } from "./helpers/wp-client";
   ```
3. Use `wp.get()`, `wp.post()`, `wp.ajax()`, or `wp.rest()` to make requests
4. Run `npm test` to verify

### Example: Testing a REST endpoint

```typescript
import { describe, it, expect, beforeAll } from "vitest";
import { WpClient, createWpClient } from "./helpers/wp-client";

describe("ck/v1/projects", () => {
  let wp: WpClient;

  beforeAll(() => {
    wp = createWpClient();
  });

  it("returns project list", async () => {
    const res = await wp.rest("ck/v1/projects");
    expect(res.status).toBe(200);
  });
});
```

### Example: Testing an AJAX handler

```typescript
it("handles ck_get_project action", async () => {
  const res = await wp.ajax({ action: "ck_get_project", project_id: "123" });
  // Unauthenticated requests typically return 0 or a JSON error
  expect([200, 400]).toContain(res.status);
});
```
