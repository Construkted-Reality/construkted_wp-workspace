# Security Audit Report

**Audit Date:** January 28, 2026  
**Repositories Audited:** `construkted.js/`, `construkted_reality_v1.x/`  
**Total Vulnerabilities Found:** 13

---

## Executive Summary

This security audit identified **13 unique vulnerabilities** across both repositories. The critical findings include exposed Cesium Ion access tokens, missing CSRF protection on AJAX endpoints, unauthenticated REST API endpoints, and cryptographically weak API key generation. Several high-severity dependency vulnerabilities were also identified that require immediate attention.

---

## Part 1: construkted.js/ Repository

### Technology Stack

- **Language:** TypeScript 4.7.4
- **3D Libraries:** Cesium 1.132, Three.js 0.152.0
- **Build Tools:** Vite 5.4.10, Rollup 2.53.2, Gulp 4.0.2
- **Dependencies:** jQuery 3.6.3, markdown-it, proj4, @turf/turf

---

### Critical Severity Issues

#### Issue #1: Cesium Ion Access Token Exposure

**File:** `src/index.ts:338`  
**Severity:** Critical  
**CWE:** CWE-798 - Use of Hard-coded Credentials

```typescript
Ion.defaultAccessToken = CONSTRUKTED_AJAX.cesium_access_token;
if (!Ion.defaultAccessToken) console.warn("default access token is null!");
```

**Description:**  
The Cesium Ion access token is exposed via the global `CONSTRUKTED_AJAX` object and passed directly to the Cesium library. This token provides access to Cesium Ion services which may incur billing charges and provide access to potentially sensitive geospatial data.

**Impact:**  
- Unauthorized access to Cesium Ion services
- Potential billing fraud and unexpected charges
- Access to premium terrain and imagery data
- Data exfiltration from user's 3D assets

**Remediation:**  
1. Implement a server-side proxy that forwards tile requests without exposing the token
2. Restrict token usage by referer/origin in Cesium Ion dashboard
3. Rotate all currently exposed tokens immediately
4. Store tokens in server-side environment variables only
5. Implement token refresh rotation schedule

**Reference:** https://cesium.com/ion/tokens

---

#### Issue #2: Missing CSRF Protection in AJAX Calls

**File:** `src/construkted_ajax.ts` (entire file)  
**Severity:** Critical  
**CWE:** CWE-352 - Cross-Site Request Forgery (CSRF)

**Affected Functions:**
- `saveCurrentView()` - lines 11-39
- `resetCameraView()` - lines 69-96
- `captureThumbnail()` - lines 98-181
- `removeThumbnail()` - lines 183-238
- `saveActiveEditor()` - lines 252-280
- `saveGeolocation()` - lines 291-366
- `saveIgnoreOriginalTransform()` - lines 368-391
- `submitAssetGlobeStatusDisplay()` - lines 393-428
- `removeAssetFromGlobe()` - lines 430-465
- `saveSceneBackgroundColor()` - lines 467-491
- `saveDepthTestAgainstTerrain()` - lines 493-517
- `getOriginallyGeoreferenced()` - lines 519-538
- `setOriginallyGeoreferenced()` - lines 540-557

**Example Vulnerable Code:**
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

**Description:**  
All AJAX requests lack CSRF token validation. While some operations retrieve nonces from DOM attributes (like `data-nonce`), these are never included in requests or validated server-side.

**Impact:**  
- Cross-Site Request Forgery attacks allowing unauthorized state-changing requests
- Attackers can manipulate user's saved camera views
- Unauthorized asset geolocation changes
- Thumbnail capture/delete operations can be triggered
- Asset editor settings can be modified

**Remediation:**  
1. Include CSRF token in all AJAX requests
2. Server-side validation of nonce for each request
3. Use WordPress nonces (`wp_create_nonce()`) consistently
4. Verify the nonce matches the action and user
5. Add SameSite cookie attribute for session cookies

---

#### Issue #3: DOM Clobbering XSS via Rollup Bundler

**Package:** `rollup <2.79.2`  
**Severity:** Critical  
**CWE:** CWE-79 - Cross-site Scripting (XSS)  
**Advisory:** https://github.com/advisories/GHSA-gcx4-mw62-g8wm

**Description:**  
The Rollup bundler version 2.53.2 contains a DOM clobbering vulnerability that can lead to XSS attacks when bundled scripts are included in HTML pages.

**Impact:**  
- Arbitrary JavaScript execution in victim's browser
- Session hijacking
- Credential theft
- Malicious redirects

**Remediation:**  
1. Update Rollup to version 2.79.2 or higher
2. If update causes compatibility issues, implement content security policy headers
3. Audit bundled output for global variable pollution
4. Consider migrating to alternative bundler (esbuild, webpack 5)

---

### High Severity Issues

#### Issue #4: Axios CSRF Vulnerability (Transitive Dependency)

**Package:** `axios <=0.29.0` (via `browser-sync`)  
**Severity:** High  
**CWE:** CWE-352 - Cross-Site Request Forgery (CSRF)  
**Advisory:** https://github.com/advisories/GHSA-wf5p-g6vw-rhxx

**Impact:**  
Remote attackers can perform CSRF attacks via specially crafted web pages due to axios handling of requests.

**Remediation:**  
```bash
npm audit fix --force
```

**Note:** This will upgrade browser-sync from 2.26.14 to 3.0.4 which is a breaking change.

---

#### Issue #5: Axios SSRF and Credential Leakage

**Package:** `axios <=0.29.0`  
**Severity:** High  
**CWE:** CWE-918 - Server-Side Request Forgery (SSRF)  
**Advisory:** https://github.com/advisories/GHSA-jr5f-v2jv-69x6

**Impact:**  
Requests with absolute URLs can bypass security boundaries, potentially exposing internal network resources or credentials.

**Remediation:**  
1. Implement URL validation before making requests
2. Block requests to private IP ranges
3. Use relative URLs when possible
4. Update axios to latest version

---

#### Issue #6: Regular Expression Denial of Service in Braces

**Package:** `braces <3.0.3`  
**Severity:** High  
**CWE:** CWE-1333 - Regular Expression Denial of Service (ReDoS)  
**Advisory:** https://github.com/advisories/GHSA-grv7-fg5c-xmjg

**Impact:**  
Malformed input can cause catastrophic backtracking, leading to denial of service.

**Remediation:**  
```bash
npm audit fix --force
```

**Note:** This will upgrade gulp from 4.0.2 to 5.0.1 which is a breaking change.

---

#### Issue #7: Template Injection XSS via Send

**Package:** `send <0.19.0` (via `browser-sync`)  
**Severity:** High  
**CWE:** CWE-79 - Cross-site Scripting (XSS)  
**Advisory:** https://github.com/advisories/GHSA-m6fv-jmcg-4jfg

**Impact:**  
Template injection in development server can lead to XSS attacks.

**Remediation:**  
```bash
npm audit fix --force
```

---

#### Issue #8: HTML Entities Decoding XSS Risk

**File:** `src/ConstruktedApi.ts:175-196`  
**Severity:** High  
**CWE:** CWE-79 - Cross-site Scripting (XSS)

```typescript
export const decodeEntities = (function () {
    const element = document.createElement("div");
    function decodeHTMLEntities(str: any) {
        if (str && typeof str === "string") {
            str = str.replace(/<script[^>]*>([\S\s]*?)<\/script>/gim, "");
            str = str.replace(/<\/?\w(?:[^"'>]|"[^"]*"|'[^']*')*>/gim, "");
            element.innerHTML = str;
            str = element.textContent;
            element.textContent = "";
        }
        return str;
    }
    return decodeHTMLEntities;
})();
```

**Description:**  
The `innerHTML` assignment followed by `textContent` extraction can still execute scripts in certain edge cases and is not a safe XSS mitigation strategy.

**Impact:**  
- Potential XSS attacks if bypass techniques are discovered
- Inconsistent behavior across browsers
- Maintenance burden from custom sanitization

**Remediation:**  
1. Replace with a proper HTML sanitization library (DOMPurify)
2. Use `textContent` assignment only, never `innerHTML`
3. Implement Content Security Policy headers
4. Use `DOMPurify.sanitize()` with appropriate config

```typescript
import DOMPurify from 'dompurify';

const decodeEntities = (str: string): string => {
    const element = document.createElement("div");
    element.textContent = str;
    return DOMPurify.sanitize(element.innerHTML);
};
```

---

#### Issue #9: Console Information Leakage in Production

**File:** `src/index.ts:299-303`  
**Severity:** Medium  
**CWE:** CWE-532 - Information Exposure Through Log Files

```typescript
if (isLocal()) {
    console.info("original CONSTRUKTED_AJAX", window.CONSTRUKTED_AJAX);
    console.info(JSON.stringify(window.CONSTRUKTED_AJAX));
    // ... more console logging
}
```

**Description:**  
Sensitive configuration data including potentially access tokens is logged to browser console during development mode.

**Impact:**  
- Information disclosure to anyone with browser access
- Potential exposure during screen sharing or screenshots
- Debug information persists in some browsers

**Remediation:**  
1. Remove all console.info() calls in production code
2. Use conditional logging with environment check
3. Ensure isLocal() check prevents all logging in production
4. Use structured logging library with level filtering

---

#### Issue #10: Development Mode Feature Bypass

**File:** `src/ConstruktedApi.ts:18-23`  
**Severity:** Low  
**CWE:** CWE-656 - Reliance on Security Through Obscurity

```typescript
export const isLocal = () =>
    location.hostname === "cesiumgis.com" || location.hostname === "localhost" || location.hostname === "127.0.0.1";

export const isGw4 = () => location.hostname === "gw4.construkted.com";
```

**Description:**  
Hostname-based feature flags enable development behaviors that may not be appropriate for production environments.

**Impact:**  
- Security controls may be inadvertently disabled on lookalike domains
- Local development features accessible on staging
- Maintenance confusion from scattered feature flags

**Remediation:**  
1. Use build-time constants instead of runtime checks
2. Implement proper environment configuration
3. Consolidate feature flags to single configuration object
4. Use build-time environment variables

---

## Part 2: construkted_reality_v1.x/ Repository (WordPress Theme)

### Technology Stack

- **Platform:** WordPress (PHP 8.x)
- **Components:** Custom REST API, AJAX handlers, frontend submission
- **Theme:** gowatch-child (child theme)
- **Integration:** External API via jQuery AJAX

---

### Critical Severity Issues

#### Issue #11: Unauthenticated REST API Endpoints

**File:** `includes/class.api.php:66-99`  
**Severity:** Critical  
**CWE:** CWE-306 - Missing Authentication

**Exposed Endpoints:**
```php
register_rest_route('ck/v1', '/getAssets', array(
    'methods' => 'GET',
    'callback' => array($this, 'get_assets'),
    'permission_callback' => function () {
        return true; // No authentication required
    }
));

register_rest_route('ck/v1', '/getAsset/(?P<id>[a-zA-Z0-9-]+)', array(
    'methods' => 'GET',
    'callback' => array($this, 'get_asset'),
    'permission_callback' => function () {
        return true; // No authentication required
    }
));

register_rest_route('ck/v1', '/addAsset', array(
    'methods' => 'POST',
    'callback' => array($this, 'add_asset'),
    'permission_callback' => function () {
        return true; // No authentication required
    }
));
```

**Description:**  
All REST API endpoints (`/ck/v1/getAssets`, `/ck/v1/getAsset/{id}`, `/ck/v1/addAsset`) have no authentication requirement. The `permission_callback` returns `true` unconditionally.

**Impact:**  
- Unauthenticated access to all user asset data
- Private asset enumeration and data exfiltration
- Unauthorized asset creation
- User data exposure without authentication

**Remediation:**  
1. Implement proper authentication in all permission_callback functions
2. Add API key validation for all endpoints
3. Implement rate limiting per IP address
4. Add request logging for audit trail
5. Consider OAuth 2.0 for API authentication

**Example Fix:**
```php
'permission_callback' => function ($request) {
    $api_key = $this->get_api_key_from_header();
    if (!$api_key) {
        return false;
    }
    return $this->validate_api_key($api_key, 'read');
}
```

---

#### Issue #12: Cryptographically Weak API Key Generation

**File:** `includes/class.api.php:549-553`  
**Severity:** Critical  
**CWE:** CWE-328 - Use of Weak Hash

```php
function generate_api_key()
{
    $key = md5(uniqid(rand(), true));
    return $key;
}
```

**Description:**  
API keys are generated using `md5()` combined with `uniqid()` and `rand()`. This approach has multiple vulnerabilities:

1. `md5()` is cryptographically broken and vulnerable to collision attacks
2. `uniqid()` is based on microtime and predictable
3. `rand()` is not cryptographically secure
4. The combination produces only 32 hexadecimal characters

**Impact:**  
- API keys can be predicted or brute-forced
- Collision attacks possible with md5
- Keys are easily enumerable
- Account takeover via API key prediction

**Remediation:**  
1. Use `wp_generate_password()` or `random_bytes()` with `bin2hex()`
2. Implement key prefix for key type identification
3. Add key expiration and rotation
4. Implement key hashing for storage (HMAC)

**Example Fix:**
```php
function generate_api_key()
{
    return 'ck_' . bin2hex(random_bytes(32));
}

// Store hashed version
$hashed_key = hash('sha256', $key);
```

---

#### Issue #13: Plain Text Password Storage for Protected Assets

**File:** `includes/ajax.php:559-564`  
**Severity:** High  
**CWE:** CWE-256 - Plaintext Storage of a Password

```php
if ($view_access === 'password' && isset($_POST['assetPassword'])) {
    $asset_password = sanitize_text_field($_POST['assetPassword']);
    update_post_meta($post_id, 'asset_view_password', $asset_password);
}
```

**Description:**  
Asset protection passwords are stored in plain text in post meta without any hashing or encryption.

**Impact:**  
- Any user with database access can view all asset passwords
- WordPress admin panel exposes all passwords
- SQL injection would expose all passwords
- No protection against password reuse attacks

**Remediation:**  
1. Hash passwords using `wp_hash_password()` or `password_hash()`
2. Use `password_verify()` for comparison
3. Store only the hash, never the plaintext
4. Implement proper salt management

**Example Fix:**
```php
if ($view_access === 'password' && isset($_POST['assetPassword'])) {
    $asset_password = sanitize_text_field($_POST['assetPassword']);
    $hashed_password = wp_hash_password($asset_password);
    update_post_meta($post_id, 'asset_view_password', $hashed_password);
}
```

---

### Medium Severity Issues

#### Issue #14: Inconsistent Input Validation

**File:** `includes/ajax.php` (multiple functions)  
**Severity:** Medium  
**CWE:** CWE-20 - Improper Input Validation

**Examples of Inconsistent Sanitization:**
```php
// Using intval
$post_id = intval($data['post_id']);

// Using absint
$post_id = absint($_REQUEST['asset_id']);

// Using sanitize_text_field
$view_access = sanitize_text_field($_POST['viewAccess']);

// Direct access without sanitization
$post_id = $_REQUEST['post_id'];
```

**Description:**  
Input validation uses different methods inconsistently across functions, with some inputs accessed directly from `$_REQUEST` without sanitization.

**Impact:**  
- Potential SQL injection if unvalidated input reaches database
- Data integrity issues from type confusion
- Inconsistent behavior across endpoints
- Hard to audit security coverage

**Remediation:**  
1. Create a centralized input validation class
2. Define type-specific validators for each data type
3. Use WordPress sanitization functions consistently
4. Add input validation tests

---

#### Issue #15: Verbose Error Messages

**File:** `includes/ajax.php` (multiple locations)  
**Severity:** Medium  
**CWE:** CWE-210 - Information Exposure Through Error Messages

**Examples:**
```php
echo "failed to delete old thumbnail!";
echo "failed to updated!";
return array('success' => false, 'message' => 'failed to update post meta!');
```

**Description:**  
Error messages expose implementation details and failure modes that could aid attackers in understanding the system.

**Impact:**  
- Information disclosure about internal structure
- Error-based enumeration attacks
- Debug information leakage
- Potential SQL injection hints

**Remediation:**  
1. Use generic error messages in production
2. Log detailed errors server-side only
3. Implement error codes instead of messages
4. Add production error handling layer

---

#### Issue #16: Missing Rate Limiting

**All AJAX and REST API endpoints**  
**Severity:** Medium  
**CWE:** CWE-307 - Missing Rate Limiting on API

**Description:**  
No rate limiting or throttling is implemented on any AJAX or REST API endpoint. This allows unlimited requests from any source.

**Impact:**  
- Brute force attacks on password-protected assets
- Denial of service through request flooding
- Resource exhaustion
- Automated scanning and enumeration

**Remediation:**  
1. Implement WordPress transient-based rate limiting
2. Add request counting per IP per endpoint
3. Return 429 Too Many Requests on limit
4. Consider WordPress plugins for rate limiting

---

#### Issue #17: Unauthenticated AJAX Endpoints via wp_ajax_nopriv

**File:** `includes/ajax.php`  
**Severity:** Critical  
**CWE:** CWE-306 - Missing Authentication

```php
add_action('wp_ajax_nopriv_post_set_current_view', 'post_set_current_view');
add_action('wp_ajax_post_set_current_view', 'post_set_current_view');
// Multiple endpoints registered with _nopriv hooks
```

**Description:**  
Many AJAX endpoints are registered with both `wp_ajax_*` and `wp_ajax_nopriv_*` hooks, allowing unauthenticated access to sensitive operations.

**Impact:**  
- Unauthorized state changes by any visitor
- Asset manipulation without authentication
- Thumbnail capture/delete by anonymous users
- Geolocation modifications by anyone

**Remediation:**  
1. Remove `wp_ajax_nopriv_*` hooks for sensitive operations
2. Add authentication checks in handler functions
3. Implement proper capability checks
4. Review each endpoint for auth requirements

---

## Dependency Vulnerability Summary

| Package | Current Version | Vulnerability | Severity | Remediation |
|---------|---------------|--------------|----------|-------------|
| axios | <=0.29.0 | CSRF, SSRF | High | `npm audit fix --force` |
| braces | <3.0.3 | ReDoS | High | `npm audit fix --force` |
| rollup | <2.79.2 | DOM Clobbering | Critical | Upgrade to 2.79.2+ |
| html-minifier | Any | REDoS | High | Replace with alternative |
| esbuild | <=0.24.2 | SSRF | Moderate | `npm audit fix --force` |
| send | <0.19.0 | XSS | High | `npm audit fix --force` |
| vite | 5.4.10 | Depends on vulnerable esbuild | Moderate | Update with audit fix |

---

## Recommendations Summary

### Immediate Actions (Critical Priority)

1. **Rotate Cesium Ion tokens** - All exposed tokens should be revoked and regenerated
2. **Add CSRF protection** - Implement nonce validation on all AJAX endpoints
3. **Fix REST API auth** - Remove permissive `permission_callback` return values
4. **Hash API keys** - Replace weak `md5(uniqid())` with `random_bytes()`
5. **Remove unauthenticated nopriv hooks** - Audit all `wp_ajax_nopriv_*` registrations
6. **Hash asset passwords** - Implement `wp_hash_password()` for asset protection

### Short-term Actions (High Priority)

7. **Update dependencies** - Run `npm audit fix --force` to patch vulnerabilities
8. **Consolidate input validation** - Create centralized validation utility
9. **Implement rate limiting** - Add request throttling to all API endpoints
10. **Replace HTML sanitization** - Use DOMPurify instead of innerHTML approach

### Long-term Improvements (Medium Priority)

11. **Implement API versioning** - Add v2 API with improved security
12. **Add request logging** - Implement audit trail for all operations
13. **Security headers** - Add CSP, X-Frame-Options, HSTS
14. **Penetration testing** - Commission third-party security audit
15. **Security training** - Educate developers on secure coding practices

---

## References

- OWASP Top 10: https://owasp.org/www-project-top-ten/
- CWE Database: https://cwe.mitre.org/
- npm Security advisories: https://www.npmjs.com/advisories
- WordPress Security: https://developer.wordpress.org/coding-standards/wordpress-coding-standards/php/

---

*End of Security Audit Report*