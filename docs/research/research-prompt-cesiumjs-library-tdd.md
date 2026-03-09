# Deep Research Prompt: TDD Best Practices for a CesiumJS/TypeScript 3D Viewer Library

## Context

I'm adding a test-driven development workflow to a TypeScript library that provides a 3D geospatial asset viewer and annotation platform. The library is built primarily on CesiumJS and is loaded into a WordPress site via a `<script>` tag. There are currently ZERO automated tests. I want to adopt TDD going forward, starting with unit tests and later adding integration and visual regression tests.

This prompt is specifically about the **TypeScript/JavaScript viewer library**. The WordPress theme and the Node.js API are covered by separate research prompts.

## Technology Stack (Exact)

### Language & Compiler
- **TypeScript 4.7.4** (strict mode enabled, `allowJs: true` for mixed JS/TS)
- **30 legacy JavaScript files** alongside 227 TypeScript files (257 total source files)
- **Target**: ES6 (ES2015)
- **Module system**: ESNext in source, compiled to **UMD** for distribution
- `isolatedModules: true` in tsconfig

### Build System (Three Parallel Systems)
- **Rollup 2.53** — dev builds (UMD, unminified, with sourcemaps)
- **Vite 5.4** — dev watch builds (UMD, minified)
- **Gulp 4 + Rollup + javascript-obfuscator 4.0** — production builds (UMD, minified, obfuscated)
- All output is UMD format exposing `window.ConstruktedJs`, with CesiumJS as external global `window.Cesium`

### Core Dependencies
| Package | Version | Role |
|---|---|---|
| `cesium` | `1.132` | Primary 3D globe/viewer engine |
| `three` | `0.152.0` | Secondary 3D engine (WebXR module only) |
| `@jdultra/threedtiles` | `9.1.12` | 3D Tiles rendering via Three.js |
| `@turf/turf` | `^6.5.0` | GIS spatial analysis |
| `proj4` | `^2.15.0` | Coordinate reference system transformations |
| `jquery` | `^3.6.3` | DOM manipulation (legacy, used throughout) |
| `markdown-it` | `^12.1.0` | Markdown rendering |
| `keycode-js` | `^3.1.0` | Keyboard event handling |

### Linting
- ESLint 8.2 with `airbnb-base` + `prettier` config
- `@typescript-eslint/parser` and `@typescript-eslint/eslint-plugin`
- Husky pre-commit hook exists but **lint is commented out** (no automated quality gates)

### What The Library Does

This is a comprehensive geospatial 3D viewer with these major feature areas:

1. **Viewer Modes** (4 distinct viewers):
   - `AssetViewer` — Single 3D tileset viewing
   - `ProjectViewer` — Multi-asset project viewing with twin/compare views
   - `OrthomosaicViewer` — 2D TMS tile viewing
   - `AssetExplorerV2` — Globe-level asset browsing

2. **3D Tileset Management**: Loading, positioning, georeferencing, and rendering Cesium 3D Tilesets (photogrammetry models, point clouds, BIM models)

3. **Annotation System** (the most complex feature):
   - Drawing tools: polygon, polyline, notes/labels, paint, image planes
   - Measurement tools: point, distance, polyline, area, volume
   - Clipping tools: clipping boxes, clipping planes
   - Annotation tree view with layers
   - Export: PDF, GeoJSON, KML

4. **Georeferencing Tools**:
   - Visual Position Editor (drag/rotate/scale assets on globe)
   - Multi-GCP Editor (Ground Control Points using Kabsch algorithm + SVD)
   - CRS/EPSG coordinate system support via proj4

5. **Camera Controls**: FPV navigation, fly-through mode, saved viewpoints, orthographic/perspective switching

6. **Video Recording**: Scene recording with timeline, keyframes, tweening

7. **WebXR Module** (`src/xr/`): Uses Three.js 0.152 (not Cesium) with vendored gl-matrix. Has its own rollup config.

8. **WordPress Integration**: Reads config from `window.CONSTRUKTED_AJAX` (injected by WordPress PHP), uses jQuery for DOM operations, constructs URLs based on WP theme paths

### Source Code Architecture

```
src/
├── index.ts                     # Entry point
├── Construkted.ts               # Main app class (1011 lines)
├── ConstruktedApi.ts            # API utilities
├── AbstractViewer.ts            # Base viewer
├── AssetViewer.ts / ProjectViewer.ts / OrthomosaicViewer.ts / AssetExplorerV2.ts
├── core/                        # Core library
│   ├── Asset.ts, TilesetAsset.ts, TMSTilesAsset.ts
│   ├── CRSManager.ts, EPSGs.ts  # Coordinate systems
│   ├── VisualPositionEditor.ts   # Georeferencing
│   ├── drawing/                  # Drawing handlers
│   ├── gcp/                      # Ground Control Points (Kabsch.js, svd.js)
│   ├── label/                    # Label rendering
│   ├── primitives/               # Custom Cesium primitives (13+ files)
│   ├── TransformEditor/          # 3D transform gizmo (6 files)
│   └── units/                    # Measurement unit conversions
├── tools/                        # Annotation & measurement tools
│   ├── annotation/clipping/      # Clipping tools (7 files)
│   ├── annotation/drawing/       # Drawing tools (12 files)
│   ├── annotation/measure/       # Measurement tools (12 files)
│   └── video-recorder/           # Video recording (10 files)
├── panels/                       # UI sidebar panels (14 files)
├── project/                      # Project operations (12 files)
├── types/                        # TypeScript type definitions
└── xr/                           # WebXR module (separate build)
```

### Key Testing Challenges

1. **CesiumJS dependency**: The library heavily uses Cesium's `Viewer`, `Scene`, `Camera`, `Cartesian3`, `Matrix4`, `Cesium3DTileset`, `Entity`, `DataSource`, and many other classes. These require WebGL context.
2. **jQuery dependency**: DOM manipulation is done through jQuery, and the code reads from `window.CONSTRUKTED_AJAX` globals.
3. **Browser APIs**: Uses `requestAnimationFrame`, `canvas`, `WebGL`, `WebXR`, `MediaRecorder`, `Blob`, `URL.createObjectURL`.
4. **Side effects**: Many modules modify the Cesium viewer, add event handlers, or manipulate the DOM as side effects on import or construction.
5. **Mathematical code**: The GCP module (Kabsch algorithm, SVD), coordinate transformations (proj4, ECEF-to-WGS84), measurement calculations (area, volume, distance) — these are pure functions that are highly testable.
6. **No dependency injection**: Classes directly instantiate Cesium objects, jQuery calls, and browser APIs. No DI container or inversion of control.

## Research Questions

### 1. Test Framework Selection (2025-2026 state of the art)

- **Vitest** vs **Jest** for a TypeScript library in 2026 — which is the current recommendation?
- Given that Vite is already in the build toolchain, does Vitest have a significant advantage?
- How does the test framework choice interact with the UMD output format?
- What test runner works best with mixed TypeScript/JavaScript codebases (`allowJs: true`)?
- Does the framework choice matter when Rollup is the primary build tool (not Vite)?

### 2. Testing CesiumJS Code Specifically

This is the most critical and hardest research question.

- How do CesiumJS application developers test their code? What patterns does the CesiumJS community use?
- How does CesiumJS's own test suite work? (CesiumJS is open source — what framework and patterns do they use internally?)
- Can CesiumJS objects (`Viewer`, `Scene`, `Camera`, `Cartesian3`, `Matrix4`, `Cesium3DTileset`) be instantiated in a test environment without a real WebGL context?
- What is the recommended approach for mocking or stubbing CesiumJS objects?
- Is there a headless rendering option for CesiumJS (like headless Chrome/Puppeteer) for visual or integration tests?
- How do you test code that creates Cesium `Entity` objects, `Primitive` objects, or `DataSource` objects?
- Are there any published guides, blog posts, or open-source projects that demonstrate CesiumJS testing patterns?

### 3. Testing Three.js Code

- For the WebXR module that uses Three.js 0.152: how do you test Three.js rendering code?
- How does Three.js's own test suite work?
- Can Three.js `Scene`, `Camera`, `Renderer` be tested without WebGL?
- What about testing the gl-matrix math functions?

### 4. Testing Browser-Dependent Code Without a Browser

- **jsdom** vs **happy-dom** vs **Puppeteer/Playwright** for running tests that depend on browser APIs?
- How do you handle WebGL context requirements in a Node.js test environment?
- How do you mock `window`, `document`, `requestAnimationFrame`, `canvas.getContext('webgl')` in tests?
- For code that reads from `window.CONSTRUKTED_AJAX` (WordPress-injected globals): how do you set up test fixtures for window globals?
- How do you test jQuery-dependent TypeScript code in a test environment?

### 5. What CAN Be Unit Tested Easily (Quick Wins)

- The mathematical/algorithmic code (Kabsch algorithm, SVD, coordinate transformations, measurement calculations, unit conversions) — these are pure functions. What's the best approach?
- `proj4` coordinate transformations — how do you test these?
- Data transformation functions (GeoJSON export, annotation tree operations)
- State management / data model classes (Asset, Project, annotations)
- The `units/` module (AngleUnits, AreaUnits, DistanceUnits, VolumeUnits)

### 6. What's Hard to Unit Test (and What to Do Instead)

- Rendering code (custom Cesium primitives, Three.js rendering)
- User interaction handlers (mouse/keyboard events on the 3D canvas)
- Camera controllers (FPV, fly-through)
- The annotation drawing tools (which combine canvas events, Cesium primitives, and state management)
- What testing strategy works for these? Visual regression testing? Integration tests with headless browser? Manual testing with structured test plans?

### 7. Mocking Strategy

- How do you create test doubles for CesiumJS objects without mocking the entire library?
- Should I create a custom mock module for Cesium (`__mocks__/cesium.ts`)?
- How do you mock jQuery in TypeScript tests?
- For code with heavy side effects (DOM manipulation, event handler registration): what's the testing approach?
- Is there a published pattern for testing applications that depend on a large external library like CesiumJS (similar to how React Testing Library changed how people test React)?

### 8. Test Architecture for a UMD Library

- How do you structure tests for a library that's consumed as a UMD bundle via `<script>` tag?
- The library exposes a single global (`ConstruktedJs`). Should tests import from source (`src/index.ts`) or test the built bundle?
- How do you test that the UMD bundle correctly exposes the expected API?
- Given `isolatedModules: true` in tsconfig: any testing implications?

### 9. Project Structure for Tests

- Where should test files live? `src/__tests__/`? `tests/`? Co-located with source (`*.test.ts` next to `*.ts`)?
- What does the test configuration file look like (vitest.config.ts or jest.config.ts)?
- How do you set up test utilities and shared fixtures for CesiumJS testing?
- How do you handle the separate XR module (which has its own rollup config)?

### 10. Gradual Adoption Strategy

- For a 257-file codebase with zero tests: what's the recommended order of attack?
- How do you introduce TDD into a codebase that wasn't designed for testability (no DI, heavy coupling to globals)?
- What refactoring is needed to make the code testable, and how do you prioritize it?
- Is it worth adding tests to existing code, or only TDD new features/bugfixes going forward?
- How do you measure test coverage and set meaningful targets for a gradual rollout?

### 11. CI Integration

- How do you run CesiumJS-dependent tests in GitHub Actions?
- Do you need a headless browser in CI? Which one?
- How do you handle WebGL requirements in CI environments?
- What does a practical CI pipeline look like for a TypeScript library with both unit and browser-based tests?

## What I Need From This Research

1. **Specific framework and tool recommendations** with version numbers
2. **CesiumJS-specific testing patterns** — this is the hardest part and the most valuable. Code examples of testing CesiumJS applications.
3. **Three.js testing patterns** for the XR module
4. **A practical categorization of the codebase**: what's easily unit-testable vs what needs integration tests vs what needs visual regression tests
5. **Code examples** of test setup, mocking strategies, and actual test cases for each category
6. **A recommended project structure** for adding tests to this library
7. **A phased adoption plan** — start with pure functions (math, conversions), then data models, then interaction code
8. **Links to authoritative sources** — CesiumJS's own test suite, Three.js's test suite, open-source CesiumJS applications with tests, relevant blog posts
9. **Honest assessment of what's NOT worth unit testing** in a 3D rendering library and what alternative quality strategies exist for that code
