# TypeScript Build Workflow

Build construkted.js and deploy to WordPress theme.

## Setup
1. Copy `.env.example` to `.env`
2. Set `BUILD_OUTPUT_PATH` to your WordPress theme JS directory:
```
BUILD_OUTPUT_PATH=/path/to/wp-content/themes/gowatch-child/includes/construkted/assets/js
```

## Development
```bash
cd construkted.js
npm run dev    # Vite watch mode - rebuilds on save, auto-copies to WordPress
```
- Watches `src/**/*.ts`, `src/**/*.css`
- Outputs to `dist/construkted.js`
- Auto-copies to `BUILD_OUTPUT_PATH`

## Production Build
```bash
npm run build   # Gulp build task
```
- Runs Rollup with release config
- Obfuscates via javascript-obfuscator
- Output: `build/construkted.js`

## Linting
```bash
npm run lint    # ESLint + TypeScript check
```
Must pass before commits (Husky pre-commit hook).

## Output
| Command | Output | Size |
|---------|--------|------|
| `npm run dev` | `dist/construkted.js` + `.map` | ~10MB |
| `npm run build` | `build/construkted.js` | Obfuscated |
