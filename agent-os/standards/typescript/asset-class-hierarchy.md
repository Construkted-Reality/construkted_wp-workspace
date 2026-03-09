# Asset Class Hierarchy

Abstract base class for all displayable assets (3D tiles, point clouds, orthomosaics).

## Base Class
```typescript
import { Asset } from './core/Asset';

export abstract class Asset {
    protected _type: ConstruktedAssetType;
    protected _ready: boolean = false;
    protected readonly _readyEvt: Event = new Event();

    // Type checking
    isTileset(): boolean;   // 3D tiles, point clouds, polygon meshes
    isTMSTiles(): boolean;  // Orthomosaics

    // Required abstract methods
    abstract toggle(): void;
    abstract setSplitDirection(left: boolean, right: boolean): void;
}
```

## Subclasses
- `TilesetAsset` - 3D Tiles, point clouds, polygon meshes (Cesium3DTileset)
- `TMSTilesAsset` - Orthomosaic imagery (ImageryLayer)
- `TilesetAssetGroup` - Collection of TilesetAssets

## Ready Pattern
Assets load asynchronously:
```typescript
const asset = new TilesetAsset(options);

// Check if ready
if (asset.ready) { /* use immediately */ }

// Or wait for ready event
asset.readyEvt.addEventListener(() => {
    // Safe to access asset.tileset
});
```

## Type Identification
```typescript
if (asset.isTileset()) {
    const tileset = (asset as TilesetAsset).tileset;
}
if (asset.isTMSTiles()) {
    const layer = (asset as TMSTilesAsset).imageryLayer;
}
```
