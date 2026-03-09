# TDD for a WordPress/TypeScript/Node.js platform starting from zero

**Vitest unifies your TypeScript and Node.js testing, PHPUnit with Brain Monkey handles WordPress, and the entire stack can be running its first tests within a week.** The critical insight for this three-repo platform is sequencing: start with the Node.js API (smallest codebase, highest blast radius, fastest setup), then the TypeScript viewer library (Vite 5 makes Vitest near-zero config), and tackle WordPress last (most infrastructure overhead). Across all three repos, characterization tests — not aspirational unit tests — are the correct first move for a legacy codebase with zero test coverage. The approach below draws from Michael Feathers' legacy code patterns, current 2025–2026 tooling recommendations, and practical configurations specific to your stack.

---

## The WordPress repo demands a two-tier testing strategy

The PHP codebase presents the steepest setup challenge because it lacks Composer entirely. **Introducing Composer is the non-negotiable first step** — without it, there's no sane way to manage PHPUnit, Brain Monkey, PHPCS, or PHPStan. The `composer.json` should live in the theme root with all testing tools as `require-dev` dependencies, `vendor/` added to `.gitignore`, and no changes to the production deployment pipeline (the existing SSH-based `git pull` deploys won't touch `vendor/`).

The testing architecture splits into two tiers. **Fast unit tests** use `PHPUnit\Framework\TestCase` with Brain Monkey for mocking WordPress functions — no database, no WordPress bootstrap, executing in under two seconds. **Integration tests** use `WP_UnitTestCase` with the WordPress test suite, a real MySQL database, and transaction rollback after each test. Brain Monkey is the 2025 community favorite over WP_Mock for mocking `get_post_meta`, `WP_Query`, hooks, and filters — it handles WordPress hook assertions natively and is built on Mockery. For the **~20 direct `$wpdb` queries**, always use integration tests with a real database; mocking `$wpdb` for complex SQL is brittle and doesn't verify query correctness.

For the **100+ AJAX handlers**, WordPress provides `WP_Ajax_UnitTestCase` with `_handleAjax()`. A critical constraint: `_handleAjax()` can only be called once per test method, so each scenario needs its own method. The prioritization strategy is risk-based: test data-writing handlers first (those doing INSERT/UPDATE/DELETE), then WooCommerce checkout/order handlers (revenue-critical), then REST API endpoints (security-critical, only 6 of them, high ROI), and finally read-only handlers. Creating a catalog spreadsheet — handler name, file, writes data (Y/N), has nonce check (Y/N), tested (Y/N) — makes this manageable.

The REST API endpoints can be tested without HTTP calls by dispatching `WP_REST_Request` objects directly through `WP_REST_Server::dispatch()`. Custom `X-Api-Key` authentication is tested by setting headers on the request object:

```php
$request = new WP_REST_Request('GET', '/ck/v1/resource');
$request->set_header('X-Api-Key', 'valid-test-key');
$response = $this->server->dispatch($request);
$this->assertEquals(200, $response->get_status());
```

**Static analysis delivers immediate value without writing any tests.** PHPStan with the `szepeviktor/phpstan-wordpress` extension should start at **level 0** with a generated baseline (`phpstan analyse --generate-baseline`). The baseline stores all existing errors; only new code must pass. WordPress Core itself proposed adopting PHPStan in July 2025, validating it as the standard static analysis tool. PHPCS with the `WordPress-Extra` and `WordPress.Security` rulesets catches missing nonce verification and unsanitized input automatically — run on changed files only initially using `--filter=gitmodified`.

The GitHub Actions workflow runs four parallel jobs: PHPCS, PHPStan, unit tests (no database), and integration tests (with a MariaDB service container). Use `shivammathur/setup-php@v2` for PHP setup, `ramsey/composer-install@v3` for Composer caching, and `sjinks/setup-wordpress-test-library@master` for the WP test suite.

---

## Vitest is the obvious choice for the TypeScript viewer library

The 225,000-line TypeScript library already uses Vite 5 for development, making **Vitest the zero-config choice**. Vitest reuses the existing `vite.config.ts`, sharing plugins and configuration — Jest with Vite requires the separate `vite-jest` bridge with limitations. Performance is dramatic: real-world migrations report test suites going from **18.7 seconds to 1.8 seconds**. Vitest's API is 95% Jest-compatible, so most existing Jest examples and documentation translate directly. TypeScript 4.7.4 is fully compatible since Vitest uses esbuild for transpilation (20–30x faster than tsc), making the TypeScript version irrelevant for test execution speed.

The critical architectural decision is **what can be tested without WebGL**. CesiumJS's own test suite provides the answer: they separate tests into WebGL and non-WebGL categories, with non-WebGL tests running in ~15 seconds versus ~60 seconds for rendering tests. For this codebase, the breakdown is:

- **Testable in Node.js** (no browser needed): All coordinate math, proj4 transforms, Turf.js operations, Kabsch algorithm, data parsing, GeoJSON processing, configuration handling, state management logic, URL builders, type guards
- **Requires mocked objects**: Scene setup, entity management, CesiumJS wrapper code, layer management
- **Requires real browser**: WebGL rendering, shader compilation, camera interaction, picking, mouse events on 3D canvas, visual regression screenshots

For geospatial calculations, **property-based testing with fast-check** is exceptionally powerful. Testing mathematical invariants — roundtrip preservation (forward then inverse transform ≈ identity), distance preservation for rigid transforms (Kabsch), determinant = 1 for rotation matrices — catches edge cases that example-based tests miss. A single property-based test replaces dozens of individual assertions:

```typescript
fc.assert(fc.property(
  fc.double({min: -180, max: 180}),
  fc.double({min: -85, max: 85}),
  (lon, lat) => {
    const forward = proj4('EPSG:4326', 'EPSG:3857', [lon, lat]);
    const back = proj4('EPSG:3857', 'EPSG:4326', forward);
    return Math.abs(back[0] - lon) < 1e-6 && Math.abs(back[1] - lat) < 1e-6;
  }
));
```

CesiumJS mock fixtures should be lightweight objects satisfying the type interface without WebGL. Create a shared `tests/fixtures/cesium-mocks.ts` with `createMockViewer()`, `createMockScene()`, `createMockCamera()`, and `createMockCartesian3()` factory functions. Crucially, **Cesium math types (Cartesian3, Matrix4, Transforms) work fine in Node.js** — only Viewer/Scene/rendering need mocks.

For DOM testing, **jsdom** is preferred over happy-dom for this codebase because jQuery exercises many DOM APIs where jsdom's completeness matters. Use Vitest's `environmentMatchGlobs` to run pure math tests in Node (fastest) and DOM tests in jsdom:

```typescript
environmentMatchGlobs: [
  ['**/math/**', 'node'],
  ['**/utils/**', 'node'],
  ['**/dom/**', 'jsdom'],
]
```

For integration/E2E testing of actual CesiumJS rendering, **Playwright with `--use-gl=swiftshader`** provides software WebGL rendering without requiring a GPU, working reliably in CI. CesiumJS itself uses Playwright for E2E and screenshot comparison tests.

Realistic coverage targets: pure math/geometry at **90–100%**, data parsing at **85–95%**, CesiumJS integration at **30–50%**, Three.js rendering at **20–40%**. Start thresholds at 5% and increase by 5% per sprint. CesiumJS achieves 90% coverage with 263,000 lines of test specs, but that represents a decade of investment — treat it as an aspirational ceiling, not a near-term target.

---

## The Node.js API is the fastest win and should be tested first

With only ~20 TypeScript files, `construkted_api` is the smallest codebase but carries the highest blast radius — a bug in the asset processing pipeline (S3 download → extract → validate → tile → upload → notify WordPress) corrupts data across the entire platform. **Vitest + Supertest** is the recommended stack, matching the TypeScript library's framework for consistency.

The single most important refactor before writing any test is **separating Express app creation from `app.listen()`**. Without this, Supertest cannot work:

```typescript
// src/app.ts — exports Express app (no listen)
export function buildApp() {
  const app = express();
  // ... routes, middleware ...
  return app;
}

// src/server.ts — starts listening (production entry)
import { buildApp } from './app';
buildApp().listen(3000);
```

For **AWS S3 mocking**, `aws-sdk-client-mock` is the clear winner — officially recommended by the AWS SDK team, fully typed, supports command-level mocking, sequential responses, and error simulation. LocalStack (Docker-based) is the secondary option for integration tests requiring real S3 API behavior, managed via the `testcontainers` npm package for automatic lifecycle management.

**Child process testing** requires a `ProcessRunner` abstraction wrapping `child_process.spawn`. Inject this into pipeline steps via constructor injection. For tests, provide a `MockProcessRunner` returning configurable EventEmitter instances. This supports testing error cases (ENOENT for missing binaries, non-zero exit codes, stderr output, timeouts) without spawning real processes:

```typescript
function createMockChildProcess(exitCode = 0, stdout = '', stderr = '') {
  const cp = new EventEmitter();
  cp.stdout = new EventEmitter();
  cp.stderr = new EventEmitter();
  process.nextTick(() => {
    if (stdout) cp.stdout.emit('data', Buffer.from(stdout));
    cp.emit('close', exitCode);
  });
  return cp;
}
```

For the **task queue with parallelism limits**, test concurrency by tracking simultaneous executions and asserting the max never exceeds the configured limit. Test FIFO ordering, error propagation (one failed task shouldn't stop the queue), and drain/empty events.

**File system testing** uses `memfs` with `vol.fromNestedJSON()` for unit tests and real temporary directories (`mkdtempSync` + cleanup in `afterEach`) for integration tests. The archive extraction itself (7z) is mocked at the child process level; memfs validates post-extraction file operations.

The all-GET-for-mutations API design is tested by **asserting side effects explicitly** — verify queue additions, S3 operations, and WordPress notification calls. A gradual migration strategy adds POST equivalents alongside GETs, deprecates GET mutations with logged warnings, then removes them once clients migrate.

For **outbound HTTP mocking** (WordPress notification callbacks), Nock is simpler for pure Node.js API testing. A notable 2025 development: Nock now uses MSW's `@mswjs/interceptors` under the hood, unifying the Node.js HTTP mocking ecosystem.

---

## Cross-cutting strategy: characterization tests, contract testing, and coordinated multi-repos

**Characterization tests are the correct first move**, not unit tests. A characterization test captures actual behavior — not desired behavior — as a safety net before any refactoring. The algorithm: put code in a test harness, write an assertion you know will fail, let the failure tell you the actual behavior, change the assertion to match. Mark Seemann (2025) emphasizes writing a deliberately failing test first as a falsifiable experiment to avoid tautological assertions. For this platform, characterization tests at HTTP boundaries (REST endpoints, AJAX handlers, API routes) give maximum safety net with minimum effort.

**Contract testing between repos is critical** because three independent repositories communicate via HTTP. Pact is the recommended framework — it's consumer-driven, language-agnostic, and has libraries for both PHP (`pact-php`) and JavaScript/TypeScript (`pact-js`). The phased approach: start with JSON Schema validation for all inter-service endpoints, implement Pact consumer tests in `construkted.js` for WordPress endpoints, add Pact provider verification in the WordPress and API repos, then set up a Pact Broker with `can-i-deploy` checks in CI.

**Keep the three repos separate** rather than merging into a monorepo. Three fundamentally different tech stacks (PHP vs TypeScript vs Node.js) with different build tools, test runners, and deployment models don't benefit from monorepo tooling overhead. Instead, use a "coordinated multi-repo" approach: shared ESLint config for both TypeScript repos via an npm package, GitHub Actions reusable workflows, Pact Broker as the contract testing glue, and SonarCloud for unified code quality dashboards.

**Risk-based prioritization across repos** follows the formula Risk = Likelihood × Impact. Tier 1 (test first): WordPress ↔ API HTTP callbacks, authentication flows, data mutation logic. Tier 2: AJAX handlers consumed by the viewer library, core API business logic, the TypeScript library's public API surface. Tier 3: UI rendering logic, template rendering, configuration management. Tier 4 (test when touched): static content, internal utilities, logging.

The most effective ongoing strategy is **bug-driven testing**: convert every production bug into a test before fixing it. This naturally builds coverage in the areas that break most. Research suggests risk-based testing achieves **95% defect coverage while cutting low-risk testing by 40%** compared to traditional approaches.

---

## Recommended tool matrix

| Purpose | WordPress Theme (PHP) | TypeScript Viewer Library | Node.js API |
|---|---|---|---|
| **Test runner** | PHPUnit 9.x + Yoast Polyfills | Vitest 4.x | Vitest 4.x |
| **Unit test mocking** | Brain Monkey + Mockery | `vi.mock()`, `vi.fn()`, `vi.spyOn()` | `vi.mock()`, `vi.fn()` |
| **Integration testing** | WP_UnitTestCase (real DB) | Playwright (WebGL) | Supertest (HTTP) |
| **HTTP mocking** | `pre_http_request` filter | MSW or `vi.spyOn(jQuery, 'ajax')` | Nock |
| **AWS mocking** | N/A | N/A | aws-sdk-client-mock |
| **FS mocking** | N/A | N/A | memfs |
| **DOM environment** | N/A | jsdom (via Vitest) | N/A |
| **Property testing** | N/A | fast-check | N/A |
| **Coverage** | Xdebug + PHPUnit `--coverage-clover` | Vitest V8 provider | Vitest V8 provider |
| **Static analysis** | PHPStan (level 0 → 3) + PHPCS | TypeScript `tsc --noEmit` | TypeScript `tsc --noEmit` |
| **Linting** | PHPCS (WordPress Coding Standards) | ESLint + Prettier | ESLint + Prettier |
| **Pre-commit** | GrumPHP or Husky | Husky + lint-staged (re-enable) | Husky + lint-staged |
| **Coverage reporting** | SonarCloud | SonarCloud | SonarCloud |
| **Contract testing** | pact-php (provider) | pact-js (consumer) | pact-js (provider) |
| **CI** | GitHub Actions + `shivammathur/setup-php` + MariaDB service | GitHub Actions + `setup-node` | GitHub Actions + `setup-node` |

---

## Phased implementation plan with effort estimates

**Phase 0 — Quick wins with zero test infrastructure (Week 1, ~8 hours total).** Re-enable the Husky pre-commit hook in `construkted.js` by uncommenting it and adding lint-staged configuration (~30 minutes). Add PHPCS + PHPStan to the WordPress theme via Composer init — use PHPStan level 0 with a generated baseline so only new code must pass (~3 hours). Add `tsc --noEmit` type checking to the Node.js API build (~30 minutes). Add `.editorconfig` to all three repos (~15 minutes). These changes deliver immediate value — catching bugs and enforcing standards — before a single test exists.

**Phase 1 — Node.js API tests (Weeks 2–3, ~20 hours).** Install Vitest + Supertest. Refactor the app/server separation (the single riskiest step; estimate 2–4 hours). Write a health check endpoint test to prove the pipeline works. Write 10 integration tests covering the main asset pipeline happy path, error cases for malformed requests, and task queue logic. Add GitHub Actions CI running tests on every PR. **This repo goes first** because it's the smallest (~20 files), has the highest data-corruption risk, and delivers the fastest confidence boost.

**Phase 2 — TypeScript library tests (Weeks 3–5, ~16 hours).** Install Vitest (near-zero config with existing Vite 5). Write 10 unit tests targeting pure utility functions first: coordinate transforms, proj4 wrappers, Turf.js operations, data parsing, configuration validators. Add fast-check property-based tests for the Kabsch algorithm and coordinate roundtrips. Add coverage reporting with V8 provider, starting thresholds at 5%. Add GitHub Actions CI. Re-enable Husky with `vitest related --run` in pre-commit for changed files only.

**Phase 3 — WordPress theme tests (Weeks 5–8, ~35 hours).** Introduce Composer to the repo. Set up PHPUnit with the WordPress test suite and a local MySQL test database. Write 5 smoke tests: theme activation without fatal errors, the simplest read-only REST endpoint, one critical data-writing AJAX handler. Write 5 more tests for the WooCommerce checkout flow and the highest-risk `$wpdb` queries. Add GitHub Actions CI with a MariaDB service container running integration tests on PRs.

**Phase 4 — Maturity and contract testing (Weeks 8–12, ongoing).** Institute the "test what you touch" policy: every bug fix and every new feature gets tests. Define JSON Schemas for all inter-service API contracts. Implement Pact consumer tests in `construkted.js`. Gradually increase PHPStan from level 0 toward level 3. Add Playwright E2E tests for critical 3D viewer scenarios using `--use-gl=swiftshader`. Set up SonarCloud for all three repos. Target **20% meaningful coverage** across repos by week 12 — not 80%, which leads to trivial tests that add no value.

| Milestone | Target Date | Deliverable |
|---|---|---|
| All repos have linting/static analysis in CI | Week 1 | PHPCS, PHPStan baselines, ESLint |
| API repo has 10+ tests in CI | Week 3 | Vitest + Supertest pipeline |
| TS library has 10+ tests in CI | Week 5 | Vitest with geospatial tests |
| WP theme has 10+ tests in CI | Week 8 | PHPUnit + WP test suite |
| "Test what you touch" is habitual | Week 12 | All new code ships with tests |

---

## The five biggest risks and how to avoid them

**Test fatigue is the number one risk.** Teams introducing testing to legacy codebases frequently abandon the effort within weeks. Mitigation: keep tests fast (under 5 seconds for unit suites), run them automatically in CI, start embarrassingly small (one test per repo), and celebrate the first green CI run. Don't set unrealistic coverage targets — **30% meaningful coverage vastly outperforms 80% trivial coverage**.

**WordPress environment setup is notoriously finicky.** The `install-wp-tests.sh` script downloads WordPress to `/tmp/` which gets cleared on reboot. PHPUnit version compatibility between PHP 7 and PHP 8 requires the Yoast Polyfills library — the most common error is `Call to undefined method PHPUnit\Util\Test::parseTestMethodAnnotations()`. Budget 4–8 hours for initial WordPress test infrastructure, and expect frustration.

**WebGL is unavailable in Node.js testing environments.** `THREE.WebGLRenderer` and `Cesium.Viewer` will throw immediately. Do not attempt to test rendering in unit tests. The `headless-gl` package doesn't support WebGL2 (Three.js dropped WebGL1 in v0.163). Mock these modules aggressively and reserve rendering tests for Playwright E2E with software rendering.

**The app/server coupling in the Node.js API** will block Supertest if `app.listen()` is called at import time. This refactor — separating `buildApp()` from the server startup — is required and is the single highest-risk code change in Phase 1. Write a characterization test of the existing API behavior before making this change.

**Over-mocking destroys test value.** Mocking every dependency makes tests tautological — they verify that your mocking framework works, not that your code works. Prefer integration tests with real databases for WordPress, real file operations for the API's file processing, and real Cesium math types (which work fine in Node.js) for coordinate calculations. Mock only at true external boundaries: S3, child processes, outbound HTTP calls.