# Task Lifecycle

Tasks progress through states during 3D asset processing. Terminal states cannot be retried.

## State Diagram

```
QUEUED (10)
    ↓
RUNNING (20) ←→ PAUSED (21)
    ↓
CPU_INTENSIVE_RUNNING_QUEUED (30)
    ↓
    ├── COMPLETED (50)  [terminal]
    ├── FAILED (40)     [terminal]
    └── CANCELED (60)   [terminal]
```

## Status Codes

| Code | State | Description |
|------|-------|-------------|
| 10 | QUEUED | Waiting in general queue |
| 20 | RUNNING | Actively processing (download, validate, upload) |
| 21 | PAUSED | Temporarily paused due to low memory |
| 30 | CPU_INTENSIVE_RUNNING_QUEUED | Waiting for CPU-intensive queue slot |
| 40 | FAILED | Processing failed (terminal) |
| 50 | COMPLETED | Successfully finished (terminal) |
| 60 | CANCELED | User canceled (terminal) |

## Running Status (sub-state while RUNNING)

| Code | State | Description |
|------|-------|-------------|
| 0 | NONE | Not yet started |
| 10 | PROCESSING_DRONE_IMAGE | Processing drone imagery |
| 20 | DOWNLOADING_ZIP | Downloading input from S3 |
| 30 | TILING | Running tiling tool |
| 40 | UPLOADING_TILES | Uploading results to S3 |

## Terminal States

FAILED, COMPLETED, and CANCELED are terminal:
- No retry mechanism - user must submit a new task
- Auto-cleaned after 48 hours (`cleanupTasksAfter: 2880` minutes)

## Key Task Properties

```typescript
task.status.code      // StatusCodes enum value
task.runningStatus    // RunningStatusCodes enum value
task.dateCreated      // Timestamp
task.dateStarted      // Timestamp when RUNNING began
task.processingTime   // Total processing duration
```
