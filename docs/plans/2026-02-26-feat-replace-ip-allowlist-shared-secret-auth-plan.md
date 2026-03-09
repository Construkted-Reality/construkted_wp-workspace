---
title: "feat: Replace IP allowlist with shared secret authentication for API-to-WP callbacks"
type: feat
status: completed
date: 2026-02-26
origin: docs/brainstorms/2026-02-26-api-wp-shared-secret-auth-brainstorm.md
---

# feat: Replace IP Allowlist with Shared Secret Authentication for API-to-WP Callbacks

## Overview

Replace the hardcoded IP allowlist in WordPress's `control_asset_details.php` with a shared API key (`X-Construkted-Key` header) that the processing servers include in every callback. This eliminates the dependency on static IP addresses for servers running on residential internet with dynamic IPs.

The change spans two repositories: `construkted_api` (Node.js processing servers) and `construkted_reality_v1.x` (WordPress theme).

## Problem Statement / Motivation

The `construkted_api` processing servers (2-3 machines on residential internet) call back to WordPress after asset processing completes. The only protection on this endpoint is a hardcoded `$allowedIPs` array in `control_asset_details.php:14-36`.

**Why this is a problem:**
- Server IPs change every few months (dynamic residential connections)
- When an IP changes, callbacks silently fail with no alerting
- Failures are only discovered when end users report assets stuck in "processing"
- Updating the allowlist requires editing PHP source and redeploying

The IP allowlist was always a proxy for "is this request from a trusted server?" A shared secret answers that question directly without IP dependency. (see brainstorm: `docs/brainstorms/2026-02-26-api-wp-shared-secret-auth-brainstorm.md`)

## Proposed Solution

1. **WP admin generates** a shared secret (64-character hex string via `bin2hex(random_bytes(32))`) stored in WP options
2. **Admin copies** the key to each API server's `.env` file as `WP_SHARED_SECRET`
3. **API servers include** the key as an `X-Construkted-Key` HTTP header in every callback to WordPress
4. **WP validates** the header using `hash_equals()` against the stored secret
5. **IP allowlist removed** entirely from `control_asset_details.php`

**Why this approach over alternatives** (see brainstorm for full evaluation):
- Per-server keys: unnecessary complexity for 2-3 servers
- HMAC request signing: HTTPS already encrypts the key in transit
- Dynamic IP registration: still relies on IP-based auth, just automates updates

## Technical Considerations

### Architecture Impacts

- **Cross-repo change**: Both `construkted_api` and `construkted_reality_v1.x` must be updated in coordination
- **Two HTTP libraries**: `task.ts` uses `axios`, `app.ts` uses `request-promise` — header injection syntax differs for each
- **Config loading**: API uses `dotenv.config()` in `app.ts` — env vars must be read via `process.env` at point of use, not in `config.ts` (which loads before dotenv). WP uses `get_option()` for settings.

### Security Considerations

- **Use `hash_equals()`** for key comparison in PHP to prevent timing attacks (not `===`). Parameter order: `hash_equals($stored_key, $provided_key)` — known string first, user-supplied second per PHP docs.
- **Key entropy**: minimum 32 bytes (256 bits), generated as 64-character hex string via `bin2hex(random_bytes(32))`. This exceeds OWASP's 128-bit minimum recommendation.
- **Empty key validation**: both sides must reject empty/whitespace-only keys — otherwise `"" === ""` would authenticate anything
- **Trim key values**: Apply `trim()` to both stored and provided keys before comparison. Prevents copy-paste whitespace issues from causing mysterious silent auth failures.
- **Header over query param**: `X-Construkted-Key` header avoids key appearing in server access logs (see brainstorm: key decision on header-based auth). Note: the `X-` prefix is deprecated per RFC 6648 (2012) but acceptable for private internal APIs.
- **Admin field type**: use `type="password"` with show/hide toggle to prevent shoulder-surfing
- **HTTPS enforcement**: All callback URLs MUST use HTTPS. The API server should validate that `wPServerUrl` starts with `https://` before sending the key. If someone configures an HTTP URL, the key travels in plaintext.
- **Key in WP options**: stored plaintext in `wp_options` table — consistent with existing pattern for S3 keys and Cesium token in `api_keys_options`
- **Sanitize callback**: Register a `sanitize_callback` for the WP option that validates the key is a 64-character hex string when present.

### CRITICAL: `wPServerUrl` SSRF Must Be Addressed

> **Deepening research finding (Security Sentinel — severity: CRITICAL)**

The shared secret is sent as a header to whatever URL is in `wPServerUrl`. This URL is accepted as an **untrusted query parameter** in `/request_tiling` (`app.ts:99`) with no validation. Since the API server has zero authentication on any endpoint (`Access-Control-Allow-Origin: *`), an attacker can:

1. Call `/request_tiling` with `wPServerUrl=https://attacker.com`
2. The API processes the job and calls back to `https://attacker.com/...` with `X-Construkted-Key: <the_secret>`
3. The attacker receives the shared secret

**This completely defeats the shared secret authentication.** Without fixing this, the feature provides no meaningful security improvement over the IP allowlist.

**Required fix (in-scope for this feature):** Validate `wPServerUrl` against a whitelist of allowed WP base URLs configured in the API's `.env` file:
- Add `ALLOWED_WP_URLS` env var (comma-separated list of allowed WordPress base URLs)
- Validate `wPServerUrl` against this whitelist in `/request_tiling` handler before accepting the job
- Reject requests with unrecognized `wPServerUrl` values

### Performance Implications

None meaningful. Adding a single header to HTTP requests and one string comparison on the PHP side.

### Pre-existing Issues (Fix While Touching This Code)

1. **`json_encode()` bug** at `control_asset_details.php:33`: The `405` is passed as `json_encode()`'s options bitmask, not as an HTTP status code. The response actually returns HTTP 200. Fix to use `http_response_code(403)` before the JSON output.
2. **CORS headers removal**: Lines 27-29 set `Access-Control-Allow-Origin` per IP in the allowlist. When the allowlist is removed, these go away too. Since these are server-to-server calls (not browser), CORS is irrelevant. Remove them and document the change.

## System-Wide Impact

- **Interaction graph**: API completes tiling job -> `_updateAssetCustomFields()` or `_reportError()` in `task.ts` -> HTTP GET to `control_asset_details.php` -> WP validates `X-Construkted-Key` header -> processes request -> updates post meta / records error. Separately: WP admin ping button -> API `/ping` endpoint -> HTTP callback to `control_asset_details.php` -> validates key -> returns response.
- **Error propagation**: If key validation fails, WP returns HTTP 403 with `{"errCode": 1, "errMsg": "Unauthorized"}`. In `task.ts`, axios throws on non-2xx responses. The catch block at `task.ts:939-951` logs the error but does NOT call `this._failed()` — this is a **pre-existing bug** where the task appears completed despite callback failure. The plan should NOT fix this bug (out of scope) but should ensure auth rejection errors are logged distinctly from other failures.
- **State lifecycle risks**: Failed callbacks leave assets in "processing" state (`is_being_processed` meta never cleared). This is the same failure mode as the current IP problem, but with key auth the cause is more deterministic and debuggable.
- **API surface parity**: Three call sites send callbacks to WP — all three must include the header:
  1. `task.ts:940` — `axios.get()` in `_updateAssetCustomFields()`
  2. `task.ts:1025` — `axios.get()` in `_reportError()`
  3. `app.ts:232` — `requestPromise()` in `/ping` handler
- **Integration test scenarios**:
  1. Full tiling job completes and successfully updates WP custom fields via authenticated callback
  2. API server with wrong key gets 403 and logs a clear auth failure message
  3. Admin regenerates key in WP, updates API `.env`, pings to verify
  4. API server starts without `WP_SHARED_SECRET` — refuses to start (startup validation)
  5. WP with no key configured rejects all callbacks

## Acceptance Criteria

### WordPress (`construkted_reality_v1.x`)

- [x] `control_asset_details.php` — Replace IP allowlist (lines 14-36) with `X-Construkted-Key` header validation using `hash_equals()`
- [x] `control_asset_details.php` — Return HTTP 403 with `{"errCode": 1, "errMsg": "Unauthorized"}` for missing/invalid key (fix the pre-existing `json_encode()` bug)
- [x] `control_asset_details.php` — Remove CORS header loop (lines 27-29) that iterated over IP allowlist
- [x] `control_asset_details.php` — Reject requests when no shared secret is configured in WP (empty option = no valid key)
- [x] `control_asset_details.php` — Log rejected requests via `error_log()` with requesting IP and timestamp for debugging
- [x] `api-url-settings.php` — Add shared secret plain text field to "Backend Server URLs" tab with `openssl rand -hex 32` generation instruction (matches existing pattern for S3/Cesium keys)
- [x] `admin.php` — Register the new WP option for the shared secret (store in `api_keys_options` array, display on Backend Server URLs tab)

### API Server (`construkted_api`)

- [x] `lib/task.ts` — Add `X-Construkted-Key` header to `axios.get()` calls in `_updateAssetCustomFields()` (line 940) and `_reportError()` (line 1025)
- [x] `app.ts` — Add `X-Construkted-Key` header to `requestPromise()` call in `/ping` handler (line 232). Note: `request-promise` is deprecated (last published 2020) — error handling uses `err.statusCode` (NOT `err.response?.status` like axios)
- [x] `app.ts` — Read `WP_SHARED_SECRET` and `ALLOWED_WP_URLS` from `process.env` directly (NOT from config.ts — `dotenv.config()` runs in app.ts after config module loads)
- [x] `app.ts` — Add `WP_SHARED_SECRET` and `ALLOWED_WP_URLS` to `checkStartCondition()` validation (lines 375-448) — refuse to start without them
- [x] `app.ts` — Validate `wPServerUrl` against `ALLOWED_WP_URLS` whitelist in BOTH `/request_tiling` AND `/ping` handlers before sending callbacks (CRITICAL — prevents SSRF secret exfiltration via either endpoint)
- [x] `app.ts` — Normalize URLs (strip trailing slashes) before comparison to prevent `https://site.com` vs `https://site.com/` mismatch
- [x] `.env.example` — Add `WP_SHARED_SECRET=your_shared_secret_here` and `ALLOWED_WP_URLS=https://your-wordpress-site.com`
- [x] API logs clearly distinguish auth rejection (403) from other callback failures

### Validation Scenarios

| Scenario | Expected Result |
|----------|----------------|
| API with correct key -> WP | Callback succeeds (200, errCode 0) |
| API with wrong key -> WP | HTTP 403, `{"errCode": 1, "errMsg": "Unauthorized"}` |
| API with no header -> WP | HTTP 403, `{"errCode": 1, "errMsg": "Unauthorized"}` |
| API with empty key -> WP | HTTP 403 (empty key never matches) |
| API key with leading/trailing whitespace | `trim()` applied, matches if content matches |
| WP with no key configured | All callbacks rejected |
| Key regenerated in WP | Old key stops working immediately |
| Ping from admin UI | Verifies key configuration end-to-end |
| API starts without `WP_SHARED_SECRET` | Startup check fails, server refuses to start |
| `/request_tiling` with unknown `wPServerUrl` | Request rejected before processing (SSRF prevention) |
| `/request_tiling` with attacker-controlled URL | Rejected — secret never sent to unauthorized host |

## Success Metrics

- Zero callback failures due to IP address changes (the entire point)
- Admin can rotate keys via WP admin UI without editing source code
- Auth failures produce clear, actionable log messages on both sides
- Ping button in WP admin serves as key configuration health check

## Dependencies & Risks

### Deployment Sequence (Maintenance Window)

This is a cross-repo change with a chicken-and-egg dependency. **Deploy during a maintenance window when no tiling jobs are processing:**

1. Drain the processing queue — wait for all running jobs to complete
2. Deploy WordPress changes (new auth + admin UI)
3. Generate shared secret in WP admin
4. Copy key to each API server's `.env` file
5. Restart each API server
6. Use the WP admin Ping button to verify each server's key is working
7. Resume processing

**Why not dual-mode transitional auth:** adds code complexity for a one-time deployment. A maintenance window is simpler and the processing downtime is minutes, not hours.

### Rollback Plan

If key auth breaks in production:
1. Revert `control_asset_details.php` to restore IP allowlist (git revert)
2. Revert API servers (remove header, restart) — or just leave the header, WP will ignore it with IP check restored
3. Recover stuck assets: query for posts where `is_being_processed` meta is set and no completion timestamp — manually clear the flag

### Open Questions

- [x] **`delete_attachment` action**: `control_asset_details.php:281-315` handles an `action=delete_attachment` that's also behind the IP allowlist. **Resolved**: grep confirms the API server never calls this action. It's dead code or WP-internal only. The shared secret gate still protects it since it runs before any action dispatch.
- [ ] **Ping has no explicit handler**: The `/ping` callback succeeds by falling through to the `else` catch-all at `control_asset_details.php:451` which returns `errCode: 0`. This works but is fragile. Consider adding an explicit `action=ping` handler. (Low priority — works as-is.)

### Out of Scope (Documented in Brainstorm)

These security issues were identified but are explicitly not part of this feature (see brainstorm: Security Concerns section):

1. WP -> API direction is completely unprotected (`/request_tiling` endpoint)
2. API server has no auth middleware (`Access-Control-Allow-Origin: *`)
3. `control_asset_details.php` uses `$_REQUEST` without CSRF protection
4. ~~`wPServerUrl` passed as query parameter (callback redirect attack vector)~~ **MOVED IN-SCOPE**: The `wPServerUrl` validation is now a required part of this feature because without it, an attacker can exfiltrate the shared secret via SSRF (see CRITICAL section above in Technical Considerations)

## MVP

### control_asset_details.php (WP — key validation replacing IP allowlist)

```php
// Replace lines 14-36 in control_asset_details.php

// Shared secret authentication
$stored_key = trim(get_option('api_keys_options')['construkted-wp-shared-secret'] ?? '');
$provided_key = trim($_SERVER['HTTP_X_CONSTRUKTED_KEY'] ?? '');

if (empty($stored_key) || empty($provided_key) || !hash_equals($stored_key, $provided_key)) {
    http_response_code(403);
    error_log('[Construkted Auth] Rejected callback from ' . ($_SERVER['REMOTE_ADDR'] ?? 'unknown') . ' - invalid or missing X-Construkted-Key header');
    echo json_encode(['errCode' => 1, 'errMsg' => 'Unauthorized']);
    exit();
}
```

### task.ts (API — adding header to axios calls + 403 logging)

```typescript
// In _updateAssetCustomFields() — replace the axios call and update catch block
const response = await axios.get(url, {
    headers: {
        'X-Construkted-Key': process.env.WP_SHARED_SECRET || ''
    }
});

// Updated catch block (existing catch at task.ts:939-951):
} catch (err: any) {
    const status = err.response?.status;
    const errorMessage = status ? `HTTP ${status}: ${err.message}` : err.message;
    if (status === 403) {
        logger.error(`(construkted asset: ${this.postSlug}) WP callback auth rejected (403) - check WP_SHARED_SECRET matches WP admin key`);
    } else {
        logger.error(`(construkted asset: ${this.postSlug}) Failed to update asset custom fields: ${errorMessage}`);
    }
}

// In _reportError() — same header addition
// NOTE: existing catch at task.ts:1032 is a bare `catch {}` that swallows errors.
// At minimum, capture the error to log auth failures:
} catch (err: any) {
    const status = err.response?.status;
    if (status === 403) {
        logger.error(`(construkted asset: ${this.postSlug}) Error report auth rejected (403) - check WP_SHARED_SECRET`);
    }
}
```

### app.ts (API — adding header to request-promise ping + 403 logging)

```typescript
// In /ping handler — NOTE: request-promise uses err.statusCode, NOT err.response?.status
const response = await requestPromise({
    url: url,
    json: true,
    headers: {
        'X-Construkted-Key': process.env.WP_SHARED_SECRET || ''
    }
});

// Updated catch block:
} catch (err: any) {
    if (err.statusCode === 403) {
        logger.error(`[Auth] Ping rejected by WP (403) - check WP_SHARED_SECRET`);
        http.send(res, globalConstants.ERROR_SUCCESS, "Authentication failed - check shared secret configuration", {});
    } else {
        http.send(res, globalConstants.ERROR_SUCCESS, err.message, {});
    }
}
```

> **Review finding (Kieran):** `request-promise` throws `StatusCodeError` with `err.statusCode` property. Axios throws with `err.response?.status`. Don't mix them up.

### config.ts — No Changes Needed

> **Review finding (Kieran):** `dotenv.config()` is called in `app.ts:18`, not `config.ts`. The config module executes *before* env vars are loaded. The existing codebase reads `process.env` directly at point of use — follow that pattern. Do NOT add env vars to the `Config` interface or config object.

### app.ts (API — wPServerUrl validation in /request_tiling AND /ping)

```typescript
// Helper: parse and normalize allowed WP URLs (call once after dotenv.config())
const normalizeUrl = (url: string) => url.trim().replace(/\/+$/, '');
const allowedWPUrls = (process.env.ALLOWED_WP_URLS || '').split(',').map(normalizeUrl).filter(Boolean);

// In /request_tiling handler, after wPServerUrl presence check, before new Task()
const normalizedWPServerUrl = normalizeUrl(wPServerUrl);
if (!allowedWPUrls.includes(normalizedWPServerUrl)) {
    logger.error(`[Auth] Rejected tiling request: wPServerUrl '${wPServerUrl}' not in ALLOWED_WP_URLS whitelist`);
    http.send(res, globalConstants.ERROR_INVALID_PARAMETER, "invalid wPServerUrl", {});
    return;
}

// ALSO in /ping handler (same SSRF vector — accepts wPServerUrl as query param)
const normalizedWPServerUrl = normalizeUrl(wPServerUrl);
if (!allowedWPUrls.includes(normalizedWPServerUrl)) {
    logger.error(`[Auth] Rejected ping: wPServerUrl '${wPServerUrl}' not in ALLOWED_WP_URLS whitelist`);
    http.send(res, globalConstants.ERROR_SUCCESS, "invalid wPServerUrl", {});
    return;
}
```

> **Review finding (DHH + Kieran):** URL trailing slash normalization is critical. `https://construkted.com/` vs `https://construkted.com` would cause a silent mismatch with exact string comparison.

### api-url-settings.php (WP — admin UI for key management)

> **Review finding (DHH + Simplicity):** One admin uses this field once every few months. No need for client-side crypto generation, copy buttons, show/hide toggles, or readonly dance. Generate the key in the terminal with `openssl rand -hex 32`, paste it in. Same workflow as existing S3 keys and Cesium token.

```php
<!-- Add to Backend Server URLs tab -->
<h3>Shared Secret</h3>
<p>
    This key authenticates callbacks from the processing servers to WordPress.
    Generate with: <code>openssl rand -hex 32</code>
</p>
<?php
$api_keys = get_option('api_keys_options', []);
$shared_secret = $api_keys['construkted-wp-shared-secret'] ?? '';
?>
<input type="text"
       id="construkted-wp-shared-secret"
       name="api_keys_options[construkted-wp-shared-secret]"
       value="<?php echo esc_attr($shared_secret); ?>"
       size="70"
       class="api-url-input" />
```

## Sources & References

### Origin

- **Brainstorm document:** [docs/brainstorms/2026-02-26-api-wp-shared-secret-auth-brainstorm.md](docs/brainstorms/2026-02-26-api-wp-shared-secret-auth-brainstorm.md) — Key decisions carried forward: single shared key for all servers, `X-Construkted-Key` header-based auth, WP admin key management on Backend Server URLs tab, remove IP allowlist entirely.

### Deepening Research (2026-02-26)

- **Best practices**: RFC 6648 (`X-` prefix deprecation), OWASP key entropy guidelines (128-bit minimum), PHP `hash_equals()` parameter ordering
- **Framework docs**: WordPress Settings API (`register_setting` with `sanitize_callback`), `bin2hex(random_bytes(32))` preferred over `wp_generate_password()` for machine-to-machine keys, `request-promise` deprecated since 2020
- **Security audit**: SSRF via `wPServerUrl` (CRITICAL — moved in-scope), `trim()` for whitespace resilience, HTTPS enforcement for callback URLs, sanitize callback for WP option

### Internal References

- IP allowlist implementation: `construkted_reality_v1.x/wp-content/themes/gowatch-child/control_asset_details.php:14-36`
- Asset callback (axios): `construkted_api/lib/task.ts:871-952`
- Error callback (axios): `construkted_api/lib/task.ts:1012-1035`
- Ping callback (request-promise): `construkted_api/app.ts:216-247`
- WP admin Backend Server URLs tab: `construkted_reality_v1.x/includes/admin/forms/api-url-settings.php`
- WP admin API Keys tab (existing pattern): `construkted_reality_v1.x/includes/admin/forms/api-keys.php`
- WP settings registration: `construkted_reality_v1.x/includes/admin/admin.php:19-35`
- API config loading: `construkted_api/config.ts:1-44`
- API startup validation: `construkted_api/app.ts:375-448`
- API env template: `construkted_api/env.example`
- wPServerUrl parameter acceptance: `construkted_api/app.ts:99`
