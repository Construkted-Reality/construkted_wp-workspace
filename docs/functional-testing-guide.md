# Functional Testing Guide — Construkted Reality Platform

## 1. Overview

This guide covers **functional testing** — verifying that features work as expected through HTTP requests, browser automation, and manual validation. It is not about TDD methodology or unit testing philosophy; those are covered elsewhere.

**Purpose:** Provide a single reference for running, extending, and planning functional tests across all four repos and the WordPress environment.

**Audience:** Developers and AI agents working on the Construkted Reality platform. Agents should treat the commands, paths, and procedures here as authoritative.

---

## 2. Test Classification

Every test in this project falls into one of three classes. The classification determines who can run it, what infrastructure it needs, and how results are interpreted.

### Class 1: Agent-Executable Tests

Tests that AI agents can write, run, and interpret without human involvement.

**Characteristics:**
- Deterministic inputs and outputs
- Binary pass/fail — no ambiguity in results
- No visual assessment required
- No manual authentication steps
- Run in terminal or CI

**Examples:** API parameter validation, response shape verification, WP REST endpoint contracts, PHP pure unit tests, config structure validation.

### Class 2: Automated Tests, Human-Triggered

Tests that execute automatically once started, but require a human to initiate, set up prerequisites, or interpret ambiguous results.

**Characteristics:**
- Requires a running environment (DDEV + API server)
- May need test data, auth credentials, or environment variables
- Results are usually deterministic, but setup is not

**Examples:** WP AJAX handlers that modify data (need a safe test dataset), CesiumJS viewer initialization checks via Playwright, upload flow smoke tests, cross-repo ping tests, database state verification after test runs.

**Migration path:** Some Class 2 tests migrate to Class 1 as test data fixtures and auth mechanisms are automated.

### Class 3: Human-Only Tests

Tests that require human perception, judgment, or real-world interaction.

**Characteristics:**
- Visual correctness, UX feel, performance perception
- Cannot be meaningfully automated
- Documented as manual checklists, not scripts

**Examples:** 3D model visual correctness, annotation placement accuracy, upload UX flow, mobile/tablet viewer experience, PDF export quality, camera navigation feel, permission edge cases with role-switching.

---

## 3. What's Built

### Layer 1: API HTTP Functional Tests

**Location:** `construkted_api/tests/endpoints.test.ts`

**Run:**
```bash
cd construkted_api && npm test
```

**What it tests:** All Express API endpoints — parameter validation, response shapes, URL whitelist enforcement, enum validation, task lifecycle queries. 24 HTTP-level functional tests plus bucket config structure tests.

**How it works:** Uses `supertest` to make HTTP requests against the Express app in-process. The app is imported directly — no server is bound to a port. Side effects are prevented by mocking `TaskManager`, `Task`, `runAwsRemove`, `request-promise`, and `logger` via `vi.mock()`.

**How to add tests:**
1. Create a new `.test.ts` file in `construkted_api/tests/`.
2. Import the app: `import app from "../app";`
3. Use the supertest pattern:
   ```typescript
   import request from "supertest";
   import app from "../app";

   describe("Your endpoint", () => {
     it("should return expected response", async () => {
       const res = await request(app).get("/your-endpoint");
       expect(res.status).toBe(200);
     });
   });
   ```
4. Mock any external dependencies that would cause side effects.

**Agent instructions:** Run `cd construkted_api && npm test`. All tests should pass. If any fail, the Vitest output identifies the exact endpoint and assertion that failed. No environment setup is needed — these tests run entirely in-process.

---

### Layer 2a: WordPress External HTTP Tests

**Location:** `tests/wordpress/`

**Run:**
```bash
cd tests && NODE_TLS_REJECT_UNAUTHORIZED=0 npm test
```

**Run WordPress tests only:**
```bash
cd tests && NODE_TLS_REJECT_UNAUTHORIZED=0 npm run test:wordpress
```

**Prerequisites:**
- DDEV must be running: `cd wordpress && ddev start`
- Verify with: `cd wordpress && ddev status`

**What it tests:** WordPress reachability (homepage, wp-login), REST API availability (wp-json index), AJAX endpoint behavior (admin-ajax.php). Currently 4 smoke tests.

**WpClient helper** (`tests/wordpress/helpers/wp-client.ts`):
- `get(path)` — GET request to the WordPress site
- `post(path, body)` — POST request
- `ajax({action: "handler_name", ...params})` — POST to `admin-ajax.php`
- `rest("ck/v1/endpoint")` — GET/POST to the WP REST API
- Handles DDEV self-signed certs, `WP_DEBUG` PHP notices embedded in JSON responses, cookie auth, and application passwords

**Environment variables:**
| Variable | Default | Purpose |
|---|---|---|
| `WP_TEST_URL` | `https://construkted-develop-01.ddev.site` | Base URL of the WordPress instance |
| `WP_APP_PASSWORD` | (none) | Base64-encoded `user:password` for authenticated requests |

**How to add tests:**
1. Create a new `.test.ts` file in `tests/wordpress/`.
2. Import the client:
   ```typescript
   import { createWpClient } from "./helpers/wp-client";
   const wp = createWpClient();
   ```
3. Write tests using the WpClient methods. See `tests/wordpress/smoke.test.ts` for examples.
4. For authenticated tests, set the `WP_APP_PASSWORD` env var or pass cookies to the WpClient constructor.

**Agent instructions:** Before running tests, verify DDEV is running with `cd wordpress && ddev status`. If DDEV is stopped, an agent cannot start it without human confirmation (Class 2). Once running, execute the test command. Smoke tests verify infrastructure — if they fail, the WordPress environment itself is down, not the application code.

**Why `NODE_TLS_REJECT_UNAUTHORIZED=0`:** DDEV uses self-signed SSL certificates. Node.js rejects these by default. This flag disables TLS verification for the test run only.

---

## 4. What's Documented but Not Built

### Layer 2b: WordPress PHPUnit Integration Tests

**Status:** NOT BUILT. The current PHPUnit setup (`construkted_reality_v1.x/phpunit.xml`) runs unit tests only. The bootstrap file (`tests/bootstrap.php`) explicitly does not load WordPress.

**What exists now:**
```bash
cd construkted_reality_v1.x && composer test
```
This runs PHPUnit 10.5 against `tests/Unit/`. Currently contains only `ExampleTest.php` (placeholder).

**What full WP integration testing would require:**
1. Install the WordPress test suite (`wp-scaffold` or manual setup)
2. Create a dedicated test database (separate from the dev database)
3. Rewrite `tests/bootstrap.php` to load WordPress's test framework (`includes/functions.php` + `tests/phpunit/includes/bootstrap.php`)
4. Create `wp-tests-config.php` with test database credentials
5. Each test runs in a database transaction that rolls back automatically

**When to build:** If Layer 2a external HTTP tests prove insufficient for testing PHP-level logic (validation functions, data transformations, hooks) in isolation.

**Effort estimate:** 1–2 days for initial setup, plus ongoing maintenance of the WP test framework compatibility.

---

### Layer 3: Browser/E2E Tests (Playwright)

**Status:** NOT BUILT.

**Initial setup:**
1. Install Playwright in the `tests/` directory: `npm init playwright`
2. Configure base URL to point at the DDEV instance
3. Create a dedicated test user account for authentication
4. First test target: login → dashboard → verify key elements present

**Key challenges:**

| Challenge | Detail |
|---|---|
| WebGL/CesiumJS | Playwright's Chromium supports WebGL in headless mode, but CesiumJS initializes asynchronously and loads tiles from S3. Tests must wait for viewer-ready events and handle missing tile data gracefully. |
| Upload flow | Multi-minute async workflow spanning API + S3 + tiling tools. Only viable as a smoke test, not a fast feedback loop. |
| Test data stability | Tests depend on specific projects/assets/albums existing. If someone deletes them, tests break. Need fixtures or seed scripts. |
| Visual regression for WebGL | **Don't do it.** Renders vary by GPU, driver, and OS. The maintenance burden exceeds the value. |

**Effort estimate:** Half a day for a login smoke test. 1–2 days for a meaningful CesiumJS viewer test.

---

### Layer 4: Cross-Repo Integration Tests

**Status:** NOT BUILT. Documented as a manual smoke test procedure.

**The integration flow:**
```
WordPress (upload) → construkted_api (request_tiling) → S3 download → tiling tools → S3 upload → callback to WordPress (control_asset_details.php)
```

**Why not automated:** Steps 2–4 involve external tools (UltraMesh, Cesium tiling pipeline) and real S3 buckets. These cannot run in a fast test loop. Mocking the entire pipeline would simulate the system rather than test it — pointless.

**Pragmatic approach:** Test contract boundaries separately. Layer 1 tests verify API contracts. Layer 2a tests verify WordPress contracts. If both boundary test suites pass, the integration works correctly *as long as the wire between them works*. The manual smoke test below verifies the wire.

**Manual smoke test procedure:**

1. **Verify infrastructure:** Ensure both DDEV (`cd wordpress && ddev status`) and the API server (`curl http://localhost:5000/`) are running.
2. **Verify shared-secret auth:**
   ```bash
   curl https://API_HOST:5000/ping?wPServerUrl=YOUR_WP_URL
   ```
   Expected: 200 OK with valid response.
3. **Upload a test file:** Use the WordPress upload form to submit a small test file (e.g., a .las or .obj under 50MB).
4. **Monitor tiling task:**
   ```bash
   curl https://API_HOST:5000/task/all
   ```
   Watch for the task to appear and progress through states.
5. **Verify WordPress update:** Confirm the WordPress post meta is updated when tiling completes (check the asset detail page in wp-admin).
6. **Verify viewer rendering:** Load the processed asset in the CesiumJS viewer. Confirm it renders without errors.

---

## 5. Quick Reference

| Test Layer | Run Command | Location | Class | Status |
|---|---|---|---|---|
| API unit + functional tests | `cd construkted_api && npm test` | `construkted_api/tests/` | 1 (Agent) | Built |
| JS viewer unit tests | `cd construkted.js && npm test` | `construkted.js/tests/` | 1 (Agent) | Built |
| Upload.js unit tests | `cd construkted.uploadjs && npm test` | `construkted.uploadjs/tests/` | 1 (Agent) | Built |
| PHP unit tests | `cd construkted_reality_v1.x && composer test` | `construkted_reality_v1.x/tests/` | 1 (Agent) | Built |
| WP HTTP functional tests | `cd tests && NODE_TLS_REJECT_UNAUTHORIZED=0 npm test` | `tests/wordpress/` | 2 (Human-triggered) | Built |
| WP PHPUnit integration | *(not built)* | `construkted_reality_v1.x/tests/` | 2 | Documented |
| Browser E2E (Playwright) | *(not built)* | `tests/e2e/` (planned) | 2 | Documented |
| Cross-repo integration | *(manual)* | N/A | 3 (Human-only) | Documented |

All paths are relative to `/home/outsider/Projects/Construkted_Reality/code/web/dev-site-01/`.

---

## 6. Manual Test Checklist (Class 3)

These tests require human judgment. Run them before releases or after significant changes to the affected areas.

### 3D Viewer (CesiumJS)

- [ ] Globe renders without console errors
- [ ] 3D model loads and displays correctly (point cloud, mesh, 3D tiles)
- [ ] Camera navigation feels smooth (orbit, zoom, pan)
- [ ] FPV (first-person view) navigation works naturally
- [ ] Annotations render at correct positions on the 3D surface
- [ ] Annotation tools work correctly (create, edit, delete)
- [ ] Sidebar panels open/close and display correct data
- [ ] XR mode initializes (if applicable)

### Upload Flow

- [ ] Upload form renders correctly
- [ ] File selection works (drag-and-drop and file picker)
- [ ] Progress bar updates during upload
- [ ] Large file upload (>500MB) completes without timeout
- [ ] Upload cancellation works mid-upload
- [ ] Error states display correctly (wrong file type, file too large, network error)

### Project/Asset Management

- [ ] Create new project — form submits, project appears in dashboard
- [ ] Edit project metadata — changes persist after page reload
- [ ] Delete project — removed from dashboard, associated assets cleaned up
- [ ] Asset publishing — visibility changes correctly (public/private)
- [ ] Album management — create, edit, delete albums; add/remove assets from albums

### User Permissions

- [ ] Viewer role can view but not edit
- [ ] Editor role can edit but not delete others' content
- [ ] Admin has full access to all operations
- [ ] Sharing controls work correctly (public, private, shared with specific users)

### Cross-Browser / Device

- [ ] Chrome (desktop) — full functionality
- [ ] Firefox (desktop) — viewer renders, basic functionality works
- [ ] Safari (desktop) — viewer renders
- [ ] iOS Safari — responsive layout, touch navigation
- [ ] Chrome Android — responsive layout, touch navigation
