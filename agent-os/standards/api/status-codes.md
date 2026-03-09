# Task Status Codes

Unified codes for tracking 3D asset tiling task state. Must match across all projects.

## Codes

| Code | Name | Description |
|------|------|-------------|
| 10 | QUEUED | Task waiting in general queue |
| 20 | RUNNING | Task actively processing |
| 21 | PAUSED | Task paused (memory insufficient) |
| 30 | CPU_INTENSIVE_RUNNING_QUEUED | Waiting for CPU-intensive queue slot |
| 40 | FAILED | Task failed |
| 50 | COMPLETED | Task finished successfully |
| 60 | CANCELED | Task canceled by user |

## Locations

Update ALL when adding/changing codes:

- **construkted_api**: `lib/statusCodes.ts` (TypeScript enum)
- **gowatch-child**: `functions.php` (PHP constants `TILING_STATUS_CODE_*`)
- **gowatch-child**: `includes/frontend-submission/assets/js/dashboard.js` (JS object)

## Usage

```typescript
// Backend (TypeScript)
import { StatusCodes } from './lib/statusCodes';
task.setStatus(StatusCodes.COMPLETED);
```

```php
// WordPress (PHP)
if ($status_code == TILING_STATUS_CODE_FAILED) { ... }
```

```javascript
// Frontend (JS)
if (statusCode === statusCodes.COMPLETED) { ... }
```
