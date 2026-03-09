# TDD adoption for a 3D asset processing Express API

**Jest 30 with ts-jest is the right foundation for this CommonJS/TypeScript codebase**, and the path to comprehensive testing runs through a specific sequence: pure utilities first, then validators with mocked filesystems, then strategy classes with mocked child processes and S3, and finally characterization tests on the 1223-line Task orchestrator. The project's architecture — no dependency injection, heavy child_process.spawn usage, singleton state management — is testable without major refactoring thanks to Jest's module-level mocking. Every external binary call (java, 7z, point-cloud-tiler, aws CLI) can be tested through EventEmitter-based mock processes, and AWS SDK v3 interactions are covered by the official `aws-sdk-client-mock` library. The honest reality: about 70% of the codebase's logic is unit-testable with mocking, but full tiling pipeline validation and binary compatibility require Docker-based integration tests.

---

## 1. Jest 30 is the clear choice for a CommonJS TypeScript API

**Jest 30.2.0** (released June 2025, latest patch September 2025) paired with **ts-jest** is the definitive recommendation. The decision hinges on one factor: **CommonJS compatibility**. Vitest 4.0 is ESM-first by design — it converts CJS to ESM internally via Vite's transform pipeline, causing interop issues with named exports from CommonJS modules. Multiple sources explicitly state: "If your app heavily depends on CommonJS → Jest." Jest was built in the CommonJS era, and `jest.mock()` works perfectly with synchronous `require()`.

**Vitest 4.0.18** is 2-10x faster than Jest in benchmarks (cold start up to 4x faster, memory ~30% lower), but these gains are largely irrelevant for a backend API where HTTP request latency dominates test execution time. One backend-specific benchmark showed the gap narrowing to just 1.7x. Vitest's `vi.mock()` uses ESM semantics, so `jest.mock()` patterns won't translate directly — unnecessary friction for a project that needs to ship tests quickly.

**Node.js built-in test runner (`node:test`)** is not viable. On Node 18.16.0, it's experimental with missing features: no glob patterns (require Node 21+), no module-level mocking, no rich assertion matchers, no built-in coverage. Even on Node 22+ LTS, it lacks the mocking depth needed for code without dependency injection.

The recommended toolchain with specific versions:

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

**Jest configuration for the project:**

```typescript
// jest.config.ts
import type { Config } from 'jest';

const config: Config = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/tests'],
  testMatch: ['**/*.test.ts'],
  moduleFileExtensions: ['ts', 'js', 'json'],
  collectCoverageFrom: ['src/**/*.ts', '!src/index.ts'],
  coverageDirectory: 'coverage',
  setupFilesAfterSetup: ['<rootDir>/tests/setup.ts'],
  verbose: true,
};
export default config;
```

Jest's built-in mocking (`jest.mock`, `jest.fn`, `jest.spyOn`) is sufficient for all mocking needs — fs-extra, axios, child_process, and environment variables. No additional mocking library like sinon or testdouble is needed. Jest's module-level mocking is specifically designed for code without dependency injection, which is exactly this project's situation.

---

## 2. Testing child processes is the hardest problem, and EventEmitter fakes solve it

This is the highest-priority challenge. The API spawns seven different external binaries through `child_process.spawn()`, and each needs testable wrappers. The community-standard approach — endorsed by every authoritative source from Aha! Engineering to multiple widely-referenced Medium articles — is **manual mocking with Jest's `jest.mock('child_process')` and a custom EventEmitter-based fake process**. Dedicated libraries like `mock-spawn` exist but are unmaintained (8+ years old).

**The reusable mock helper:**

```typescript
// tests/helpers/mockChildProcess.ts
import { EventEmitter } from 'events';
import { Readable } from 'stream';

export function createMockChildProcess() {
  const cp = new EventEmitter() as any;
  cp.stdout = new Readable({ read() {} });
  cp.stderr = new Readable({ read() {} });
  cp.stdin = { write: jest.fn(), end: jest.fn() };
  cp.pid = 12345;
  cp.kill = jest.fn();
  cp.killed = false;
  return cp;
}
```

**Testing a successful process (exit code 0):**

```typescript
import { spawn } from 'child_process';
import { createMockChildProcess } from '../helpers/mockChildProcess';

jest.mock('child_process');

describe('runUltraMesh', () => {
  let mockProcess: any;

  beforeEach(() => {
    jest.resetAllMocks();
    mockProcess = createMockChildProcess();
    (spawn as jest.Mock).mockReturnValue(mockProcess);
  });

  it('resolves on exit code 0', async () => {
    const resultPromise = runUltraMesh('/path/to/input.las');
    mockProcess.stdout.push('Processing complete\n');
    mockProcess.stdout.push(null);
    mockProcess.emit('close', 0, null);
    await expect(resultPromise).resolves.toBeDefined();
  });
});
```

**Testing failure with specific exit codes and stderr:**

```typescript
it('rejects when java exits with error code', async () => {
  const resultPromise = runUltraMesh('/path/to/input.las');
  mockProcess.stderr.push('Error: OutOfMemoryError\n');
  mockProcess.stderr.push(null);
  mockProcess.emit('close', 1, null);
  await expect(resultPromise).rejects.toThrow(/exit code 1/);
});

it('handles spawn ENOENT when binary not found', async () => {
  const resultPromise = runUltraMesh('/path/to/input.las');
  const error = new Error('spawn java ENOENT') as any;
  error.code = 'ENOENT';
  mockProcess.emit('error', error);
  await expect(resultPromise).rejects.toThrow(/ENOENT/);
});
```

**Testing stdout progress parsing — critical for this API's progress extraction:**

```typescript
it('extracts progress percentages from point-cloud-tiler stdout', async () => {
  const progressUpdates: number[] = [];
  const onProgress = (percent: number) => progressUpdates.push(percent);
  const resultPromise = runPointCloudTiler('/input.las', { onProgress });

  mockProcess.stdout.push('Processing tiles: 10%\n');
  mockProcess.stdout.push('Processing tiles: 50%\n');
  mockProcess.stdout.push('Processing tiles: 100%\n');
  mockProcess.stdout.push(null);
  mockProcess.emit('close', 0, null);

  await resultPromise;
  expect(progressUpdates).toEqual([10, 50, 100]);
});

// Edge case: chunks split mid-line (common with real processes)
it('handles split chunks in stdout progress', async () => {
  const progressUpdates: number[] = [];
  const resultPromise = runPointCloudTiler('/input.las', { onProgress: (p) => progressUpdates.push(p) });

  mockProcess.stdout.push('Processing ti');
  mockProcess.stdout.push('les: 50%\nProcessing tiles: 100%\n');
  mockProcess.stdout.push(null);
  mockProcess.emit('close', 0, null);

  await resultPromise;
  expect(progressUpdates).toEqual([50, 100]);
});
```

**Testing command-line argument construction — verifying spawn was called correctly:**

```typescript
it('constructs correct arguments for imagery-tiler', async () => {
  const resultPromise = runImageryTiler({
    input: '/data/image.tif', output: '/output/tiles', zoom: '0-18'
  });
  process.nextTick(() => {
    mockProcess.stdout.push(null);
    mockProcess.emit('close', 0, null);
  });
  await resultPromise;

  expect(spawn).toHaveBeenCalledWith(
    'imagery-tiler',
    ['--input', '/data/image.tif', '--output', '/output/tiles', '--zoom', '0-18'],
    expect.objectContaining({ cwd: expect.any(String) })
  );
});
```

**Testing timeout/SIGKILL scenarios with fake timers:**

```typescript
it('kills process after timeout and rejects', async () => {
  jest.useFakeTimers();
  const resultPromise = runLasinfo('/path/to/file.las', { timeout: 30000 });

  jest.advanceTimersByTime(31000);
  expect(mockProcess.kill).toHaveBeenCalledWith('SIGKILL');

  mockProcess.emit('close', null, 'SIGKILL');
  await expect(resultPromise).rejects.toThrow(/timeout/i);
  jest.useRealTimers();
});
```

**The highest-value refactoring pattern** is separating command construction from execution into pure functions that are trivially testable without any mocking:

```typescript
// Pure function — no mock needed
function buildUltraMeshArgs(inputFile: string, options: MeshOptions) {
  const args = ['-jar', '/opt/ultramesh/ultramesh.jar', '--input', inputFile];
  if (options.quality) args.push('--quality', String(options.quality));
  return { command: 'java', args };
}

// Test is dead simple
it('includes quality flag when specified', () => {
  const { args } = buildUltraMeshArgs('/data/input.las', { quality: 90 });
  expect(args).toContain('--quality');
  expect(args).toContain('90');
});
```

This pattern applies to all seven binaries and represents the highest-confidence, lowest-effort testing win for child process logic.

---

## 3. AWS SDK v3 mocking with aws-sdk-client-mock covers most S3 scenarios

**aws-sdk-client-mock v4.0.2** is the officially AWS-recommended library for mocking SDK v3 clients. It intercepts `Client.send()` at the instance level, mocking all S3Client instances globally. Paired with **aws-sdk-client-mock-jest v4.1.0**, it provides custom Jest matchers like `toHaveReceivedCommand` and `toHaveReceivedCommandWith`.

**Basic setup and PutObjectCommand mocking:**

```typescript
import { mockClient } from 'aws-sdk-client-mock';
import 'aws-sdk-client-mock-jest';
import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { sdkStreamMixin } from '@smithy/util-stream';
import { Readable } from 'stream';

const s3Mock = mockClient(S3Client);

beforeEach(() => s3Mock.reset());
afterAll(() => s3Mock.restore());

it('uploads tile to correct bucket with metadata', async () => {
  s3Mock.on(PutObjectCommand).resolves({ ETag: '"abc123"' });

  await uploadService.upload({ bucket: 'us-uploads', key: 'tile.b3dm', body: buffer });

  expect(s3Mock).toHaveReceivedCommandWith(PutObjectCommand, {
    Bucket: 'us-uploads',
    Key: 'tile.b3dm',
  });
});
```

**Testing multi-region uploads (US + EU buckets):**

```typescript
it('routes uploads to correct regional bucket', async () => {
  s3Mock
    .on(PutObjectCommand, { Bucket: 'eu-uploads' }).resolves({ ETag: '"eu"' })
    .on(PutObjectCommand, { Bucket: 'us-uploads' }).resolves({ ETag: '"us"' });

  await storageService.upload({ file: buffer, region: 'EU', key: 'test.b3dm' });

  expect(s3Mock).toHaveReceivedCommandWith(PutObjectCommand, {
    Bucket: 'eu-uploads',
  });
});
```

**Mocking multipart uploads with @aws-sdk/lib-storage:**

```typescript
import { CreateMultipartUploadCommand, UploadPartCommand, CompleteMultipartUploadCommand } from '@aws-sdk/client-s3';

it('handles large file multipart upload', async () => {
  s3Mock.on(CreateMultipartUploadCommand).resolves({ UploadId: '1' });
  s3Mock.on(UploadPartCommand).resolves({ ETag: '1' });
  s3Mock.on(CompleteMultipartUploadCommand).resolves({ Location: 'https://...', Bucket: 'mock', Key: 'test' });
  // For small files, lib-storage sends PutObjectCommand instead
  s3Mock.on(PutObjectCommand).resolves({});

  const upload = new Upload({
    client: new S3Client({}),
    params: { Bucket: 'mock', Key: 'test', Body: largeBuffer },
  });
  await upload.done();

  expect(s3Mock).toHaveReceivedCommand(CreateMultipartUploadCommand);
});
```

Newer versions also provide `mockLibStorageUpload(s3Mock)` which configures all required multipart command mocks automatically.

**Presigned URLs require jest.mock(), not aws-sdk-client-mock.** The `getSignedUrl` function from `@aws-sdk/s3-request-presigner` is a standalone function, not a Command sent via `Client.send()`:

```typescript
jest.mock('@aws-sdk/s3-request-presigner');
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

const getSignedUrlMock = getSignedUrl as jest.MockedFunction<typeof getSignedUrl>;

it('generates download URL with correct expiration', async () => {
  getSignedUrlMock.mockResolvedValue('https://bucket.s3.wasabisys.com/file?X-Amz-Signature=abc');

  const url = await presignService.getDownloadUrl('us-bucket', 'tiles/tileset.json');

  expect(getSignedUrlMock).toHaveBeenCalledWith(
    expect.any(S3Client),
    expect.any(GetObjectCommand),
    { expiresIn: 3600 }
  );
});
```

**For AWS CLI spawning** (`aws s3 sync`), use the same child_process mock pattern — mock `spawn`, verify `aws` is called with correct arguments including `s3 sync`, bucket paths, and environment variables containing AWS credentials. Long-term, consider migrating from CLI spawning to SDK v3 for better testability, though `aws s3 sync` has no direct SDK equivalent.

**For integration tests, MinIO beats LocalStack** for this use case. Since Wasabi is itself an S3-compatible storage provider (not AWS S3), MinIO more closely models the scenario — both use the same S3 API without AWS-specific behaviors. Point the same `@aws-sdk/client-s3` client at MinIO by changing only the endpoint:

```yaml
# docker-compose.test.yml
services:
  minio:
    image: minio/minio:latest
    ports: ["9000:9000"]
    environment:
      MINIO_ROOT_USER: testuser
      MINIO_ROOT_PASSWORD: testpassword
    command: server /data
```

---

## 4. Supertest, strategies, and the singleton all have established patterns

### Express endpoint testing

**Supertest 7.2.2** remains the dominant choice for Express API testing — **62%+ of Node.js backend developers** use it per 2025 surveys, with ~8-10 million weekly downloads. It works perfectly with Express 4.17.1 and handles GET-only endpoints trivially. The critical setup is exporting the Express app separately from `app.listen()`:

```typescript
// server.ts — export app without listening
export function createApp(): Express {
  const app = express();
  app.use(cors());
  // ... routes
  return app;
}

// index.ts — listen in separate file
const app = createApp();
app.listen(3000);
```

**Testing GET endpoints with query parameters:**

```typescript
import request from 'supertest';
import { createApp } from '../server';

const app = createApp();

it('starts tiling with valid query params', async () => {
  const response = await request(app)
    .get('/tile')
    .query({ inputPath: 's3://bucket/model.obj', type: 'mesh', callbackUrl: 'https://example.com/callback' })
    .expect(200);

  expect(response.body).toHaveProperty('taskId');
  expect(response.body.status).toBe('queued');
});
```

**Testing endpoints that trigger background tasks** — mock TaskManager to prevent actual execution:

```typescript
it('returns taskId immediately without waiting for completion', async () => {
  const addTaskSpy = jest.spyOn(TaskManager.getInstance(), 'addTask')
    .mockImplementation((task) => { task.id = 'mock-id'; return task; });

  const response = await request(app)
    .get('/tile')
    .query({ inputPath: 's3://bucket/file.obj', type: 'mesh' })
    .expect(200);

  expect(response.body.taskId).toBeDefined();
  expect(addTaskSpy).toHaveBeenCalledTimes(1);
  addTaskSpy.mockRestore();
});
```

### Strategy pattern testing

Each strategy class should be tested in isolation by mocking its external dependencies at the module level:

```typescript
jest.mock('child_process');
jest.mock('axios');
jest.mock('@aws-sdk/client-s3');

import { MeshTilingStrategy } from '../strategies/MeshTilingStrategy';

describe('MeshTilingStrategy — UltraMesh path', () => {
  it('spawns java with correct jar and arguments', async () => {
    // ... mock spawn, emit close 0, verify arguments
  });

  it('handles java process failure with OutOfMemoryError', async () => {
    // ... mock spawn, emit stderr + close 1
  });
});

describe('MeshTilingStrategy — Cesium Ion path', () => {
  it('executes full pipeline: create asset → upload → poll → download', async () => {
    (axios.post as jest.Mock)
      .mockResolvedValueOnce({ data: { id: 12345, uploadLocation: { endpoint: '...', bucket: 'ion' } } });
    (axios.get as jest.Mock)
      .mockResolvedValueOnce({ data: { status: 'IN_PROGRESS' } })
      .mockResolvedValueOnce({ data: { status: 'COMPLETE', archiveUrl: 'https://...' } });

    const result = await strategy.tile({ inputPath: '/tmp/model.obj', useCesiumIon: true });
    expect(result.success).toBe(true);
  });
});
```

### TaskManager singleton — state reset is the critical concern

Three approaches for preventing test pollution across tests, in order of recommendation:

**Approach 1: Add a `resetForTesting()` static method** (minimal, safe refactoring):

```typescript
// Add to TaskManager class
static resetForTesting(): void {
  if (TaskManager.instance) {
    TaskManager.instance.tasks.clear();
    TaskManager.instance.runningCount = 0;
  }
  TaskManager.instance = undefined as any;
}

// In tests
beforeEach(() => TaskManager.resetForTesting());
```

**Approach 2: `jest.resetModules()` for complete isolation** (no production code changes):

```typescript
beforeEach(() => jest.resetModules());

it('gets a clean singleton', () => {
  const { TaskManager } = require('../TaskManager');
  const tm = TaskManager.getInstance();
  expect(tm.getTasks().length).toBe(0); // guaranteed fresh
});
```

**Testing queue management with fake timers:**

```typescript
it('removes tasks older than 48 hours during cleanup', () => {
  jest.useFakeTimers();
  const tm = TaskManager.getInstance();
  tm.addTask(createMockTask('old-task', { createdAt: new Date(Date.now() - 49 * 60 * 60 * 1000) }));
  tm.addTask(createMockTask('new-task', { createdAt: new Date() }));

  tm.cleanup();

  expect(tm.getTask('old-task')).toBeUndefined();
  expect(tm.getTask('new-task')).toBeDefined();
  jest.useRealTimers();
});
```

---

## 5. The 1223-line Task class needs characterization tests before any refactoring

Michael Feathers' *Working Effectively with Legacy Code* defines the core principle: **never refactor without tests, never test without understanding current behavior**. The Task class orchestrates the full pipeline (download → extract → validate → tile → upload → notify), and the right approach is a hybrid: **unit test each pipeline stage independently** while writing a few thin integration tests for the full flow.

**Testing state transitions through the pipeline:**

```typescript
describe('Task state transitions', () => {
  let task: Task;

  beforeEach(() => {
    task = new Task({ id: 'test', type: 'mesh', inputPath: 's3://bucket/model.obj' });
    jest.spyOn(task as any, 'download').mockResolvedValue('/tmp/model.obj');
    jest.spyOn(task as any, 'extract').mockResolvedValue('/tmp/extracted/');
    jest.spyOn(task as any, 'validate').mockResolvedValue(true);
    jest.spyOn(task as any, 'tile').mockResolvedValue('/tmp/tiles/');
    jest.spyOn(task as any, 'upload').mockResolvedValue('s3://bucket/tiles/');
    jest.spyOn(task as any, 'notify').mockResolvedValue(undefined);
  });

  it('transitions through all states in order', async () => {
    const states: string[] = [];
    jest.spyOn(task, 'setStatus').mockImplementation((s: string) => { states.push(s); });

    await task.run();
    expect(states).toEqual(['downloading', 'extracting', 'validating', 'tiling', 'uploading', 'notifying', 'completed']);
  });

  it('transitions to failed on download error', async () => {
    jest.spyOn(task as any, 'download').mockRejectedValue(new Error('S3 access denied'));
    await task.run();
    expect(task.status).toBe('failed');
    expect(task.error).toContain('S3 access denied');
  });
});
```

**For the 30+ error handling paths**, organize tests by pipeline stage — each stage gets its own describe block with tests for each error condition (network timeout, access denied, corrupted archive, disk space, process crash, API errors). This makes coverage tracking straightforward and failures easy to locate.

**Key Feathers techniques for the Task class:**

- **Sprout Method**: When adding new functionality, write it in a new, tested method called from the old code
- **Wrap Method**: Add pre/post behavior by wrapping existing methods
- **Extract Method**: Gradually pull testable pieces out of the 1223-line file, giving each its own unit tests
- **Characterization tests**: Write tests that document what the code *currently does* (not what it should do) — these serve as a safety net for future refactoring

---

## 6. File system testing, HTTP mocking, and environment variables

**For filesystem testing, `memfs` is the recommended approach** for unit tests. It provides an in-memory filesystem compatible with Node's `fs` module:

```typescript
jest.mock('fs');
const { vol } = require('memfs');

beforeEach(() => vol.reset());

test('counts files in directory', () => {
  vol.fromJSON({
    '/input/model.obj': 'content',
    '/input/texture.png': 'data',
    '/input/tileset.json': '{"root":{}}',
  });
  expect(countFiles('/input')).toBe(3);
});
```

**Important caveat**: `memfs` doesn't natively intercept `fs-extra` — you may need to mock `fs-extra` separately with `jest.mock('fs-extra')` or use `unionfs` to combine real and virtual filesystems. For integration-style tests that need real filesystem behavior, use temp directories:

```typescript
let tmpDir: string;
beforeEach(async () => { tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'test-')); });
afterEach(async () => { await fs.remove(tmpDir); });
```

Maintain a `tests/fixtures/` directory with small, representative test files for each format: minimal `.las`/`.laz` point cloud files, small test archives, 1x1 pixel images, and minimal tileset.json structures.

**For HTTP mocking, both MSW and nock are excellent choices.** A notable 2025 development: nock now uses `@mswjs/interceptors` internally, meaning both libraries share the same request interception engine. Both intercept `axios` and the deprecated `request-promise` at the network level without library-specific configuration. **Nock** has the simpler API for straightforward cases and works well for this project's needs — mocking Cesium Ion REST API calls and WordPress callback notifications:

```typescript
import nock from 'nock';

it('sends task result to WordPress callback URL', async () => {
  const callbackScope = nock('https://example.com')
    .post('/wp-callback', (body) => {
      expect(body.taskId).toBe('test-task');
      expect(body.status).toBe('completed');
      return true;
    })
    .reply(200);

  await task.notify();
  expect(callbackScope.isDone()).toBe(true);
});
```

**Environment variable testing** requires `jest.resetModules()` when the config module caches values at import time:

```typescript
const originalEnv = process.env;

beforeEach(() => {
  jest.resetModules();
  process.env = { ...originalEnv };
});

afterEach(() => { process.env = originalEnv; });

it('uses default port when PORT not set', () => {
  delete process.env.PORT;
  const config = require('./config');
  expect(config.port).toBe(8080);
});
```

Set baseline test environment variables in a setup file referenced by `jest.config.ts`:

```javascript
// tests/setup.ts
process.env.S3_BUCKET = 'test-bucket';
process.env.AWS_REGION = 'us-east-1';
process.env.CESIUM_ION_TOKEN = 'test-token';
process.env.NODE_ENV = 'test';
```

---

## 7. What genuinely requires integration tests

Not everything can or should be unit tested. Here is an honest assessment:

**Unit testable with mocking (~70% of logic):** command-line argument construction for all binaries, stdout/stderr parsing, exit code handling, S3 upload/download orchestration logic, multi-region bucket routing, presigned URL generation logic, strategy selection and orchestration, TaskManager queue logic (max parallel, pause/resume, cleanup), pipeline state transitions, all error handling paths, all pure utility functions, config loading, validators, and Express endpoint routing.

**Requires integration tests (~30% of logic):** actual binary output format compatibility (does the real point-cloud-tiler produce output your parser expects?), actual S3 upload/download with large files and multipart, actual archive extraction with 7z producing expected directory structures, Cesium Ion API behavior with real assets, end-to-end pipeline with real test fixtures, cross-platform filesystem behavior, and actual process lifecycle (memory limits, concurrent process management).

**Recommended integration test infrastructure** is Docker Compose with a `Dockerfile.test` installing all required binaries (p7zip-full, imagemagick, default-jre, awscli) plus MinIO for S3-compatible storage, and small test fixture files (~KB each) stored in `tests/fixtures/`. Use **Testcontainers for Node.js** (`testcontainers` npm package) to programmatically manage Docker containers within integration tests when needed.

---

## 8. Phased adoption plan: from zero to comprehensive coverage

### Phase 0 — Infrastructure (day 1-2)

Install Jest + ts-jest + @types/jest. Create `jest.config.ts`, `tests/setup.ts`, and `tests/helpers/` directory. Add npm scripts: `test`, `test:unit`, `test:integration`, `test:watch`, `test:coverage`. Get one passing test (`expect(true).toBe(true)`) to validate the pipeline. Export the Express app from a `createApp()` function separate from `app.listen()`.

### Phase 1 — Pure functions, maximum confidence (week 1)

Test `statusCodes.ts`, `taskErrorInfos.ts`, `utils.ts` (file counting/filtering), `bucketConfig.ts`, and `bucketConfigMgr.ts`. These need zero mocking and build team confidence in the testing infrastructure. Target **100% coverage** on these modules. This also establishes testing conventions and patterns for the team.

### Phase 2 — Config and validators (weeks 2-3)

Test `config.ts` with environment variable manipulation and `jest.resetModules()`. Test filesystem validators (`assetInputValidator.ts`, `existsTilesetJSON.ts`, `countOfFilesOfDirectory.ts`, `georeferencedAtECEF.ts`) using `memfs` or `jest.mock('fs-extra')`. This phase introduces mocking skills without the complexity of child processes or network calls.

### Phase 3 — Strategy classes (weeks 3-5)

Mock `child_process.spawn()` using EventEmitter fakes. Mock S3 with `aws-sdk-client-mock`. Mock HTTP calls with nock. Test each tiling strategy in isolation. Extract command-construction pure functions from spawn-calling code. This phase delivers the highest-value tests for the core business logic.

### Phase 4 — Task.ts and TaskManager (weeks 5-8)

Add `TaskManager.resetForTesting()`. Write characterization tests for Task.ts capturing current behavior. Test each pipeline stage independently with mocked methods. Test all 30+ error handling paths. Begin **Extract Method** refactoring, pulling testable logic into smaller functions with their own tests. Use the **Sprout Method** for all new functionality — never add untested code.

### Phase 5 — API endpoints and integration (week 8+)

Add Supertest endpoint tests for all GET routes. Set up Docker Compose with MinIO for S3 integration tests. Create small test fixture files for each binary format. Add a separate GitHub Actions job for integration tests. Configure CI with environment variable stubs and separate unit/integration pipelines:

```yaml
jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '18.16.0', cache: 'npm' }
      - run: npm ci
      - run: npm run test:unit

  integration-tests:
    runs-on: ubuntu-latest
    needs: unit-tests
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '18.16.0', cache: 'npm' }
      - run: npm ci
      - run: npm run test:integration
```

### The governing rule going forward

**All new code is written with TDD.** Use Sprout Method to add tested new code alongside untested legacy code. Over time, the tested portion grows until it dominates. Inside-out (unit tests first) is the right approach for this codebase because there are clear pure utility layers at the bottom, and outside-in endpoint tests would require mocking the entire pipeline simultaneously — overwhelming when starting from zero.

---

## 9. Recommended project structure and key resources

```
project-root/
├── src/                          # existing source code
├── tests/
│   ├── unit/
│   │   ├── utils.test.ts         # Phase 1
│   │   ├── statusCodes.test.ts
│   │   ├── bucketConfig.test.ts
│   │   ├── config.test.ts        # Phase 2
│   │   ├── validators/
│   │   │   ├── assetInputValidator.test.ts
│   │   │   └── existsTilesetJSON.test.ts
│   │   ├── strategies/           # Phase 3
│   │   │   ├── meshTiling.test.ts
│   │   │   ├── pointCloudTiling.test.ts
│   │   │   ├── imageryTiling.test.ts
│   │   │   └── existingTiles.test.ts
│   │   ├── taskManager.test.ts   # Phase 4
│   │   └── task.test.ts
│   ├── integration/
│   │   ├── routes.test.ts        # Phase 5
│   │   └── s3Upload.test.ts
│   ├── fixtures/
│   │   ├── sample.las            # minimal point cloud
│   │   ├── sample.7z             # small test archive
│   │   ├── tileset.json          # valid tileset structure
│   │   └── sample.tif            # minimal GeoTIFF
│   ├── helpers/
│   │   ├── mockChildProcess.ts   # reusable spawn mock
│   │   └── testUtils.ts          # shared test utilities
│   └── setup.ts                  # environment variables, global setup
├── jest.config.ts
├── tsconfig.json
├── tsconfig.test.json            # extends tsconfig.json, includes tests/
└── docker-compose.test.yml       # MinIO for integration tests
```

## Conclusion

The path from zero tests to a well-tested codebase does not require a major rewrite. Jest's module-level mocking (`jest.mock()`) is specifically designed for code without dependency injection — it intercepts `require()` calls and replaces entire modules, which is exactly what's needed for the tightly coupled S3 clients, child process spawns, and HTTP calls in this codebase. The single most impactful architectural change is **separating command construction from execution** for all seven spawned binaries — this converts the hardest-to-test logic into trivially testable pure functions. The second most impactful change is adding `TaskManager.resetForTesting()` to enable test isolation. Everything else can be tested as-is through mocking. Start with Phase 1 pure functions this week, and within two months the critical paths through the tiling pipeline will be covered. The key discipline: every new line of code gets written test-first using TDD, and legacy code gets characterization tests before any refactoring touches it.