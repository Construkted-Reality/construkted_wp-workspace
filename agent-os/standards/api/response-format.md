# API Response Format

All API responses use `http.send()` with consistent structure.

## Response Structure
```json
{
  "errCode": 0,
  "errMsg": "message",
  "...additional fields"
}
```

## Error Codes
- `0` = SUCCESS - Operation completed
- `1` = INVALID_PARAMETER - Missing or invalid request parameter

## Usage
```typescript
import * as http from "./lib/http";
import * as global from "./global";

// Success
http.send(res, global.ERROR_SUCCESS, "tiling started", {});

// Missing parameter
http.send(res, global.ERROR_INVALID_PARAMETER, "postId required!", {});

// Success with data
http.send(res, global.ERROR_SUCCESS, "", { isSuccessfulDelete: true });
```

## Endpoint Validation Pattern
Check required parameters early, return immediately on missing:
```typescript
if (!postId) {
  http.send(res, global.ERROR_INVALID_PARAMETER, "postId required!", {});
  return;
}
```

## Source files
- `construkted_api/lib/http.ts` - send() function
- `construkted_api/global.ts` - error constants
