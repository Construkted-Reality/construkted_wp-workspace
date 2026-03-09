# TDD strategy for a CesiumJS/TypeScript 3D viewer library

**Vitest 4.x is the right test framework, and roughly 35–45% of your 257-file codebase is immediately unit-testable without any browser or WebGL context.** The remaining rendering and interaction code requires a layered strategy: mock Cesium's WebGL-dependent objects while using real Cesium math types, run integration tests via Playwright with `xvfb` on standard GitHub Actions runners, and accept that visual regression and structured manual testing will cover what unit tests cannot. CesiumJS's own test suite — 13,500+ specs across 263K lines of test code — provides a battle-tested playbook for exactly this architecture. The most important rule for a zero-test codebase: start with pure functions today, enforce "test what you touch" on every PR, and ratchet coverage upward quarterly.

---

## Vitest 4.x wins decisively for this stack

**Vitest is the 2025–2026 consensus recommendation for new TypeScript projects**, and your existing Vite 5.4 in the build pipeline makes this choice even clearer. The State of JS 2024 survey shows Vitest overtaking Jest in developer satisfaction. Benchmarks demonstrate **4–10× faster cold starts** and watch-mode response times of 380ms versus Jest's 3.4 seconds. Jest 30.x still treats ESM as experimental; Vitest handles ESM and TypeScript natively with zero configuration — no `ts-jest`, no `@swc/jest`, no Babel.

The Vite integration matters. Vitest automatically reads your `vite.config.ts`, sharing resolve aliases, plugins, and transforms. Jest would require manually duplicating every path alias in `moduleNameMapper`. Your `isolatedModules: true` setting aligns perfectly with Vitest's esbuild-based transform pipeline, which compiles each file independently by design.

**The fact that Rollup 2.53 (not Vite) is the primary build tool is irrelevant.** Vitest uses Vite only as the test runner's transform layer, not as a replacement for your production bundler. The Vitest docs explicitly state: "Even if your library is built with esbuild or Rollup, Vitest is an interesting option." Your Rollup, Gulp, and Vite build configs remain completely untouched.

Recommended configuration:

```typescript
// vitest.config.ts
import { defineConfig, mergeConfig } from 'vitest/config';
import viteConfig from './vite.config';

export default mergeConfig(viteConfig, defineConfig({
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./tests/setup.ts'],
    include: ['src/**/*.test.ts', 'tests/**/*.test.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html', 'lcov'],
      include: ['src/**/*.ts'],
      exclude: ['src/**/*.d.ts', 'src/**/*.test.ts'],
    },
  },
}));
```

Install: `npm install -D vitest@^4.0 jsdom @vitest/coverage-v8`

---

## CesiumJS's own test suite is the authoritative playbook

CesiumJS uses **Jasmine + Karma** for unit tests and **Playwright + Sinon** for E2E tests. The test codebase is larger than the engine itself: **263K lines of test code versus 218K lines of source**. Their architecture provides the key insight your project needs.

**CesiumJS separates tests into two categories.** Non-WebGL tests (math, data sources, imagery providers) constitute the bulk of the suite and run in ~15 seconds without any GPU. WebGL tests (Viewer, Scene, Camera, rendering primitives) require a context and take ~60 seconds. For CI environments without GPUs, CesiumJS provides a `getWebGLStub` utility that makes all WebGL calls no-ops, enabling full code coverage of non-rendering logic.

**Cesium math objects work perfectly in Node.js without a browser.** Cartesian3, Matrix4, Quaternion, BoundingSphere, Color, JulianDate, Ellipsoid, Transforms, and all utility functions run as pure JavaScript. The `gltf-pipeline` project by CesiumGS uses `require('cesium')` in Node.js for these types without any browser dependency. This means your coordinate transformation code, measurement calculations, and geometry operations can be tested with **zero mocking**.

```typescript
// Works directly in Vitest — no WebGL, no mocking needed
import { Cartesian3, Matrix4, Transforms, Ellipsoid, Math as CesiumMath } from 'cesium';

describe('coordinate transforms', () => {
  it('converts degrees to cartesian', () => {
    const result = Cartesian3.fromDegrees(-75.59777, 40.03883);
    expect(result.x).toBeDefined();
    expect(typeof result.x).toBe('number');
  });

  it('computes distance between points', () => {
    const a = new Cartesian3(1, 0, 0);
    const b = new Cartesian3(0, 1, 0);
    expect(Cartesian3.distance(a, b)).toBeCloseTo(Math.SQRT2, 10);
  });
});
```

**What requires WebGL:** Viewer, Scene, Camera, CesiumWidget, and anything in the rendering pipeline. Entity objects can be *constructed* as data objects but cannot render. BillboardCollection can be instantiated and items added, but the `update` cycle needs a Scene/Context.

CesiumJS shares WebGL contexts across test suites using `beforeAll`/`afterAll` to avoid the cost of repeated context creation and browser-imposed context limits. Tests clean up between runs with `scene.primitives.removeAll()` in `afterEach`.

Key references: CesiumJS's [Testing Guide](https://github.com/CesiumGS/cesium/blob/main/Documentation/Contributors/TestingGuide/README.md), their `Specs/getWebGLStub.js` utility, and the `packages/widgets/Specs/createViewer.js` helper.

---

## Three-tier mocking strategy for Cesium-dependent code

### Tier 1: Use real Cesium math types — no mocking

For any code that only touches Cartesian3, Matrix4, Color, JulianDate, Transforms, or similar pure-math types, import them directly. These are fast, deterministic, and their computations are exactly what you want to verify.

### Tier 2: Partial mocks with `__mocks__/cesium.ts`

This is the pattern Resium (the React CesiumJS wrapper) uses. Resium's maintainers note: "Cesium cannot be loaded in Jest because it deeply depends on Web APIs (WebWorker, WebGL). Creating stubs is required."

```typescript
// __mocks__/cesium.ts
const actualCesium = await vi.importActual<typeof import('cesium')>('cesium');

// Pass through all pure-math types unchanged
export const Cartesian3 = actualCesium.Cartesian3;
export const Matrix4 = actualCesium.Matrix4;
export const Color = actualCesium.Color;
export const JulianDate = actualCesium.JulianDate;
export const defined = actualCesium.defined;
export const defaultValue = actualCesium.defaultValue;
export const Math = actualCesium.Math;

// Mock only the WebGL-dependent types
export const Viewer = vi.fn().mockImplementation(() => ({
  scene: {
    primitives: { add: vi.fn(), remove: vi.fn(), removeAll: vi.fn() },
    camera: {
      position: new actualCesium.Cartesian3(),
      direction: new actualCesium.Cartesian3(0, 0, -1),
      flyTo: vi.fn(), setView: vi.fn(), lookAt: vi.fn(),
    },
    globe: { depthTestAgainstTerrain: false },
    requestRender: vi.fn(),
  },
  entities: { add: vi.fn(), remove: vi.fn(), removeAll: vi.fn(), values: [] },
  dataSources: { add: vi.fn(), remove: vi.fn() },
  canvas: document.createElement('canvas'),
  destroy: vi.fn(),
  isDestroyed: vi.fn().mockReturnValue(false),
}));
```

### Tier 3: Dependency injection for long-term testability

The most architecturally sound approach. Instead of importing Cesium directly in business logic, inject it:

```typescript
// Production code — accepts dependency with default to global
class AnnotationManager {
  constructor(private cesium: typeof Cesium = window.Cesium) {}

  addMarker(lng: number, lat: number) {
    return this.cesium.Cartesian3.fromDegrees(lng, lat);
  }
}

// Test code — no Cesium needed
const mockCesium = {
  Cartesian3: { fromDegrees: vi.fn((lng, lat) => ({ x: lng, y: lat, z: 0 })) }
};
const manager = new AnnotationManager(mockCesium as any);
```

This refactoring is minimal (add a constructor parameter with a default value) and makes every consumer trivially testable.

---

## Three.js and WebXR testing patterns

Three.js uses **QUnit** and separates tests identically to CesiumJS: non-rendering tests run in Node.js, rendering tests run in the browser. For E2E tests, Three.js uses **Puppeteer** to screenshot all examples and compare against references.

**Scene, Camera, Vector3, Matrix4, BufferGeometry, Material subclasses, Raycaster, AnimationMixer, and the entire math stack all work without WebGL.** Only `WebGLRenderer` requires a context. For your Three.js 0.152 WebXR module, the vast majority of scene graph logic and math is testable in pure Node.js.

When you do need a renderer in tests, use **headless-gl** with WebGL2 shims:

```typescript
import createWebGLContext from 'gl';
const gl = createWebGLContext(512, 512);
Object.assign(gl, {
  texImage3D: () => {}, createVertexArray: () => {},
  bindVertexArray: () => {}, deleteVertexArray: () => {},
});
const renderer = new WebGLRenderer({ context: gl, canvas: mockCanvas });
```

For WebXR testing, Meta's **Immersive Web Emulation Runtime (IWER)** is the standard tool. It emulates the full WebXR Device API — sessions, reference spaces, controllers, hand tracking — and provides an `ActionRecorder/ActionPlayer` for deterministic replay of recorded headset sessions.

---

## Browser APIs, jQuery, and WordPress globals

**Neither jsdom nor happy-dom supports WebGL.** Both return `null` from `canvas.getContext('webgl')`. Use **happy-dom** for fast unit tests (7× faster than jsdom) and Playwright for anything requiring real WebGL. Vitest supports per-file environment switching with `// @vitest-environment happy-dom` at the top of individual test files.

For WebGL context mocking in unit tests, use `vitest-webgl-canvas-mock` or build a manual mock that patches `HTMLCanvasElement.prototype.getContext`. For `requestAnimationFrame` testing, Vitest's fake timers provide built-in `vi.advanceTimersToNextFrame()`. For `MediaRecorder`, create a global mock class in your setup file.

**jQuery should be loaded as a real dependency, not mocked.** It operates on jsdom's DOM, and mocking it defeats the purpose of testing DOM manipulation. Mock only `$.ajax` for network calls:

```typescript
vi.spyOn($, 'ajax').mockImplementation((settings: any) => {
  settings.success?.({ status: 'ok', data: 'mock-response' });
  return $.Deferred().resolve().promise() as any;
});
```

WordPress globals are straightforward:

```typescript
// tests/setup.ts
vi.stubGlobal('CONSTRUKTED_AJAX', {
  ajax_url: 'http://localhost/wp-admin/admin-ajax.php',
  nonce: 'test-nonce-12345',
  plugin_url: 'http://localhost/wp-content/plugins/construkted/',
});
```

**proj4 and turf.js are pure JavaScript libraries that work directly in Node.js** — no browser APIs, no mocking needed. Use them as real dependencies in tests. They're fast, deterministic, and their computations are what you actually want to verify.

---

## What to test first: a practical categorization

### Immediately unit-testable (zero mocking, pure functions)

This is where you start. These files are the highest-value, lowest-effort targets:

- **Math algorithms**: Kabsch, SVD, coordinate transformations, measurement calculations — pure input/output functions. Use `toBeCloseTo()` for floating-point comparisons and test mathematical invariants (identity, inverse, round-trip, commutativity).
- **Unit conversions**: AngleUnits, AreaUnits, DistanceUnits, VolumeUnits — parameterized tests with known reference values using `it.each()`.
- **proj4 coordinate transformations**: Define projections, transform known coordinates, verify against published reference data.
- **Data transformations**: GeoJSON export, annotation tree operations, serialization/deserialization — test round-trip fidelity and edge cases.
- **turf.js calculations**: Distance, area, point-in-polygon — use known geometric truths as assertions.

```typescript
describe('DistanceUnits', () => {
  it.each([
    [1, 'meters', 'feet', 3.28084],
    [1, 'kilometers', 'miles', 0.621371],
    [0, 'meters', 'feet', 0],
  ])('converts %d %s to %s = %f', (value, from, to, expected) => {
    expect(convert(value, from, to)).toBeCloseTo(expected, 4);
  });
});
```

### Medium difficulty (needs mocking, data models)

Asset, Project, and Annotation class construction, serialization, validation. State management logic. Configuration parsing. These require the Tier 2 partial mocking strategy for any Cesium type references.

### Hard to unit test (alternative strategies required)

**Custom Cesium primitives, Three.js rendering, camera controllers, annotation drawing tools, and user interaction handlers** are genuinely hard to unit test and often not worth the effort. The rendering pipeline is better served by visual regression tests (Playwright screenshots), smoke tests (verify no console errors), and structured manual QA checklists. Testing thin wrappers around Cesium/Three.js APIs provides no value — you'd just be testing that the library works.

---

## CI pipeline: three jobs, cost-optimized

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-latest  # $0.006/min (free on public repos)
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: 'npm' }
      - run: npm ci
      - run: npx vitest run --project unit --coverage
      - uses: actions/upload-artifact@v4
        with: { name: coverage, path: coverage/ }

  integration-tests:
    runs-on: ubuntu-latest
    needs: unit-tests
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: 'npm' }
      - run: npm ci && npx playwright install --with-deps chromium
      - uses: GabrielBB/xvfb-action@v1
        with: { run: npx vitest run --project integration }

  visual-tests:  # Only on PRs, uses GPU runner
    runs-on: gpu-linux-4  # $0.052/min
    needs: unit-tests
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: 'npm' }
      - run: npm ci && npx playwright install --with-deps chromium
      - run: sudo modprobe nvidia && sudo modprobe nvidia_uvm || true
      - run: xvfb-run --auto-servernum npx playwright test
```

**Cost per PR: ~$0.03 without visual tests, ~$0.13 with GPU visual regression.** Standard runners handle unit and integration tests. GPU runners (Tesla T4, ~$0.052/min) are needed only for stable visual regression screenshots. SwiftShader (built into Chromium) provides software WebGL on standard runners but is slow and flaky for visual comparisons.

For **headless WebGL on standard runners**, use Chromium with `--use-gl=swiftshader` or `--use-angle=swiftshader`. For GPU runners, use `--use-angle=vulkan` with `xvfb-run` in headed mode. The key `xvfb` action provides a virtual framebuffer on headless Linux, required for any browser-based WebGL testing.

---

## Recommended project structure

```
project-root/
├── src/
│   ├── core/math/
│   │   ├── kabsch.ts
│   │   ├── kabsch.test.ts          ← Co-located unit tests
│   │   └── svd.ts
│   ├── core/units/
│   │   ├── DistanceUnits.ts
│   │   └── DistanceUnits.test.ts
│   ├── models/
│   │   ├── Asset.ts
│   │   └── Asset.test.ts
│   ├── cesium/                      ← Cesium-dependent code
│   └── xr/                          ← Separate XR module
│       └── vitest.config.ts         ← Own config extending root
├── tests/
│   ├── integration/                 ← Browser tests (Playwright)
│   ├── visual/                      ← Visual regression
│   ├── fixtures/                    ← Shared test data
│   │   ├── mock-cesium.ts
│   │   └── sample-geojson.json
│   └── setup.ts                     ← Global mocks (Cesium, jQuery, WP)
├── __mocks__/
│   └── cesium.ts                    ← Partial Cesium mock
├── vitest.config.ts
├── playwright.config.ts
└── package.json
```

Co-locate unit tests next to source files. Integration, visual, and fixture files go in a separate `tests/` directory. The XR module gets its own Vitest config that extends the root. Use Vitest's `projects` feature to run unit tests in Node.js and integration tests in browser mode from a single configuration.

UMD bundle testing deserves a dedicated smoke test that loads the built bundle in jsdom, verifies `window.ConstruktedJs` is exposed, and checks the API surface:

```typescript
// tests/integration/umd-bundle.test.ts
import { JSDOM } from 'jsdom';
import { readFileSync } from 'fs';

it('exposes ConstruktedJs on window', () => {
  const bundle = readFileSync('./dist/construkted-js.umd.js', 'utf-8');
  const dom = new JSDOM('<!DOCTYPE html>', { runScripts: 'dangerously' });
  dom.window.eval('window.Cesium = { Viewer: function() {} }');
  dom.window.eval(bundle);
  expect(dom.window.ConstruktedJs).toBeDefined();
});
```

---

## Phased adoption plan for a zero-test codebase

**Phase 0 — Infrastructure (week 1–2).** Install Vitest. Create the config. Add `npm run test` to CI. Zero tests, zero failures. This removes all friction for writing the first test.

**Phase 1 — Pure functions (weeks 2–6).** Target 15–20 files, ~5–8% coverage. Test math utilities, unit conversions, proj4 transforms, data transformations, turf.js calculations. Write **characterization tests first** — don't assume correctness; document actual behavior. If `kabsch(P, Q)` returns a specific rotation matrix, assert that exact result even if you suspect a bug. Fix bugs separately, after tests lock in current behavior.

**Phase 2 — Data models and state (weeks 6–12).** Target 30–40 files, ~15–20% coverage. Test Asset, Project, Annotation serialization. Test state management logic. Apply minimal refactoring: extract methods, parameterize constructors with defaults to globals, create thin wrappers around `window.Cesium` for injection.

**Phase 3 — Integration code (weeks 12–20).** Target ~25–35% coverage. Service-layer coordination, API communication, event handling logic extracted from DOM handlers.

**Phase 4 — Browser tests (ongoing).** Add Playwright smoke tests for critical user flows. Add visual regression for key rendering states. This is where `xvfb` and GPU runners enter the picture.

**The single most important rule: every bug fix and feature change includes a test from day one.** This prevents new test debt and naturally grows coverage in the areas that change most. Michael Feathers calls this the "test islands" pattern — tested areas expand over time in the code that matters most.

Realistic coverage targets: **15–20% at 3 months, 25–35% at 6 months, 40–50% at 12 months.** A long-term plateau of 50–65% is realistic for a 3D rendering library. Much of the rendering code is genuinely untestable via unit tests and should be covered by visual regression and manual QA.

---

## What is honestly not worth unit testing

**Thin wrappers around CesiumJS/Three.js APIs** add no test value — you're just testing that the library works. **GLSL shader code** cannot run in Node.js. **Mouse/touch event wiring** (the `addEventListener` plumbing, not the handler logic) is better verified by integration tests. **One-line delegation methods** and **initialization bootstrap code** are better covered by smoke tests than unit tests. **CSS and layout** cannot be meaningfully expressed in assertions.

For rendering code, the proven alternative stack is: **Playwright visual regression** (screenshot comparison with `maxDiffPixelRatio: 0.03` for anti-aliasing tolerance), **smoke tests** (load the app, verify no console errors, verify key elements render), and **structured manual test checklists** maintained in the repo for camera controllers, annotation tools, and interaction flows. CesiumJS's own E2E suite uses exactly this approach — Playwright screenshot comparisons generated from `main` branch as baselines.

The realistic distribution for quality assurance in a 3D library is roughly: **30% automated unit tests, 20% automated integration/browser tests, 15% visual regression, and 35% structured manual testing.** Accepting this distribution rather than pursuing 80%+ automated coverage is the pragmatic path to sustainable quality.

## Conclusion

The technical path forward is clear: **Vitest 4.x** for the framework, **real Cesium math types plus partial mocks** for the testing strategy, **co-located test files** for project structure, and a **characterization-test-first** approach for the zero-test codebase. The critical architectural insight from CesiumJS's own 13,500-test suite is the clean separation between code that needs WebGL and code that doesn't. Roughly 35–45% of your 257 files likely fall into the "no WebGL needed" category and can be tested today with minimal setup. The rendering pipeline, camera controllers, and interaction handlers are best served by Playwright visual regression on standard CI runners with `xvfb`, reserving GPU runners only for pixel-perfect screenshot baselines. Start with `npm install -D vitest jsdom @vitest/coverage-v8`, write one test for your simplest pure function, and enforce "test what you touch" on every PR. Coverage will compound naturally in the code that matters most.