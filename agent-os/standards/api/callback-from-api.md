# API Callback to WordPress

construkted_api calls back to WordPress to update asset status.

## Endpoint

```
/wp-content/themes/gowatch-child/control_asset_details.php
```

## Actions

| Action | Purpose |
|--------|----------|
| `update_custom_fields` | Update triangle count, point count, texture resolution |
| `report_error` | Report tiling failure with error code and message |
| `delete_attachment` | Remove attachments from processed asset |

## Request Format

```
GET ?post_id=123&action=update_custom_fields&count_of_triangles=50000&...
GET ?post_id=123&action=report_error&error_code=ERR001&error_msg=...
```

## IP Whitelisting

Only allowed IPs can call this endpoint. Add new processing server IPs to `$allowedIPs` array in:

```
control_asset_details.php (line ~14)
```

## Security

- No authentication token required
- IP whitelist is the only protection
- All parameters passed via query string (GET)
