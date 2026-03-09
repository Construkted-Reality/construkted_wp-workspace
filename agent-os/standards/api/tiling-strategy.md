# Tiling Strategy Pattern

Each asset type has its own strategy class. **Always create a new class for new asset types.**

## Interface
```typescript
interface TilingStrategy {
  run(): Promise<void>;
}
```

## Implementations
| Strategy | Asset Type | External Tool |
|----------|------------|---------------|
| MeshTilingStrategy | PolygonMesh | UltraMesh or Cesium Ion |
| PointCloudTilingStrategy | PointCloud | Cesium 3D Tiling Pipeline |
| ImageryTilingStrategy | Orthomosaic | Custom (gdal2tiles style) |
| ExistingTilesTilingStrategy | 3D Tiles | None (passthrough) |

## Creating a New Strategy
1. Create `lib/tiling/{name}TilingStrategy.ts`
2. Implement `TilingStrategy` interface
3. Handle: validation, subprocess spawning, progress tracking, error handling
4. Call `task._uploadTiledFolder()` on success
5. Call `task._failed(errorInfo)` on failure
6. Add case in `task.ts` `_doStartTiling()` method

## Key Patterns
- Use `task.setRunningStatus()` for progress tracking
- Store subprocess in `task.setRunningProcess()` for cancellation
- Check for `SIGKILL` signal to handle task cancellation
- Use `taskErrorInfos` for consistent error reporting

## Source files
`construkted_api/lib/tiling/`
