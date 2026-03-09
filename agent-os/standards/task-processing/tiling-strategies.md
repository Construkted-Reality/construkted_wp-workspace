# Tiling Strategies

Each 3D asset type has a dedicated strategy class for processing. New asset types require a new strategy.

## Interface

All strategies implement `TilingStrategy`:

```typescript
// lib/tiling/tilingStrategy.ts
export interface TilingStrategy {
    run(): Promise<void>;
}
```

## Asset Types → Strategies

| Asset Type | Strategy Class | Input Files | External Tool |
|------------|----------------|-------------|---------------|
| PolygonMesh | `MeshTilingStrategy` | OBJ + MTL | UltraMesh |
| PointCloud | `PointCloudTilingStrategy` | LAS, LAZ | Cesium Ion Pipeline |
| 3DTile | `ExistingTilesTilingStrategy` | tileset.json | None (pre-tiled) |
| Orthomosaic | `ImageryTilingStrategy` | GeoTIFF | GraphicsMagick |

## Asset Type Constants

```typescript
// lib/tiling/assetModelTypes.ts
export const AssetModelTypes = {
    Unknown: "Unknown",
    PolygonMesh: "PolygonMesh",
    PointCloud: "PointCloud",
    ThreeDTiles: "3DTile",
    CAD: "3DCADModel",
    Orthomosaic: "Orthomosaic"
};
```

## Adding a New Asset Type

1. Add type to `AssetModelTypes` in `lib/tiling/assetModelTypes.ts`
2. Create `lib/tiling/newTypeTilingStrategy.ts` implementing `TilingStrategy`
3. Add validation rules in `lib/validation/assetInputValidator.ts`
4. Update task creation logic to select the new strategy
5. Update WordPress constants in `gowatch-child/functions.php`

## Strategy Location

All strategy files live in `construkted_api/lib/tiling/`:

```
lib/tiling/
├── tilingStrategy.ts           # Interface
├── assetModelTypes.ts          # Type constants
├── meshTilingStrategy.ts       # PolygonMesh
├── pointCloudTilingStrategy.ts # PointCloud
├── imageryTilingStrategy.ts    # Orthomosaic
└── existingTilesTilingStrategy.ts # Pre-tiled 3DTiles
```
