---
title: "fix: User Failure/Success Notification Email Never Sent"
type: fix
status: completed
date: 2026-02-22
reviewed: true
---

# fix: User Failure/Success Notification Email Never Sent

## Overview

When an asset fails or succeeds processing, the user who owns the asset **never receives their notification email**. Only the admin email (`info@construkted.com`) is delivered. This affects both the "Asset processing fails" and "Asset prepared" notifications -- users have zero email visibility into their asset processing status.

The root cause is a misuse of `wp_get_current_user()` in a server-to-server context where no WordPress user is logged in. Several latent bugs in the same code path will become user-facing once the primary fix is applied -- these are included in the fix scope.

## Problem Statement

### Primary Bug

The `control_asset_details.php` endpoint is called by **external tile-processing servers** (authenticated by IP whitelist, not WordPress session). In this context, `wp_get_current_user()` returns a default `WP_User` object with ID=0 and an empty email string. The empty email is passed to `wp_mail()`, which silently returns `false`.

**Affected file:** `construkted_reality_v1.x/wp-content/themes/gowatch-child/control_asset_details.php`

**Bug Location 1 -- `report_error` handler (lines 304-308):**
```php
$current_user = wp_get_current_user();   // Returns user with ID=0, empty email
$user_mail = $current_user->user_email;  // Always empty string

send_admin_failure_email($post_id, $error_msg);                     // Works fine
send_mail_to($user_mail, "Asset processing fails", $error_msg);    // Fails silently
```

**Bug Location 2 -- `update_custom_fields` handler (lines 399-403):**
```php
$current_user = wp_get_current_user();   // Returns user with ID=0, empty email
$user_mail = $current_user->user_email;  // Always empty string

send_mail_to("info@construkted.com", "Asset prepared");   // Works fine
send_mail_to($user_mail, "Asset prepared");                // Fails silently
```

### Why `wp_get_current_user()` Fails Here

The endpoint's authentication model is IP-based (lines 14-36), not session-based:
- External tile-processing servers call this endpoint directly
- No WordPress session/cookie is present
- `wp_get_current_user()` returns a default user object with `ID = 0` and `user_email = ''`
- `wp_mail('')` returns `false` but the return value is never checked

### Latent Bugs in the Blast Radius

Once the primary fix is applied and user emails start sending, these pre-existing issues become user-facing:

| Bug | Location | Severity | Why It Matters Now |
|-----|----------|----------|--------------------|
| `require` vs `require_once` | `send_mail_to()` line 115 | High | Callers already loaded WP; `require` may cause fatal errors on the now-active email path |
| Null dereference | `send_mail_to()` line 123 | Medium | `$post->post_name` accessed without null check; crashes if post was deleted during processing |
| HTML content-type missing | `send_mail_to()` lines 128-133 | Medium | Email body uses `<br />` tags but no content-type filter -- users will see literal `<br />` tags |

## Proposed Solution

Replace `wp_get_current_user()` with `get_post_field('post_author', $post_id)` + `get_the_author_meta('user_email', $author_id)` -- a pattern already used in `send_mail_to()` itself (lines 125-126). Fix the latent bugs in the same commit since they're in the blast radius.

**Why this approach:**
- The correct pattern already exists in the same file (`send_mail_to()` lines 125-126)
- `$post_id` is already available from `$_REQUEST['post_id']` in both handlers
- `get_post_field()` and `get_the_author_meta()` work correctly in unauthenticated contexts
- No new dependencies or architectural changes required

## Technical Approach

### Architecture

```
Request Flow (Current -- Broken):

  Tile Server -> IP Auth -> report_error/update_custom_fields
                              |
                              |-- wp_get_current_user() -> ID=0, email='' <-- BUG
                              |-- send_admin_failure_email() -> admin notified
                              +-- send_mail_to('', ...) -> silent fail

Request Flow (Fixed):

  Tile Server -> IP Auth -> report_error/update_custom_fields
                              |
                              |-- get_post_field('post_author', $post_id) -> author_id
                              |-- get_the_author_meta('user_email', $author_id) -> user email
                              |-- is_email() validation + error_log() on failure
                              |-- send_admin_failure_email() -> admin notified
                              +-- send_mail_to($validated_email, ...) -> user notified
```

### Implementation Tasks (Single Commit)

All tasks ship together. The latent bug fixes are not scope creep -- they're in the direct path of the now-working email sends.

#### A. Core Bug Fix

- [x] **Replace `wp_get_current_user()` in `report_error` handler (lines 304-305)**

  Replace:
  ```php
  $current_user = wp_get_current_user();
  $user_mail = $current_user->user_email;
  ```
  With:
  ```php
  // wp_get_current_user() returns empty email in server-to-server calls (no WP session).
  // Resolve the asset owner from the post author instead.
  $author_id = get_post_field('post_author', $post_id);
  $user_mail = get_the_author_meta('user_email', $author_id);
  ```

- [x] **Replace `wp_get_current_user()` in `update_custom_fields` handler (lines 399-400)**

  Same replacement as above.

- [x] **Add email validation with logging before each user `send_mail_to()` call**

  Wrap user email sends:
  ```php
  // Note: send_mail_to() re-reads $_REQUEST['post_id'] internally for the email body.
  // A future refactor should pass $post_id as a parameter (see send_admin_failure_email pattern).
  if (is_email($user_mail)) {
      send_mail_to($user_mail, "Asset processing fails", $error_msg);
  } else {
      error_log('Construkted: Could not send user notification for post ' . $post_id . ' - no valid author email (resolved: "' . $user_mail . '")');
  }
  ```

  And for the success handler:
  ```php
  if (is_email($user_mail)) {
      send_mail_to($user_mail, "Asset prepared");
  } else {
      error_log('Construkted: Could not send user notification for post ' . $post_id . ' - no valid author email (resolved: "' . $user_mail . '")');
  }
  ```

#### B. Blast-Radius Bug Fixes in `send_mail_to()`

- [x] **Fix `require` to `require_once` on line 115**

  Replace:
  ```php
  require('../../../wp-load.php');
  ```
  With:
  ```php
  require_once('../../../wp-load.php');
  ```

- [x] **Fix null dereference on line 123**

  After line 121 (`$post = get_post($post_id);`), add:
  ```php
  if (!$post) {
      error_log('Construkted: send_mail_to - post not found for ID ' . $post_id);
      return false;
  }
  ```

- [x] **Fix HTML content-type (email body uses `<br />` but no content-type filter)**

  Add the filter before `wp_mail()` and remove it after, using the stored-reference pattern already in `send_admin_failure_email()` (lines 246-253):
  ```php
  $set_html_content_type = function () {
      return 'text/html';
  };
  add_filter('wp_mail_content_type', $set_html_content_type);

  $result = wp_mail($to, $subject, $message);

  remove_filter('wp_mail_content_type', $set_html_content_type);

  return $result;
  ```

  **Important:** Do NOT use `remove_filter` with a new anonymous function -- it creates a different object and the filter is never removed. The stored-variable pattern above is the correct approach, matching the existing code in this file.

#### C. Optional Hardening (Can Ship Separately)

These improve observability but are not required for the fix:

- [ ] Add `wp_mail()` return value logging in `send_mail_to()`
- [ ] Remove `wp_mail_from_name` filter leak (line 117 adds it, never removes it)
- [ ] Add `$post_id` validation to `report_error` handler (only handler missing it)

### Estimated Effort

- **Core fix + blast-radius fixes:** ~1 hour including testing
- **Optional hardening:** ~30 minutes if shipped together

## System-Wide Impact

### Interaction Graph

The fix adds two read-only WordPress function calls (`get_post_field` + `get_the_author_meta`) before the existing `send_mail_to()` call. No callbacks, middleware, or observers are triggered by these database lookups.

**Note on redundancy:** `send_mail_to()` re-reads `$_REQUEST['post_id']` internally (line 119) and resolves the post author again (line 125) for the email body. After this fix, the author is resolved twice per email -- once by the caller (for the `$to` address) and once by `send_mail_to()` (for the display name in the body). This is redundant but safe. A future refactor of `send_mail_to()` could eliminate this duplication.

### No New State Risks

The fix only changes how the `$to` email address is resolved. Post meta updates (`last_error_msg`, `is_being_processed`) happen before the email code and are unaffected.

### Integration Test Scenarios

1. **Failure notification:** Tile server calls `report_error` with valid `post_id` -> post author receives "Asset processing fails" email with correct slug, username, and error message. Admin also receives HTML notification.

2. **Success notification:** Tile server calls `update_custom_fields` with valid `post_id` and metadata -> post author receives "Asset prepared" email. Admin also receives notification.

3. **Deleted post:** Tile server calls `report_error` with a `post_id` for a deleted post -> no user email sent, error logged, JSON response still returned (no PHP fatal).

4. **Deleted/invalid author:** Post exists but author was deleted -> no user email sent, `is_email()` catches empty string, error logged, admin email still sends.

## Acceptance Criteria

### Functional

- [ ] Asset owner receives "Asset processing fails" email when processing fails
- [ ] Asset owner receives "Asset prepared" email when processing succeeds
- [ ] Admin email (`info@construkted.com`) continues to work for both success and failure (regression check)
- [ ] Email body renders correctly with proper line breaks (not raw `<br />` tags)
- [ ] Dashboard UI error display remains unaffected (`last_error_msg` post meta)

### Defensive

- [ ] Invalid/empty author emails produce `error_log()` entries instead of silent failures
- [ ] No PHP notices, warnings, or fatal errors in the email code path
- [ ] `require_once` prevents double-loading of WordPress bootstrap
- [ ] Null post objects handled gracefully in `send_mail_to()`

### Verification Steps

1. Upload an asset and trigger processing
2. Simulate a failure by calling the endpoint with `action=report_error` from an allowed IP
3. Confirm that the asset owner receives the failure email at their registered email address
4. Repeat for the success path (`action=update_custom_fields`) and confirm the "Asset prepared" email arrives
5. Verify admin emails are unchanged

## Dependencies

Branch from `develop` per AGENTS.md. No external dependencies -- all required WordPress functions are core. Testing requires access to an allowed IP (or temporary whitelist entry).

## Risk Analysis

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| Fix breaks admin emails | High | Very Low | Admin emails use hardcoded `info@construkted.com`, separate code path. Verify with regression test. |
| Post author email empty/invalid for some posts | Medium | Low | `is_email()` validation catches this; `error_log()` makes it visible. Not a regression -- these emails never sent before. |

## Future Considerations

### Refactor `send_mail_to()` to Accept `$post_id` as Parameter

The function has a hidden dependency on `$_REQUEST['post_id']` that isn't visible in its signature. Compare with `send_admin_failure_email($post_id, $error_msg)` which correctly accepts `$post_id` as a parameter. A cleaner design would either:
- Have `send_mail_to()` derive the `$to` address from the post author internally (eliminating the caller's need to resolve it)
- Accept `$post_id` as an explicit parameter (eliminating the hidden `$_REQUEST` dependency)

Deferred to keep this fix minimal and low-risk.

### Known Pre-Existing Issues (Not in This Fix)

- `esc_attr()` is used for `$post_id` sanitization (lines 298, 317) -- `absint()` or `intval()` would be more correct for an integer ID
- `send_mail_to()` lacks a PHPDoc block (unlike `send_admin_failure_email()` which has one at lines 138-147)
- `wp_mail_from_name` filter added on line 117 is never removed

## Sources & References

### Internal References

- **Bug file:** `construkted_reality_v1.x/wp-content/themes/gowatch-child/control_asset_details.php`
  - `send_mail_to()` function: lines 113-136
  - `send_admin_failure_email()` function: lines 148-256
  - `report_error` handler: lines 295-311
  - `update_custom_fields` handler: lines 312-410
  - IP whitelist: lines 14-36
  - Correct `remove_filter` pattern: `send_admin_failure_email()` lines 246-253
- **Correct pattern reference:** `includes/ajax.php:445-471` uses `get_post_field('post_author')` correctly
- **AGENTS.md:** Branch rules -- use `develop` as base for `construkted_reality_v1.x`

### External References

- WordPress `wp_get_current_user()`: https://developer.wordpress.org/reference/functions/wp_get_current_user/
- WordPress `wp_mail()`: https://developer.wordpress.org/reference/functions/wp_mail/
- WordPress `is_email()`: https://developer.wordpress.org/reference/functions/is_email/

### Original Bug Report

- `email_bug-to-fix.md` in project root

### Technical Review

Reviewed by 3 agents (2026-02-22). Key corrections applied:
- Fixed `remove_filter` anonymous closure pattern (would have silently leaked the content-type filter)
- Fixed `error_log()` prefix to match codebase convention (`Construkted:` not `[Construkted]`)
- Merged phases 1+2 into single commit scope (latent bugs are in blast radius)
- Removed "Centralized Email Service" from future considerations
- Added `$_REQUEST['post_id']` hidden dependency documentation
