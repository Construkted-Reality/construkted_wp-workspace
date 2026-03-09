# wp_localize_script Bridge

Pass PHP data to JavaScript via global variables.

## Pattern
```php
// In construkted.php
wp_localize_script(
    'construkted-script',      // Script handle
    'CONSTRUKTED_AJAX',        // JS variable name
    array(
        'ajaxurl' => admin_url('admin-ajax.php'),
        'post_id' => $post_id,
        'is_owner' => $is_owner,
        // ... more data
    )
);
```

## Access in JavaScript
```javascript
const CONSTRUKTED_AJAX = window.CONSTRUKTED_AJAX;
CONSTRUKTED_AJAX.post_id;   // PHP value available in JS
CONSTRUKTED_AJAX.ajaxurl;   // WordPress admin-ajax URL
```

## Multiple Globals
For project pages, multiple globals are set:
```php
wp_localize_script('construkted-script', 'CONSTRUKTED_AJAX', $main_data);
wp_localize_script('construkted-script', 'project_assets', $assets);
wp_localize_script('construkted-script', 'annotations', $annotations);
wp_localize_script('construkted-script', 'currentUser', $user_detail);
```

## JSON Handling
Strip slashes for JSON strings stored in post meta:
```php
'asset_geo_location' => stripslashes($json_from_meta),
```
