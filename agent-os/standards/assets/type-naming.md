# Asset Type Naming

Asset types use different string formats across systems. New code should prefer PascalCase.

## Canonical Types (PascalCase - preferred)

```typescript
// construkted_api/lib/tiling/assetModelTypes.ts
PolygonMesh   // 3D mesh with textures (OBJ/MTL)
PointCloud    // Point cloud data (LAS/LAZ)
ThreeDTiles   // Pre-tiled 3D Tiles (tileset.json) - note: code uses "3DTile"
Orthomosaic   // GeoTIFF imagery
CAD           // 3D CAD models - note: code uses "3DCADModel"
Unknown       // Unrecognized type
```

## Format by Context

| Context | Format | Example |
|---------|--------|---------|
| Backend TypeScript | PascalCase | `PolygonMesh` |
| WordPress form values | kebab-case | `polygon-mesh` |
| WordPress display | Title Case | `Polygon Mesh` |
| Frontend JS enum | kebab-case | `polygon-mesh` |

## Conversion

WordPress converts form input to backend format via:

```php
// gowatch-child/includes/frontend-submission/class/frontend-form-post.php
convert_asset_type_from_gowatch_to_edd6($asset_type)

// polygon-mesh  → Polygon Mesh
// point-cloud   → Point Cloud
// 3d-tile       → 3D Tile
// 3d-cad-model  → 3D CAD Model
// Orthomosaic   → Orthomosaic
```

## Locations to Update for New Type

1. `construkted_api/lib/tiling/assetModelTypes.ts` - Add PascalCase constant
2. `gowatch-child/includes/frontend-submission/class/frontend-form-post.php` - Add conversion
3. `construkted.js/src/types/common.ts` - Add to `ConstruktedAssetType` enum
