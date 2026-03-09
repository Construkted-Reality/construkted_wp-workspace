# AJAX Handler Pattern

WordPress AJAX endpoint registration and response handling.

## Registering Handlers
```php
// For logged-in users only
add_action('wp_ajax_my_action', 'my_handler_function');

// For both logged-in and guest users
add_action('wp_ajax_nopriv_my_action', 'my_handler_function');
add_action('wp_ajax_my_action', 'my_handler_function');
```

## Handler Function Pattern
```php
function my_handler_function() {
    $post_id = intval($_POST['post_id']);
    $data = sanitize_text_field($_POST['data']);

    $ret = array('success' => false, 'message' => '');

    // Perform operation
    $success = update_post_meta($post_id, 'my_meta', $data);

    if ($success) {
        $ret['success'] = true;
    } else {
        $ret['message'] = 'Failed to update!';
    }

    wp_send_json($ret);
    exit;
}
```

## Response Format
- Use `wp_send_json($data)` for JSON responses
- Use `wp_die()` after plain text responses
- Standard response: `{ success: bool, message: string, data?: any }`

## Permission Checks
Add nonce verification for sensitive operations:
```php
check_ajax_referer('my_nonce_action', 'nonce');
```
