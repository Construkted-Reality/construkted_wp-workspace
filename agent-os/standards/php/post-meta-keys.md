# Post Meta Key Naming

Use `snake_case` for all post meta keys.

## Format

```php
// Correct
get_post_meta($id, 'view_access', true);
get_post_meta($id, 'uploaded_file_size', true);
get_post_meta($id, 'default_camera_position_direction', true);

// Wrong
get_post_meta($id, 'viewAccess', true);      // camelCase
get_post_meta($id, 'view-access', true);     // kebab-case
```

## Common Meta Keys

| Key | Type | Purpose |
|-----|------|----------|
| `view_access` | string | public/private/password |
| `uploaded_file_size` | int | File size in bytes |
| `asset_type` | string | Asset classification |
| `default_camera_position_direction` | JSON | Camera state |
| `terrain_imagery_enabled` | bool | Terrain toggle |
| `project_assets` | JSON | Array of asset IDs |

## Legacy Exception

`asset_geo-location` uses hyphen (legacy). Don't change existing keys, but use `snake_case` for all new keys.
