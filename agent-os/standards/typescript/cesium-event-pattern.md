# Cesium Event Pattern

Use Cesium's `Event` class for reactive property change notifications.

## Declaring Events
```typescript
import { Event } from 'cesium';

class MyClass {
    private readonly _positionChanged: Event = new Event();
    private readonly _ready: Event = new Event();

    get positionChanged() { return this._positionChanged; }
    get ready() { return this._ready; }
}
```

## Raising Events
```typescript
// Raise with data
this._positionChanged.raiseEvent(this._position);

// Raise without data
this._ready.raiseEvent();
```

## Subscribing
```typescript
const removeCallback = asset.positionChanged.addEventListener((position) => {
    console.log('New position:', position);
});

// Later: unsubscribe
removeCallback();
```

## Common Events in Codebase
- `readyEvt` - Asset finished loading
- `positionChanged` - Asset moved
- `geolocationChanged` - Geolocation updated
- `geoRefChanged` - Reference point changed
- `activated` / `deactivated` - MapTool lifecycle
- `loadProgress` - Tile loading progress
