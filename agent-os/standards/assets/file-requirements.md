# Asset File Requirements

Each asset type requires specific files for successful processing.

## Requirements by Type

### PolygonMesh

| Required | Extensions | Notes |
|----------|------------|-------|
| Yes | `.obj` | Wavefront OBJ mesh file |
| Yes | `.mtl` | Material library (required if OBJ exists) |
| Yes | texture images | Referenced by MTL file |

### PointCloud

| Required | Extensions | Notes |
|----------|------------|-------|
| Yes (one of) | `.las`, `.laz` | LAS or compressed LAZ format |

### 3DTiles (ThreeDTiles)

| Required | Extensions | Notes |
|----------|------------|-------|
| Yes | `.json` | tileset.json file |
| Yes | `.b3dm`, `.pnts`, etc. | Referenced tile files |

### Orthomosaic

| Required | Extensions | Notes |
|----------|------------|-------|
| Yes | `.tif`, `.tiff` | GeoTIFF with georeferencing |

## Validation Location

```typescript
// construkted_api/lib/validation/assetInputValidator.ts
validateAssetInput(assetModelType: string, root: string): ValidationFailure | null
```

Validation functions:
- `validatePolygonMesh()` - Checks for OBJ+MTL pair
- `validatePointCloud()` - Checks for LAS/LAZ
- `validate3DTiles()` - Checks for JSON
- `validateOrthomosaic()` - Checks for TIF/TIFF

## Upload Format

Users upload a ZIP archive containing the required files. The validator extracts and recursively scans for required extensions.
