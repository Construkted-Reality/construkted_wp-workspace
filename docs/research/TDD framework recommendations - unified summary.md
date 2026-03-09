# TDD Framework Recommendations — Unified Summary

## The Recommendation

| Repo | Test Framework | Key Dependencies |
|---|---|---|
| `construkted_api` | **Jest 30 + ts-jest** | supertest, aws-sdk-client-mock, nock, memfs |
| `construkted.js` | **Vitest 4.x** | jsdom/happy-dom, @vitest/coverage-v8, Playwright |
| `construkted_reality_v1.x` | **PHPUnit 9.6 + Brain Monkey 2.7** | Mockery, yoast/phpunit-polyfills, wp-phpunit |

All three repos have zero tests today. The framework choices are driven by module system compatibility (CJS vs ESM), existing build tooling, and ecosystem constraints. Each was arrived at independently in a dedicated research document and the conclusions converge.

**Universal adoption sequence:** Infrastructure (day 1) → pure functions (weeks 1-4) → characterization tests on critical paths (months 1-3) → enforce "test what you touch" on every PR → full TDD culture (months 6-12).

**The single most important rule across all three codebases:** characterize first, refactor under test coverage. Write tests that capture *current behavior* before changing anything. Michael Feathers' *Working Effectively with Legacy Code* is cited in all three research documents as the governing approach.

---

## Why These Frameworks and Not Others

**Jest for `construkted_api`** because the repo is CommonJS TypeScript. Jest was built for CJS — `jest.mock()` works perfectly with synchronous `require()`. This codebase has no dependency injection and relies on module-level mocking for `child_process.spawn`, AWS SDK v3, and `fs-extra`. Vitest is ESM-first and converts CJS internally, causing interop friction. Vitest's 2-10x speed advantage is irrelevant for a backend API where HTTP latency dominates test execution time.

**Vitest for `construkted.js`** because the repo is ESM TypeScript with Vite 5.4 already in the build pipeline. Vitest reads `vite.config.ts` directly — shared resolve aliases, plugins, and transforms with zero duplication. Native ESM and TypeScript support. 4-10x faster cold starts than Jest. Jest 30.x still treats ESM as experimental.

**PHPUnit 9.6 for `construkted_reality_v1.x`** because PHPUnit 10+ isn't compatible with WordPress core's test suite yet. Brain Monkey mocks WordPress functions without loading WordPress for fast unit tests. `WP_Ajax_UnitTestCase` handles integration testing of the 177 AJAX handlers. Pest PHP requires PHP 8.3+ (codebase targets PHP 7.1+). Codeception requires PHP 8.0+. There is no viable alternative.

**On using two different JS test frameworks:** the CJS/ESM module system boundary is the correct place to draw the framework boundary. Fighting Vitest's ESM-first design in a CJS codebase creates real pain. Vitest everywhere becomes viable only if `construkted_api` migrates to ESM — a non-trivial refactor not worth doing for test framework consistency alone.

---

## What to Test First in Each Repo

Every research document identifies a "zero-mocking" pure-function layer as the highest-value, lowest-effort starting target:

| Repo | Start Here (Zero Mocking Required) |
|---|---|
| `construkted_api` | `statusCodes.ts`, `utils.ts`, `bucketConfig.ts`, `bucketConfigMgr.ts`, command-construction functions for spawned binaries |
| `construkted.js` | Math algorithms (Kabsch, SVD), coordinate transforms, unit conversions (AngleUnits, DistanceUnits, AreaUnits, VolumeUnits), proj4/turf.js calculations, GeoJSON export, serialization |
| `construkted_reality_v1.x` | Constants, helper functions, data transformations, sanitization utilities |

**construkted.js** has the largest immediate surface: ~35-45% of its 257 files are unit-testable without any browser or WebGL context. Cesium math objects (Cartesian3, Matrix4, Transforms, etc.) and turf.js/proj4 run natively in Node.js.

---

## Converging Principles Across All Three Analyses

These conclusions were reached independently in each research document:

1. **Characterize before refactoring.** Write tests that document what code *currently does*, not what it should do. Fix bugs separately, after tests lock in behavior. This applies to the 1,223-line Task class, the 177 AJAX handlers, and the Cesium rendering code equally.

2. **Separate unit and integration suites.** Distinct `test:unit` and `test:integration` scripts everywhere. Unit tests run fast with zero infrastructure. Integration tests need:
   - `construkted_api`: Docker/MinIO for S3, test fixtures for binary formats
   - `construkted.js`: xvfb/Playwright for WebGL, GPU runners for visual regression
   - `construkted_reality_v1.x`: MySQL service containers, WordPress test suite bootstrap

3. **Phase 0 is infrastructure, not tests.** Get one passing test (`expect(true).toBe(true)` / `$this->assertTrue(true)`) running in CI before writing real tests. Remove all friction first.

4. **"Test what you touch" beats coverage targets.** Don't pursue coverage retroactively. Enforce tests on every PR that touches code. Coverage compounds naturally where it matters most.

5. **Same timeline everywhere.** Day 1-2 for infrastructure. Weeks 1-4 for pure functions. Months 1-3 for meaningful coverage on critical paths. Months 6-12 for full TDD culture.

---

## Full Toolchains

### construkted_api

```json
{
  "devDependencies": {
    "jest": "^30.2.0",
    "ts-jest": "^29.3.0",
    "@types/jest": "^29.5.0",
    "supertest": "^7.2.2",
    "@types/supertest": "^6.0.3",
    "aws-sdk-client-mock": "^4.0.2",
    "aws-sdk-client-mock-jest": "^4.1.0",
    "@smithy/util-stream": "^3.0.0",
    "nock": "^14.0.0",
    "memfs": "^4.0.0"
  }
}
```

### construkted.js

```
npm install -D vitest@^4.0 jsdom @vitest/coverage-v8
npm install -D playwright @playwright/test  # for integration/visual tests
```

Plus a partial Cesium mock (`__mocks__/cesium.ts`) that passes through real math types and mocks only WebGL-dependent types (Viewer, Scene, Camera).

### construkted_reality_v1.x

```json
{
  "require-dev": {
    "phpunit/phpunit": "^9.6",
    "brain/monkey": "^2.7",
    "yoast/phpunit-polyfills": "^3.0",
    "wp-phpunit/wp-phpunit": "^6.9"
  }
}
```

Mockery 1.6 is pulled automatically as a Brain Monkey dependency.

---

*Synthesized from:*
- *TDD adoption for a 3D asset processing Express API.md*
- *TDD for a WordPress theme SaaS platform.md*
- *TDD strategy for a CesiumJS-TypeScript 3D viewer library.md*
