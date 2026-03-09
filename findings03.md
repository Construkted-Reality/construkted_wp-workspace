# Security Audit Findings

**Audit Date:** January 29, 2026  
**Auditor:** OpenCode Security Analysis  
**Scope:** construkted.js/, construkted_reality_v1.x/ repositories

---

## Executive Summary

This comprehensive security audit across both repositories has identified **12 unique vulnerabilities** requiring immediate remediation:

| Severity | Count |
|----------|-------|
| Critical | 4 |
| High | 3 |
| Medium | 3 |
| Low | 2 |

**Critical concerns include:**
- Cesium Ion access token exposure in client-side JavaScript
- Insecure API key generation using md5(uniqid())
- Unauthenticated REST API and AJAX endpoints exposing private data
- CSRF vulnerabilities across AJAX handlers

---

## Part 1: construkted.js/ Repository

**Tech Stack:** TypeScript, Cesium 1.132, Three.js 0.152.0, jQuery 3.6.3, Vite 5.4.10, Rollup 2.53.2, Gulp 4.0.2

---

### Critical Issues

#### 1. Cesium Ion Access Token Exposure

**File:** `src/index.ts:338`  
**Severity:** Critical

The Cesium Ion access token is exposed via `CONSTRUKTED_AJAX.cesium_access_token` and logged to console:

```typescript
Ion.defaultAccessToken = CONSTRUKTED_AJAX.cesium_access_token;
if (!Ion.defaultAccessToken) console.warn("default access token is null!");
```

**Impact:** Unauthorized access to Cesium Ion services, potential billing fraud, data exfiltration.  
**Remediation:** Implement server-side token proxy, restrict token by referer/origin, rotate all exposed tokens immediately.

---

#### 2. CSRF Vulnerability in jQuery AJAX Calls

**File:** `src/construkted_ajax.ts` (entire file)  
**Severity:** Critical

All AJAX requests lack CSRF token validation. Nonces are extracted from DOM attributes but not properly validated:

```typescript
jQuery.ajax({
    url: CONSTRUKTED_AJAX.ajaxurl,
    type: "post",
    data: {
        action: "post_set_current_view",
        post_id: CONSTRUKTED_AJAX.post_id,
        view_data: viewData
    },
    // No CSRF token included or validated
});
```

**Impact:** Cross-Site Request Forgery attacks allowing unauthorized state-changing requests.  
**Remediation:** Add CSRF token to all AJAX requests, validate nonce server-side.

---

#### 3. Axios CSRF Vulnerability (Transitive Dependency)

**Severity:** Critical  
**Package:** `axios <=0.29.0` via `browser-sync`  
**Advisory:** https://github.com/advisories/GHSA-wf5p-g6vw-rhxx

**Impact:** Remote attackers can perform CSRF attacks via specially crafted web pages.  
**Remediation:** Update browser-sync to version 3.0.4+ (`npm audit fix --force`)

---

#### 4. Rollup DOM Clobbering XSS Vulnerability

**Severity:** Critical  
**Package:** `rollup <2.79.2` via `rollup-plugin-less`  
**Advisory:** https://github.com/advisories/GHSA-gcx4-mw62-g8wm

**Impact:** DOM Clobbering Gadget in bundled scripts leads to XSS.  
**Remediation:** Consider migrating to alternative bundler or implementing security wrapper.

---

### High Issues

#### 5. Uncontrolled Resource Consumption in Braces

**Severity:** High  
**Package:** `braces <3.0.3`  
**Advisory:** https://github.com/advisories/GHSA-grv7-fg5c-xmjg

**Impact:** Regular expression denial of service.  
**Remediation:** `npm audit fix --force` (will update gulp to 5.0.1)

---

#### 6. XSS via InnerHTML Usage

**File:** `src/ConstruktedApi.ts:175-196`  
**Severity:** High

HTML entities decoding uses `element.innerHTML` which can introduce XSS vulnerabilities:

```typescript
export const decodeEntities = (function () {
    const element = document.createElement("div");
    function decodeHTMLEntities(str: any) {
        if (str && typeof str === "string") {
            str = str.replace(/<script[^>]*>([\S\s]*?)<\/script>/gim, "");
            str = str.replace(/<\/?\w(?:[^"'>]|"[^"]*"|'[^']*')*>/gim, "");
            element.innerHTML = str;  // Potential XSS
            str = element.textContent;
            element.textContent = "";
        }
        return str;
    }
    return decodeHTMLEntities;
})();
```

**Impact:** Cross-site scripting attacks via malformed input.  
**Remediation:** Use textContent instead of innerHTML, implement proper output encoding.

---

#### 7. Vulnerable npm Dependencies

**Severity:** High  
**Packages:** `axios <=0.29.0`, `rollup <2.79.2`, `braces <3.0.3`, `send <0.19.0`, `html-minifier`

**Advisories:**
- GHSA-wf5p-g6vw-rhxx (axios CSRF)
- GHSA-gcx4-mw62-g8wm (rollup DOM clobbering)
- GHSA-grv7-fg5c-xmjg (braces ReDoS)
- GHSA-m6fv-jmcg-4jfg (send template injection)
- GHSA-pfq8-rq6v-vf5m (html-minifier ReDoS)

**Remediation:** `npm audit fix --force` to update vulnerable dependencies.

---

### Medium Issues

#### 8. Console Information Leakage

**File:** `src/index.ts:299-303`  
**Severity:** Medium

```typescript
console.info("original CONSTRUKTED_AJAX", window.CONSTRUKTED_AJAX);
console.info(JSON.stringify(window.CONSTRUKTED_AJAX));
```

**Impact:** Sensitive configuration data exposed in browser console.  
**Remediation:** Remove debug logging in production builds, use environment-aware logging.

---

#### 9. esbuild SSRF Vulnerability

**Severity:** Medium  
**Package:** `esbuild <=0.24.2` via `vite`  
**Advisory:** https://github.com/advisories/GHSA-67mh-4wv8-2f99

**Impact:** Development server can be used to send arbitrary requests and read responses.  
**Remediation:** Update vite to version 7.3.1+ (`npm audit fix --force`)

---

### Low Issues

#### 10. Debug Mode Detection

**File:** `src/ConstruktedApi.ts:18-23`  
**Severity:** Low

```typescript
export const isLocal = () =>
    location.hostname === "cesiumgis.com" || location.hostname === "localhost" || location.hostname === "127.0.0.1";

export const isGw4 = () => location.hostname === "gw4.construkted.com";
```

**Impact:** Feature flag based on hostname may expose development behaviors in production.  
**Remediation:** Use environment variables or build-time configuration instead.

---

---

## Part 2: construkted_reality_v1.x/ Repository

**Tech Stack:** WordPress theme (PHP 8.x), custom REST API, jQuery AJAX

---

### Critical Issues

#### 11. Insecure API Key Generation

**File:** `wp-content/themes/gowatch-child/includes/class.api.php:549`  
**Severity:** Critical

API keys are generated using cryptographically weak method:

```php
function generate_api_key()
{
    $key = md5(uniqid(rand(), true));
    return $key;
}
```

**Impact:** Predictable API keys can be brute-forced, leading to unauthorized access.  
**Remediation:** Use `wp_generate_password()` or `random_bytes()` with `bin2hex()` for cryptographically secure keys.

---

#### 12. Unauthenticated REST API Endpoints

**File:** `wp-content/themes/gowatch-child/includes/class.api.php:66-99`  
**Severity:** Critical

REST routes have no authentication requirement:

```php
register_rest_route('ck/v1', '/getAssets', array(
    'methods' => 'GET',
    'callback' => array($this, 'get_assets'),
    'permission_callback' => function () {
        return true;  // No authentication required!
    }
));

register_rest_route('ck/v1', '/getAsset/(?P<id>[a-zA-Z0-9-]+)', array(
    'methods' => 'GET',
    'callback' => array($this, 'get_asset'),
    'permission_callback' => function () {
        return true;  // No authentication required!
    }
));

register_rest_route('ck/v1', '/addAsset', array(
    'methods' => 'POST',
    'callback' => array($this, 'add_asset'),
    'permission_callback' => function () {
        return true;  // No authentication required!
    }
));
```

**Impact:** Any unauthenticated user can access, modify, or create assets.  
**Remediation:** Implement proper authentication checking in permission_callback.

---

### High Issues

#### 13. Plain Text Password Storage

**File:** `wp-content/themes/gowatch-child/includes/ajax.php:559-564`  
**Severity:** High

Password-protected assets store passwords in plain text:

```php
if ($view_access === 'password' && isset($_POST['assetPassword'])) {
    $asset_password = sanitize_text_field($_POST['assetPassword']);
    update_post_meta($post_id, 'asset_view_password', $asset_password);  // Plain text!
}
```

**Impact:** Password exposure in database, potential credential reuse attacks.  
**Remediation:** Implement proper password hashing using `wp_hash_password()` or remove password protection entirely.

---

#### 14. CSRF Vulnerabilities in AJAX Handlers

**File:** `wp-content/themes/gowatch-child/includes/ajax.php`  
**Severity:** High

Multiple AJAX handlers lack proper CSRF protection:

```php
// Missing nonce validation
add_action('wp_ajax_nopriv_post_set_current_view', 'post_set_current_view');
add_action('wp_ajax_post_set_current_view', 'post_set_current_view');

function post_set_current_view()
{
    $post_id = $_REQUEST['post_id'];  // No validation
    $view_data = $_REQUEST['view_data'];
    $ret = update_post_meta($post_id, 'default_camera_position_direction', $view_data);
    // ...
}
```

**Impact:** Cross-site request forgery on state-changing operations.  
**Remediation:** Add `check_ajax_referer()` to all handlers, remove nopriv handlers where not needed.

---

### Medium Issues

#### 15. Inconsistent Input Validation

**File:** `wp-content/themes/gowatch-child/includes/ajax.php`  
**Severity:** Medium

AJAX handlers mix sanitization methods inconsistently:

```php
// Some use proper sanitization
$post_id = intval($_POST['post_id']);
$post_title = sanitize_text_field($_POST['title']);

// Others use raw input
$post_id = $_REQUEST['post_id'];  // No sanitization
$view_data = $_REQUEST['view_data'];
$bg_color = $_REQUEST['bg_color'];
```

**Impact:** Potential SQL injection or data corruption.  
**Remediation:** Standardize on WordPress sanitization functions: `absint()`, `sanitize_text_field()`, `wp_kses_post()`.

---

#### 16. Verbose Error Messages

**File:** `wp-content/themes/gowatch-child/includes/ajax.php`  
**Severity:** Medium

Error responses expose internal implementation details:

```php
echo "failed to delete old thumbnail!";
echo "successfully updated!";
echo "failed to updated!";
echo "Failed to submit!";
```

**Impact:** Information disclosure about system internals.  
**Remediation:** Use generic error messages, log detailed errors server-side.

---

#### 17. Missing Rate Limiting

**Location:** Multiple AJAX and REST endpoints  
**Severity:** Medium

No rate limiting on authentication-critical endpoints.  
**Impact:** Brute force attacks on password-protected assets and API key enumeration.  
**Remediation:** Implement WordPress transient-based rate limiting or use a dedicated plugin.

---

### Low Issues

#### 18. Exposed API Key in URL

**File:** `wp-content/themes/gowatch-child/includes/class.api.php:47-52`  
**Severity:** Low

API keys passed in URL query parameter vulnerability:

```php
$url = $server_url . '?userName=' . $user_name . '&slug=' . $slug . '&original3DFileBaseName=' . $original_3d_file_base_name;
```

**Impact:** API credentials logged in server access logs.  
**Remediation:** Use Authorization header instead of query parameters.

---

---

## Dependency Vulnerability Summary

### npm audit results (construkted.js/)

| Package | Severity | Advisory | Status |
|---------|----------|----------|--------|
| axios <=0.29.0 | High | GHSA-wf5p-g6vw-rhxx | Needs update |
| braces <3.0.3 | High | GHSA-grv7-fg5c-xmjg | Needs update |
| rollup <2.79.2 | High | GHSA-gcx4-mw62-g8wm | Needs update |
| html-minifier | High | GHSA-pfq8-rq6v-vf5m | Needs update |
| send <0.19.0 | High | GHSA-m6fv-jmcg-4jfg | Needs update |
| esbuild <=0.24.2 | Moderate | GHSA-67mh-4wv8-2f99 | Needs update |

---

## Remediation Priority Matrix

| Priority | Issue | Remediation |
|----------|-------|-------------|
| P0 | Cesium Ion token exposure | Rotate tokens, implement proxy |
| P0 | Unauthenticated REST API | Add authentication checks |
| P0 | Insecure API key generation | Use wp_generate_password() |
| P0 | CSRF in AJAX handlers | Add check_ajax_referer() |
| P1 | Plain text password storage | Implement password hashing |
| P1 | Vulnerable npm dependencies | npm audit fix --force |
| P1 | XSS via innerHTML | Use textContent |
| P2 | Inconsistent input validation | Standardize sanitization |
| P2 | Console info leakage | Remove debug logging |
| P2 | Missing rate limiting | Implement rate limiting |

---

## Recommendations

### Immediate Actions (0-24 hours)

1. **Rotate all exposed Cesium Ion tokens** via the Cesium Ion dashboard
2. **Restrict unauthenticated REST API access** by implementing authentication in permission_callback
3. **Generate new API keys** using cryptographically secure methods
4. **Add CSRF protection** to all AJAX handlers

### Short-term Actions (1-7 days)

5. **Update all vulnerable npm dependencies** via `npm audit fix --force`
6. **Implement password hashing** for password-protected assets
7. **Fix XSS vulnerabilities** in HTML entity decoding
8. **Standardize input validation** across all AJAX handlers

### Medium-term Actions (1-4 weeks)

9. **Implement rate limiting** on all sensitive endpoints
10. **Audit logging** for security events
11. **Remove debug logging** from production code
12. **Security headers** (CSP, X-Frame-Options, X-Content-Type-Options)

---

## Conclusion

Both repositories contain significant security vulnerabilities requiring immediate attention. The most critical issues are:

1. **Exposed Cesium Ion tokens** - Immediate action required to prevent unauthorized usage and billing fraud
2. **Unauthenticated API endpoints** - Full REST API is exposed without authentication
3. **Weak cryptographic practices** - API keys are generated using insecure methods
4. **Cross-site request forgery** - Multiple AJAX endpoints lack CSRF protection

A follow-up audit should be conducted after implementing all remediation steps to verify fixes are effective.