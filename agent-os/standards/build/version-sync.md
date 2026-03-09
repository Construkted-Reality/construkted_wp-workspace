# Version Synchronization

Keep version numbers in sync across both repositories.

## Version Locations
| File | Location |
|------|----------|
| `construkted.js/package.json` | `"version": "4.11.0"` |
| `gowatch-child/functions.php` | `define('CONSTRUKTED_VERSION', '4.11.0')` |

## Update Process
When releasing a new version:

1. Update `package.json` version:
```json
"version": "4.12.0"
```

2. Update `functions.php` constant:
```php
define('CONSTRUKTED_VERSION', '4.12.0');
```

3. Update CHANGELOG.md in both repos

4. Build and test

5. Commit both repos with matching version tags

## Why Sync Matters
- WordPress uses `CONSTRUKTED_VERSION` for cache-busting script URLs
- Mismatched versions cause stale JavaScript to be served
- Settings popup displays version for debugging
