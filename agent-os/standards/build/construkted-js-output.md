# construkted.js Build Output

Built JS files must be copied to the WordPress theme.

## Destination

```
construkted_reality_v1.x/wp-content/themes/gowatch-child/includes/construkted/assets/js/
```

## Automated Copy (Development)

Set `LOCAL_DEV_DIR` in `construkted.js/.env`:

```env
LOCAL_DEV_DIR=../construkted_reality_v1.x/wp-content/themes/gowatch-child/includes/construkted/assets/js
```

Vite copies `construkted.js` and `construkted.js.map` on build completion.

## Build Commands

```bash
# Development with watch
npm run dev

# Production build
npm run build
```

## Manual Copy

When automation fails, copy these files manually:
- `construkted.js/dist/construkted.js`
- `construkted.js/dist/construkted.js.map`

## Files Produced

| File | Purpose |
|------|----------|
| `construkted.js` | Main viewer library |
| `construkted.js.map` | Source maps for debugging |
