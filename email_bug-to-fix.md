# Bug Report: User Failure Notification Email Never Sent

## Summary

When an asset fails processing, the user who owns the asset **never receives their failure notification email**. Only the admin email (`info@construkted.com`) is delivered successfully.

## Affected File

`construkted_reality_v1.x/wp-content/themes/gowatch-child/control_asset_details.php`

## Root Cause

The `report_error` action handler (lines 175-191) uses `wp_get_current_user()` to obtain the user's email address before sending the failure notification. However, this endpoint is **not called by a logged-in WordPress user** -- it is called by **external tile-processing servers** (whitelisted by IP on lines 14-25). In this context, `wp_get_current_user()` returns a default/empty `WP_User` object with no email, so `$user_mail` is empty and `wp_mail()` silently fails.

### The Broken Code (lines 184-188)

```php
$current_user = wp_get_current_user();
$user_mail = $current_user->user_email;  // <-- Always empty; no user is logged in

send_mail_to("info@construkted.com", "Asset processing fails", $error_msg);  // Works fine
send_mail_to($user_mail, "Asset processing fails", $error_msg);              // Fails silently
```

### The Same Bug Exists in the Success Handler (lines 279-283)

```php
$current_user = wp_get_current_user();
$user_mail = $current_user->user_email;  // <-- Also empty

send_mail_to("info@construkted.com", "Asset prepared");   // Works fine
send_mail_to($user_mail, "Asset prepared");                // Fails silently
```

This means users also never receive the "Asset prepared" success notification.

## The Fix

The `send_mail_to()` function (lines 113-136) already retrieves the **post author** from the post ID:

```php
$author_id = get_post_field('post_author', $post_id);
$author_display_name = get_the_author_meta('display_name', $author_id);
```

The user's email should be obtained from the post author, not from `wp_get_current_user()`.

### Suggested Fix for `report_error` (lines 184-188)

Replace:
```php
$current_user = wp_get_current_user();
$user_mail = $current_user->user_email;
```

With:
```php
$author_id = get_post_field('post_author', $post_id);
$user_mail = get_the_author_meta('user_email', $author_id);
```

### Suggested Fix for `update_custom_fields` (lines 279-280)

Same replacement -- use the post author's email instead of `wp_get_current_user()`.

## Impact

- **Both** user-facing emails are affected: failure ("Asset processing fails") and success ("Asset prepared").
- Users have no email notification that their asset finished processing (success or failure).
- The admin email (`info@construkted.com`) is unaffected and works correctly.
- The dashboard UI error display is also unaffected (it reads from `last_error_msg` post meta, not email).

## How to Verify the Fix

1. Upload an asset and trigger processing.
2. Simulate a failure by calling the endpoint with `action=report_error` from an allowed IP.
3. Confirm that the asset owner receives the failure email at their registered email address.
4. Repeat for the success path (`action=update_custom_fields`) and confirm the "Asset prepared" email arrives.

## Additional Context

- The endpoint file handles requests from external tile-processing servers, authenticated only by IP whitelist (lines 14-25).
- No WordPress session/cookie is present on these requests, which is why `wp_get_current_user()` fails.
- The `send_mail_to()` function uses `wp_mail()` internally, which returns `false` when the `$to` parameter is empty, but the return value is never checked by the callers.
