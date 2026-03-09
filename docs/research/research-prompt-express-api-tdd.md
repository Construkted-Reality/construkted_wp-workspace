# Deep Research Prompt: TDD Best Practices for an Express/TypeScript Tile Processing API

## Context

I'm adding a test-driven development workflow to a Node.js/TypeScript API that orchestrates 3D asset processing — downloading archives from cloud storage, tiling 3D models into Cesium 3D Tiles format, and uploading results to multi-region S3-compatible storage. There are currently ZERO automated tests. I want to adopt TDD going forward, starting with unit tests and later adding integration tests.

This prompt is specifically about the **Express/TypeScript API server**. The WordPress theme and the CesiumJS viewer library are covered by separate research prompts.

## Technology Stack (Exact)

### Runtime & Language
- **Node.js 18.16.0** (managed via nvm)
- **TypeScript 5.4.5** (strict mode, target ES2020, CommonJS modules)
- **ts-node 10.9.2** for direct TypeScript execution (production runs `ts-node index.ts` via systemd)
- **nodemon 3.1.9** for dev auto-restart

### Framework & HTTP
- **Express 4.17.1**
- **No body parsing middleware** — all endpoints use GET with query parameters (even mutations)
- **No authentication middleware**
- **Wildcard CORS** (`Access-Control-Allow-Origin: *`)
- Supports both HTTP (port 5000, local) and HTTPS (PEM certificates, production)

### Dependencies
| Package | Version | Purpose |
|---|---|---|
| `@aws-sdk/client-s3` | `^3.914.0` | S3 client for Wasabi cloud storage |
| `@aws-sdk/lib-storage` | `^3.914.0` | Managed S3 uploads |
| `axios` | `^1.6.8` | HTTP client (used alongside deprecated `request`) |
| `express` | `^4.17.1` | HTTP framework |
| `cesium` | `^1.104.0` | Used server-side for ECEF-to-cartographic coordinate conversion |
| `fs-extra` | `^7.0.1` | Enhanced filesystem operations |
| `gm` | `^1.23.1` | GraphicsMagick/ImageMagick bindings for image processing |
| `node-schedule` | `^1.3.1` | Cron-style job scheduling (hourly task cleanup) |
| `uuid` | `^11.1.0` | UUID generation for tasks |
| `request` | `^2.88.2` | HTTP client (**deprecated**) |
| `request-promise` | `^4.2.6` | Promise wrapper for request (**deprecated**) |
| `async` | `^2.6.1` | Async control flow |
| `dotenv` | `^16.4.7` | Environment variable loading |

### Linting
- ESLint 9 with flat config, `@typescript-eslint/parser` and `@typescript-eslint/eslint-plugin`
- `eslint-config-love` shared config

### Scripts
| Script | Command |
|---|---|
| `build` | `tsc` |
| `start` | `node dist/index.js` |
| `dev` | `nodemon --exec "npm run build && node dist/index.js" --ext ts` |
| `lint` | `eslint **/*.{js,ts}` |

### What The API Does

This is a **tile processing orchestration API** that converts raw 3D data (photogrammetry, point clouds, orthomosaics) into Cesium 3D Tiles format. It:

1. **Receives processing requests** via HTTP GET endpoints
2. **Downloads archives** (ZIP, RAR, 7z, 3tz) from Wasabi S3 buckets
3. **Validates input** (checks archive contents match declared asset type)
4. **Tiles the data** using one of four strategies:
   - **MeshTilingStrategy**: Uses UltraMesh (Java JAR, `java -Xmx20g`) or Cesium Ion REST API
   - **PointCloudTilingStrategy**: Uses Cesium Ion 3D Tiling Pipeline's `point-cloud-tiler` binary
   - **ImageryTilingStrategy**: Uses `imagery-tiler` binary + WebP image conversion
   - **ExistingTilesTilingStrategy**: Validates and repackages pre-tiled 3D Tiles
5. **Uploads results** to dual-region Wasabi S3 (US East 2 + EU Central 2)
6. **Notifies WordPress** of completion/errors via HTTP callbacks
7. **Manages task lifecycle** with in-memory task queue (running, CPU-intensive, paused states)

### API Endpoints

| Method | Route | Purpose |
|---|---|---|
| GET | `/` | Health check |
| GET | `/version` | Returns version from package.json |
| GET | `/request_tiling` | Start a tiling task (params: postId, slug, userName, fileName, assetModelType, wPServerUrl, epsgCode, uploadBucketName) |
| GET | `/request_cancel` | Cancel a running task |
| GET | `/ping` | Ping the WordPress server |
| GET | `/task/all` | All tasks with info |
| GET | `/task/list` | All task UUIDs |
| GET | `/task/:uuid/info` | Specific task info |
| GET | `/delete_asset` | Delete assets from S3 (both US + EU buckets) |

### Source Code Architecture

```
├── index.ts              # Bootstrap, server start, graceful shutdown
├── app.ts                # Express app, route definitions, startup validation
├── config.ts             # Configuration (port, SSL, limits, paths)
├── global.ts             # State enum, error codes, S3 endpoint URLs
├── bucketConfig.ts       # Wasabi S3 bucket configurations (3 regions)
├── lib/
│   ├── task.ts           # Core Task class (1223 lines) — full processing lifecycle
│   ├── taskManager.ts    # TaskManager singleton (375 lines) — queue management
│   ├── logger.ts         # Custom file/console logger
│   ├── http.ts           # HTTP utilities
│   ├── bucketConfigMgr.ts # Bucket-to-endpoint mapping
│   ├── constants.ts      # SIGKILL, EPSG codes
│   ├── statusCodes.ts    # Task status enum
│   ├── runningStatusCodes.ts # Running sub-status enum
│   ├── taskErrorInfos.ts # 30+ structured error codes with messages
│   ├── utils.ts          # File utilities (count files, get images, filter by extension)
│   ├── directories.ts    # Data directory path
│   ├── countOfFilesOfDirectory.ts      # Recursive file counter
│   ├── countPointRecordsFromPointCloud.ts # Runs `lasinfo` binary
│   ├── existsTilesetJSON.ts            # Validates tileset.json existence
│   ├── georeferencedAtECEF.ts          # ECEF-to-cartographic conversion (uses Cesium server-side)
│   ├── runAwsRemove.ts                 # Spawns `aws s3 rm` CLI commands
│   ├── tiling/
│   │   ├── tilingStrategy.ts           # Strategy interface
│   │   ├── assetModelTypes.ts          # Asset type definitions
│   │   ├── meshTilingStrategy.ts       # UltraMesh or Cesium Ion (471 lines)
│   │   ├── pointCloudTilingStrategy.ts # point-cloud-tiler binary
│   │   ├── imageryTilingStrategy.ts    # imagery-tiler binary + WebP conversion
│   │   └── existingTilesTilingStrategy.ts # Pre-tiled validation
│   └── validation/
│       └── assetInputValidator.ts      # Pre-tiling archive validation
├── types/
│   └── global.d.ts       # TaskInfo interface
└── data/                 # Runtime: SSL certs, task persistence (gitignored)
```

### Key Testing Challenges

1. **Heavy child_process usage**: The core processing pipeline spawns external processes:
   - `java -Xmx20g -XX:+UseParallelGC -jar UltraMesh.jar` (mesh tiling)
   - `point-cloud-tiler` binary (point cloud tiling)
   - `imagery-tiler` binary (orthomosaic tiling)
   - `7z` (archive extraction)
   - `aws s3 rm/cp/sync` CLI (S3 operations)
   - `lasinfo` (point cloud metadata)
   - `convert`/`parallel` (image conversion)

2. **S3/Wasabi interactions**: Downloads and uploads to three Wasabi regions using both AWS SDK v3 and AWS CLI

3. **Cesium Ion REST API**: Full workflow — create asset, upload, monitor polling, archive, download

4. **WordPress HTTP callbacks**: Notifies WordPress of processing status changes

5. **In-memory state**: TaskManager singleton with task queues, no database

6. **File system operations**: Heavy use of temp directories, archive extraction, file reading/writing via `fs-extra`

7. **No dependency injection**: Classes directly instantiate S3 clients, spawn processes, and make HTTP calls

8. **Environment-dependent behavior**: Different code paths on Windows vs Linux, different behavior based on env vars (`useCesiumIon`, `isLocalTest`)

## Research Questions

### 1. Test Framework Selection (2025-2026 state of the art)

- **Vitest** vs **Jest** for a Node.js/Express/TypeScript API in 2026?
- Given CommonJS modules (`module: "commonjs"` in tsconfig): any compatibility concerns with modern test frameworks?
- Does ts-node integration matter for test runner selection?
- What about **Node.js's built-in test runner** (`node:test`)? Is it mature enough in 2025-2026 for serious use?

### 2. Testing Express API Endpoints

- **Supertest** — is it still the recommended approach for Express endpoint testing in 2026?
- How do you test endpoints that trigger long-running background tasks (like `request_tiling` which starts a multi-minute processing pipeline)?
- How do you test endpoints that only use query parameters (no request body)?
- What's the best way to test the health check and version endpoints (trivial but important for deployment verification)?
- Given that all mutations are on GET endpoints: does this affect the testing approach?

### 3. Testing Code That Spawns Child Processes

This is the highest-priority and hardest testing challenge.

- How do you test code that calls `child_process.spawn()` to run external binaries (`java`, `7z`, `point-cloud-tiler`, `aws` CLI)?
- Should you mock `child_process.spawn()` entirely? Or use a test double that simulates process behavior?
- How do you test error handling for child processes (exit codes, stderr output, timeouts, SIGKILL)?
- Is there a recommended library for mocking child processes in Node.js?
- How do you test the stdout/stderr parsing logic that extracts progress information from spawned processes?
- For the Java/UltraMesh integration: how do you test the command-line argument construction without actually running Java?

### 4. Testing S3/Wasabi Interactions

- **AWS SDK v3 mocking**: What's the current best practice? `aws-sdk-client-mock`? Manual mocks?
- How do you test multi-region upload logic (upload to US + EU buckets sequentially)?
- How do you test presigned URL generation?
- For the AWS CLI spawning (`aws s3 rm`): same question as child process testing above, but specifically for AWS CLI operations
- Is there a local S3-compatible server (MinIO, LocalStack) suitable for integration tests? Which is recommended in 2026?
- How do you test the bucket configuration mapping logic?

### 5. Testing the Strategy Pattern (Tiling Strategies)

- The tiling module uses a clean Strategy pattern with a `TilingStrategy` interface. How do you test each strategy in isolation?
- `MeshTilingStrategy` has two code paths (UltraMesh local vs Cesium Ion cloud) — how do you test both without the external services?
- The Cesium Ion path involves: REST API calls → S3 upload → polling for completion → archive download → extraction. How do you test this workflow?
- `AssetInputValidator` validates archive contents — this depends on filesystem state. Best approach?

### 6. Testing the TaskManager (Singleton with In-Memory State)

- How do you test a singleton class (`TaskManager`) that manages in-memory task queues?
- How do you test queue management logic (max parallel tasks, CPU-intensive task limits, pause/resume)?
- How do you test the scheduled cleanup (tasks older than 48 hours)?
- How do you test task persistence to/from `data/tasks.json`?
- How do you reset singleton state between tests to avoid test pollution?

### 7. Testing the Task Class (1223-Line Orchestrator)

- `task.ts` is the largest file and orchestrates the entire pipeline: download → extract → validate → tile → upload → notify. How do you test this?
- Should you test the full pipeline end-to-end, or test each stage independently?
- How do you test the error handling paths (30+ error codes in `taskErrorInfos.ts`)?
- How do you test the state transitions (Creating → Downloading → Tiling → Uploading → Completed)?
- How do you test the WordPress callback notifications during processing?

### 8. Mocking Strategy

- What mocking library is recommended? Jest's built-in mocks? `sinon`? `testdouble`? Vitest's mocking?
- How do you mock `fs-extra` operations (file reading, directory creation, temp directory management)?
- How do you mock HTTP calls made with `axios` and with `request-promise`?
- How do you mock the `cesium` library used server-side (for coordinate conversion in `georeferencedAtECEF.ts`)?
- How do you mock environment variables (`process.env`) for testing environment-dependent behavior?
- Given no dependency injection: what's the recommended approach for testing tightly coupled code? Module-level mocking? Refactoring toward DI?

### 9. What CAN Be Unit Tested Easily (Quick Wins)

- `utils.ts` — file counting and filtering functions (pure logic)
- `taskErrorInfos.ts` — error code mapping (pure data)
- `statusCodes.ts` / `runningStatusCodes.ts` — enum definitions
- `bucketConfig.ts` / `bucketConfigMgr.ts` — bucket-to-endpoint mapping
- `assetInputValidator.ts` — archive content validation (needs filesystem mocking)
- `existsTilesetJSON.ts` — tileset.json detection (needs filesystem mocking)
- `georeferencedAtECEF.ts` — coordinate conversion (pure math + Cesium dependency)
- `config.ts` — configuration validation
- `countOfFilesOfDirectory.ts` — recursive file counting

### 10. What's Hard to Unit Test (and What to Do Instead)

- The full tiling pipeline (download → tile → upload)
- The Cesium Ion API integration (multi-step REST workflow with polling)
- Actual child process execution (spawning Java, 7z, etc.)
- Multi-region S3 operations (real network I/O)
- What testing strategies exist beyond unit tests for these? Integration tests with Docker? Contract tests? End-to-end tests with real (but small) test fixtures?

### 11. Testing File System Operations

- The API heavily uses temp directories, extracts archives, reads directory trees, counts files. How do you set up/tear down filesystem state for tests?
- `fs-extra` testing patterns — mock it or use a temp directory?
- For `countOfFilesOfDirectory.ts` and `existsTilesetJSON.ts`: should you create actual directory structures in a `fixtures/` folder?
- How do you handle platform-specific filesystem behavior (Windows vs Linux paths)?

### 12. Gradual Adoption Strategy

- For an API with zero tests: what should be tested first for maximum confidence?
- How do you introduce TDD into a codebase with no DI and heavy external dependencies?
- What minimal refactoring is needed to make the code testable?
- Should you start with endpoint tests (testing from the outside in) or unit tests (testing from the inside out)?
- How do you handle the 1223-line `task.ts` — test it as-is, or refactor first?

### 13. CI/CD Integration

- How do you run these tests in a CI environment without access to Wasabi S3, UltraMesh, or Cesium Ion?
- What GitHub Actions workflow works for a Node.js/TypeScript API with unit tests?
- Do integration tests need a different CI pipeline from unit tests?
- How do you handle environment variables and secrets in test environments?

## What I Need From This Research

1. **Specific framework and tool recommendations** with version numbers
2. **Child process testing patterns** — this is the hardest challenge. Concrete code examples of testing code that spawns `java`, `aws`, and custom binaries.
3. **AWS SDK v3 mocking examples** — current best practice with code samples
4. **Strategy pattern testing examples** — how to test each tiling strategy in isolation
5. **TaskManager/singleton testing patterns** — including state reset between tests
6. **Express endpoint testing examples** using the recommended framework
7. **A recommended project structure** for adding tests
8. **A phased adoption plan** — what to test first, what refactoring to do when
9. **Links to authoritative sources** — Express testing guides, AWS SDK mocking docs, child_process testing articles, well-tested open-source Node.js APIs I can study
10. **Honest assessment of what requires integration tests vs unit tests** — don't pretend everything can be unit tested
