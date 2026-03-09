# Task Queue System

The backend uses two parallel queues to prevent CPU-intensive operations from starving lighter tasks.

## Queues

| Queue | Max Parallel | Purpose |
|-------|--------------|---------|
| General | 50 | Downloading, validation, uploading |
| CPU-Intensive | 5 | Mesh/point cloud tiling (limited by server RAM/CPU) |

## Configuration

In `config.ts`:

```typescript
maxParallelTaskCount: 50,           // General queue
maxCpuIntensiveParallelTaskCount: 5 // CPU-intensive queue
```

## How Tasks Move Between Queues

1. New task enters general queue as `QUEUED`
2. When slot available, moves to `RUNNING` (downloading, validating)
3. When ready for tiling, moves to `CPU_INTENSIVE_RUNNING_QUEUED`
4. When CPU slot available, tiling begins
5. After tiling, returns to general queue for upload

## Key Methods

```typescript
// TaskManager
processNextTask()              // Check general queue
processNextCpuIntensiveTask()  // Check CPU queue
addToRunningQueue(task)
addToCpuIntensiveRunningQueue(task)
```

## Paused Queue

Tasks can be paused if system memory is insufficient (`PAUSED` status). They resume automatically when `processNextTask()` runs.
