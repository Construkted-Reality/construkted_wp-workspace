---
title: "Bug: Orthomosaic Uploader maxFiles Parameter Incorrect"
type: fix
status: draft
date: 2026-03-05
severity: low
discovered_during: S3 5GB upload limit investigation
---

# Bug: Orthomosaic Uploader Passes maxFileSize as maxFiles

## Summary

In `construkted.uploadjs/src/frontend-form.ts:112`, the orthomosaic uploader passes `maxFileSize` (52,428,800) as the `maxFiles` constructor argument. This effectively removes the file count limit for orthomosaic uploads.

## Evidence

**Constructor signature** (`TSZF_UPloader.ts:23-30`):
```typescript
constructor(
    browseButtonId: string,
    containerId: string,
    maxFiles: number,       // ← 3rd param
    type: string,
    allowedType: string,
    maxFileSize: number     // ← 6th param
)
```

**Correct usage** (photogrammetry, line 82-89):
```typescript
this._tszfPhotogrammetryUploader = new TSZFUploader(
    "tszf-photogrammetry-pickfiles",
    "tszf-photogrammetry-upload-container",
    maxFiles,       // ← correct: small integer (10)
    "photogrammetry_asset",
    "zip,rar,7z",
    maxFileSize
);
```

**Bug** (orthomosaic, line 109-116):
```typescript
this._tszfOrthomosaicUploader = new TSZFUploader(
    "tszf-orthomosaic_upload-pickfiles",
    "tszf-orthomosaic_upload-upload-container",
    maxFileSize,    // ← BUG: 52,428,800 passed as maxFiles
    "orthomosaic_upload_asset",
    "zip,rar,7z,tif,tiff",
    maxFileSize
);
```

## Impact

- Orthomosaic uploader allows ~52 million files instead of the intended limit (likely 10)
- Low severity: users are unlikely to exploit this accidentally
- The `_onFilesAdded` method does check `this._maxFiles` (line 313), but with a limit of 52M it's effectively no limit

## Likely Fix

Change line 112 from `maxFileSize` to `maxFiles`:

```typescript
this._tszfOrthomosaicUploader = new TSZFUploader(
    "tszf-orthomosaic_upload-pickfiles",
    "tszf-orthomosaic_upload-upload-container",
    maxFiles,       // ← fix
    "orthomosaic_upload_asset",
    "zip,rar,7z,tif,tiff",
    maxFileSize
);
```

## Open Questions

- What should the actual `maxFiles` value be for orthomosaic uploads? The other uploaders use `maxFiles` which is set to 10 at `frontend-form.ts:78`. Is 10 correct for orthomosaic?
- Are there users relying on uploading more than 10 orthomosaic files at once?
