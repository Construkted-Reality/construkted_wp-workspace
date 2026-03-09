# Post Meta Storage

Asset data stored as WordPress post meta fields.

## Common Meta Keys
| Key | Type | Description |
|-----|------|-------------|
| `asset_geo-location` | JSON | Visual editor geolocation |
| `asset_geo_location_by_pre` | JSON | Pre-defined geolocation |
| `asset_geo_location_by_gcp` | JSON | GCP editor geolocation |
| `active_editor` | string | Which editor was used |
| `asset_type` | string | "3d-tile", "point-cloud", etc. |
| `asset_is_underground` | bool | Underground rendering flag |
| `terrain_imagery_enabled` | bool | Show terrain/imagery |
| `bg_color` | string | CSS background color |
| `default_camera_position_direction` | JSON | Saved camera view |
| `new_style_url` | bool | New tileset URL format |

## Reading
```php
$geo = get_post_meta($post_id, 'asset_geo-location', true);
```

## Writing
```php
update_post_meta($post_id, 'asset_geo-location', $json_string);
```

## JSON Values
Store complex data as JSON strings, parse in JavaScript:
```php
// PHP: store as string
update_post_meta($post_id, 'asset_geo-location', json_encode($data));

// JS: parse when received
const geo = JSON.parse(CONSTRUKTED_AJAX.asset_geo_location);
```
