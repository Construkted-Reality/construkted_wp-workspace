# Task Status Codes

Numeric codes with gaps for future expansion. **Must match WordPress theme constants exactly.**

## StatusCodes (Task lifecycle)
```typescript
QUEUED = 10      // Waiting to start
RUNNING = 20     // Actively processing
PAUSED = 21      // Paused (insufficient memory for UltraMesh)
CPU_INTENSIVE_RUNNING_QUEUED = 30  // Waiting for CPU-intensive slot
FAILED = 40      // Error occurred
COMPLETED = 50   // Success
CANCELED = 60    // User canceled
```

## RunningStatusCodes (Sub-states during RUNNING)
```typescript
NONE = 0
PROCESSING_DRONE_IMAGE = 10
DOWNLOADING_ZIP = 20
TILING = 30
UPLOADING_TILES = 40
```

## Sync locations
- API: `construkted_api/lib/statusCodes.ts`
- WordPress: `construkted_reality_v1.x/.../constants.php` (TILING_STATUS_CODE_*)
