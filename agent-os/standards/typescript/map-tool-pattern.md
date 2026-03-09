# MapTool Pattern

Abstract base class for interactive canvas tools (measurement, drawing, editing).

## Creating a Tool
```typescript
import { MapTool, MapToolConstructorOptions, MouseEvent } from './core/MapTool';

export class MyTool extends MapTool {
    constructor(options: MapToolConstructorOptions) {
        super({ ...options, name: 'MyTool', cursorStyle: 'crosshair' });
    }

    // Override event handlers as needed
    canvasPressEvent(event: MouseEvent) { /* left click */ }
    canvasReleaseEvent(event: MouseEvent) { /* mouse up */ }
    canvasMoveEvent(event: MouseEvent) { /* mouse move */ }
    canvasDoubleClickEvent(event: MouseEvent) { /* double click */ }
    keyPressEvent(event: KeyboardEvent) { /* key down */ }
}
```

## Lifecycle
Tools are mutually exclusive - only one active at a time:
```typescript
// Activate (deactivates previous tool automatically)
window.Construkted.setMapTool(myTool, activateOptions);

// Deactivate current tool
window.Construkted.deactivateCurrentMapTool();
```

## World Position Picking
```typescript
// Pick 3D position on tileset or terrain
const worldPos = this.getWorldPosition(event.pos, new Cartesian3());

// Pick only on 3D tilesets (ignores terrain)
const tilesetPos = this.getWorldPositionOn3DTiles(event.pos, new Cartesian3());
```

## Events
Tools emit `activated` and `deactivated` events for UI updates.
