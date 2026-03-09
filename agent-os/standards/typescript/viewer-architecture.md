# Viewer Architecture

Singleton `Construkted` class provides unified API for all viewer types.

## Entry Point
```typescript
// index.ts - DOM ready handler
window.Construkted = new Construkted({ ajax: parsedConstruktedAjax });
```

## Type Detection
Content type determined by `CONSTRUKTED_AJAX` data from WordPress:
```typescript
// Check type before accessing type-specific APIs
if (window.Construkted.isTilesetAsset()) {
    const asset = window.Construkted.masterAsset;
}
if (window.Construkted.isProject()) {
    const assets = window.Construkted.projectAssetGroup;
}
```

## Available Viewer Types
- `isTilesetAsset()` → Single 3D tile/point cloud (`AssetViewer`)
- `isProject()` → Collection of assets (`ProjectViewer`)
- `isOrthomosaic()` → TMS tiles (`OrthomosaicViewer`)
- `isAssetExplorer()` → Globe browser (`AssetExplorerV2`)

## Access Pattern
```typescript
// Always access via singleton
const construkted = window.Construkted;
construkted.cesiumViewer;  // Cesium Viewer instance
construkted.scene;         // Cesium Scene
construkted.camera;        // Cesium Camera
```
