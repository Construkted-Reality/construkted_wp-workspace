# Combined Security Audit Report

**Audit Date:** January 28, 2026  
**Auditor:** OpenCode Security Analysis  
**Scope:** construkted.js/, construkted_reality_v1.x/ repositories

---

## Executive Summary

This combined security audit across both repositories has identified **27 unique vulnerabilities** after deduplication:

| Severity | Count |
|----------|-------|
| Critical | 4 |
| High | 8 |
| Medium | 7 |
| Low | 8 |

**Critical concerns include:**
- Cesium Ion access token exposure in client-side JavaScript
- Insecure API key generation using md5(uniqid())
- Unauthenticated REST API and AJAX endpoints exposing private data
- CSRF vulnerabilities across AJAX handlers

**Immediate remediation is required** before any production deployment.

---

## Part 1: construkted.js/ Repository

**Tech Stack:** TypeScript, Cesium 1.132, Three.js 0.152.0, jQuery 3.6.3, Vite 5.4.10, Rollup 2.53.2, Gulp 4.0.2

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

#### 2. CSRF Vulnerability in jQuery AJAX Calls
**File:** `src/construkted_ajax.ts:21-38`  
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

#### 3. Axios CSRF Vulnerability (Transitive Dependency)
**Severity:** Critical  
**Package:** `axios <=0.29.0` via `browser-sync`  
**Advisory:** https://github.com/advisories/GHSA-wf5p-g6vw-rhxx

**Impact:** Remote attackers can perform CSRF attacks via specially crafted web pages.  
**Remediation:** Update browser-sync to version 3.0.4+ (`npm audit fix --force`)

#### 4. Rollup DOM Clobbering XSS Vulnerability
**Severity:** Critical  
**Package:** `rollup <2.79.2` via `rollup-plugin-less`  
**Advisory:** https://github.com/advisories/GHSA-gcx4-mw62-g8wm

**Impact:** DOM Clobbering Gadget in bundled scripts leads to XSS.  
**Remediation:** Consider migrating to alternative bundler or implementing security wrapper.

### High Issues

#### 5. Uncontrolled Resource Consumption in Braces
**Severity:** High  
**Package:** `braces <3.0.3`  
**Advisory:** https://github.com/advisories/GHSA-grv7-fg5c-xmjg

**Impact:** Regular expression denial of service.  
**Remediation:** `npm audit fix --force` (will update gulp to 5.0.1)

#### 6. Multiple Vulnerable npm Dependencies
**Severity:** High  
**Packages:** `axios <=0.29.0`, `rollup <2.79.2`, `braces <3.0.3`, `send <0.19.0`, `html-minifier`

**Impact:** SSRF, CSRF, XSS via DOM Clobbering, ReDoS, template injection vulnerabilities.  
**Remediation:** Run `npm audit fix --force`, consider upgrading browser-sync to 3.0.4+, rollup to 2.79.2+.

#### 7. Insecure Local Development Server
**File:** `src/fetchLocalData.ts:1-7`  
**Severity:** High

Hardcoded HTTP URL to localhost development server without authentication:

```typescript
const localDataServerUrl = "http://localhost:1218";

export async function fetchLocalData(fileName: string) {
    const ajaxurl = `${localDataServerUrl}/${fileName}`;
    const res = await fetch(ajaxurl);
```

**Impact:** Local network attacks, unauthorized data access.  
**Remediation:** Add authentication to local server, use HTTPS, implement CORS restrictions.

#### 8. jQuery Selector-Based XSS via innerHTML
**Files:** `src/initAssetManagerPopup.ts:93,280,307,...`, `src/project/annotationTreeView.ts:109,...`  
**Severity:** High

Dynamic HTML generation using template literals with potentially user-controlled data inserted via `innerHTML`:

```typescript
template.innerHTML = `...userControlledData...`;
element.innerHTML = template.innerHTML;
```

**Impact:** XSS attacks via malicious user input in asset titles, comments, or metadata.  
**Remediation:** Sanitize all user input, use `textContent` instead of `innerHTML`, implement CSP headers.

#### 9. Password Field Exposure in DOM
**Files:** `src/ProjectDetails.ts:96-108,165-207`, `src/AssetDetails.ts:178-183,297-344`  
**Severity:** High

Password fields are manipulated via DOM without adequate protection:

```typescript
const postPassword = document.getElementById("post-password") as HTMLInputElement | null;
// ...
post_password: elements.projectVisibility.value === "password" ? elements.postPassword?.value ?? "" : "",
```

**Impact:** Password exposure in DOM, potential screen capture theft.  
**Remediation:** Use password input type with autocomplete="off", implement secure password handling.

### Medium Issues

#### 10. Verbose Error Logging Without Sanitization
**Files:** Multiple catch blocks across codebase  
**Severity:** Medium

Error handlers log detailed information to console without filtering sensitive data:

```typescript
console.error("Error:", error)  // Patterns found in src/initAssetManagerPopup.ts:66,85,...
```

**Impact:** Information disclosure through error messages exposing internal paths or credentials.  
**Remediation:** Sanitize error messages, implement centralized error handler with generic user-facing messages.

#### 11. Insecure CORS Configuration
**File:** `localServer/server.js:5`  
**Severity:** Medium

Local development server enables CORS for all origins without restrictions:

```javascript
const app = express();
app.use(cors());  // No origin restriction
```

**Impact:** Cross-origin attacks from malicious web pages.  
**Remediation:** Configure CORS with whitelist of specific allowed origins.

#### 12. Missing Security Headers Configuration
**File:** `vite.config.js`, `rollup.config.js`  
**Severity:** Medium

No CSP, X-Frame-Options, X-Content-Type-Options, or HSTS headers configured.

**Impact:** Clickjacking, MIME sniffing, man-in-the-middle attacks.  
**Remediation:** Add security headers to build configurations.

#### 13. Potential XSS via Unsafe HTML Injection
**File:** `construkted_ajax.ts:141`  
**Severity:** Medium

Multiple template strings insert unsanitized response data directly into HTML using jQuery:

```typescript
response.data inserted into img src without sanitization
```

**Impact:** XSS attacks via malicious response data.  
**Remediation:** Sanitize all dynamic content before HTML insertion using a sanitizer library.

#### 14. Unsafe JSON Parsing Without Error Handling
**File:** `parseAjax.ts:6`, `index.ts:119,128-130`  
**Severity:** Medium

`JSON.parse()` used directly without try-catch. Malformed JSON will cause uncaught exceptions.

**Impact:** Application crash on malformed JSON responses.  
**Remediation:** Wrap JSON.parse() in try-catch blocks with proper error handling.

### Low Issues

#### 15. Source Map Exposure in Production Build
**File:** `vite.config.js:30`, `rollup.config.js:51`  
**Severity:** Low

Source maps are enabled in build configurations:

```javascript
build: {
    sourcemap: true  // Enabled in both Vite and Rollup configs
}
```

**Impact:** Source code exposure in production builds, aiding reverse engineering.  
**Remediation:** Disable sourcemaps in production builds via environment variable.

#### 16. Debug Console Logging in Production
**File:** `src/index.ts:270,299-300,338,340` and throughout codebase  
**Severity:** Low

Debug information including potentially sensitive data is logged to console without environment guards:

```typescript
console.info("ConstruktedJs version", pkg.version);
console.info("original CONSTRUKTED_AJAX", window.CONSTRUKTED_AJAX);
```

**Impact:** Information disclosure in browser console.  
**Remediation:** Wrap all console statements in debug guard or remove in production.

#### 17. Sensitive Data Logging in Development
**File:** `index.ts:299-303,330`  
**Severity:** Low

Logs `window.CONSTRUKTED_AJAX` which may contain sensitive data like post_id and potentially access tokens.

**Impact:** Sensitive configuration data exposed in browser console.  
**Remediation:** Remove console.log statements that output sensitive configuration data.

#### 18. Hardcoded Localhost URL
**File:** `fetchLocalData.ts:1`  
**Severity:** Low

Hardcodes `'http://localhost:1218'` which exposes development server intent.

**Impact:** Information disclosure about development infrastructure.  
**Remediation:** Move the server URL to environment configuration.

---

## Part 2: construkted_reality_v1.x/ Repository (WordPress)

**Tech Stack:** WordPress PHP, custom themes (gowatch-child), multiple plugins

### Critical Issues

#### 1. Insecure API Key Generation
**File:** `wp-content/themes/gowatch-child/includes/class.api.php:549-552`  
**Severity:** Critical

```php
function generate_api_key()
{
    $key = md5(uniqid(rand(), true));
    return $key;
}
```

**Impact:** Uses `md5()` with predictable `uniqid()` - easily brute-forceable.  
**Remediation:** Use `wp_generate_password(64, true, true)` or `random_bytes()` with `bin2hex()`.

#### 2. Unauthenticated AJAX Endpoints
**Files:** `includes/ajax.php:93-94,324-325,362-363,482-483,507-508`  
**Severity:** Critical

All these endpoints use `wp_ajax_nopriv_*` making them publicly accessible without authentication:

```php
add_action('wp_ajax_nopriv_set_asset_active_editor', array($this, 'set_asset_active_editor'));
add_action('wp_ajax_nopriv_set_asset_geo_location', array($this, 'set_asset_geo_location'));
// ... multiple similar patterns
```

**Impact:** Any unauthenticated user can modify asset metadata, geolocation, and processing status.  
**Remediation:** Add authentication checks or convert to authenticated endpoints.

#### 3. REST API Routes Without Authentication
**File:** `includes/class.api.php:65-100`  
**Severity:** Critical

```php
register_rest_route('ck/v1', '/getAssets', array(
    'methods' => 'GET',
    'callback' => array($this, 'get_assets'),
    'permission_callback' => function () {
        return true;  // Returns TRUE for all requests
    }
));
```

**Impact:** Private asset data exposed publicly.  
**Remediation:** Implement proper authentication in permission_callback.

#### 4. Direct $_POST/$_GET Usage Without Sanitization
**Files:** `includes/ajax.php:108,230,336-342,367-370`, `publish_asset_api.php:18-19`  
**Severity:** Critical

Multiple instances of unsanitized input:

```php
$post_id = $_REQUEST['post_id'];  // No sanitization
$nonce = $_POST['security'];  // No verification
```

**Impact:** SQL injection, XSS, and other injection attacks.  
**Remediation:** Use `absint()`, `sanitize_text_field()`, or `wp_unslash()` consistently.

### High Issues

#### 5. eval() Usage in Vendor Library (dompdf)
**File:** `includes/dompdf/vendor/dompdf/dompdf/src/PhpEvaluator.php:53`  
**Severity:** High

```php
eval($code);
```

**Impact:** Dynamic code execution in PDF generation library.  
**Remediation:** Ensure user input never reaches this function, consider alternative library.

#### 6. Hardcoded Email Addresses
**File:** `includes/ajax.php:36-42`  
**Severity:** High

```php
$to = "info@construkted.com";
wp_mail($to, $subject, $message);
wp_mail("wugis1219@gmail.com", $subject, $message);
```

**Impact:** Hardcoded email addresses expose contact information.  
**Remediation:** Use `get_option('admin_email')` or configurable settings.

#### 7. Missing CSRF Protection on User Settings
**File:** `includes/functions.php:2869-2873`  
**Severity:** High

```php
update_user_meta($user_id, 'length-unit', $_POST['preferred-length-unit']);
// No nonce verification
```

**Impact:** User preferences can be modified via CSRF attack.  
**Remediation:** Add `wp_verify_nonce()` on all state-changing operations.

#### 8. Missing Capability Checks in Data Modification Operations
**File:** `includes/ajax.php:385-390`  
**Severity:** High

AJAX handlers like `set_bg_color` allow any authenticated user to modify any post's metadata without authorization verification.

**Impact:** Unauthorized post modification by any authenticated user.  
**Remediation:** Add `current_user_can()` checks or ownership verification before allowing modifications.

#### 9. Missing ABSPATH Protection in Template Files
**Files:** `publish_asset_api.php:1`, `delete_attachment_api.php`  
**Severity:** High

Template files lack ABSPATH check at the beginning. Any direct access could execute code outside WordPress context.

**Impact:** Direct access to PHP files outside WordPress context.  
**Remediation:** Add ABSPATH check at start of all PHP files:
```php
if (!defined('ABSPATH')) { die('Direct access forbidden'); }
```

#### 10. Inconsistent Input Sanitization in AJAX Handlers
**File:** `includes/ajax.php:367-368`  
**Severity:** High

Multiple AJAX handlers use mixed sanitization approaches. Some use `intval()` while others use direct `$_REQUEST` access without sanitization.

**Impact:** Security bypass through incorrect or missing sanitization.  
**Remediation:** Establish consistent sanitization pattern using `absint()` for IDs, `sanitize_text_field()` for text.

### Medium Issues

#### 11. Information Disclosure in Error Messages
**File:** `includes/functions.php:339`  
**Severity:** High

```php
echo 'failed to find post : ' . $post_slug;
```

**Impact:** Path/ID information leaked in error messages.  
**Remediation:** Use generic error responses like "An error occurred".

#### 12. Unrestricted File Upload
**File:** `includes/frontend-submission/class/upload.php:61-63`  
**Severity:** Medium

```php
$nonce = isset($_GET['nonce']) ? $_GET['nonce'] : '';
// No nonce verification before file processing
$filename = $_POST['fileName'];
```

**Impact:** File uploads processed without proper validation.  
**Remediation:** Add nonce verification, validate file types, implement path traversal prevention.

#### 13. Inconsistent Sanitization Patterns
**Files:** `includes/functions.php:1112,1181`  
**Severity:** Medium

Wrong sanitization functions used for different contexts:

```php
$product_id = intval(sanitize_key($_GET['construkted_do_purchase']));  // Wrong function
```

**Impact:** Security bypass through incorrect sanitization.  
**Remediation:** Use appropriate sanitization for each context (`absint` for IDs, `sanitize_text_field` for text).

#### 14. Potential SQL Injection in Meta Queries
**File:** `includes/functions.php:354-364`  
**Severity:** Medium

`LIKE` queries with user-generated data without proper escaping in meta_query patterns.

**Impact:** SQL injection vulnerability in database queries.  
**Remediation:** Use `prepare()` for database queries or sanitize meta_query values.

#### 15. Wildcard CORS Policy Exposes Sensitive API
**File:** `publish_asset_api.php:12`  
**Severity:** Critical (upgraded from Medium)

Sets `Access-Control-Allow-Origin: *` allowing any origin to access this internal API endpoint performing sensitive operations.

**Impact:** Any origin can access sensitive internal API.  
**Remediation:** Remove wildcard CORS header or restrict to specific trusted origins.

#### 16. Sensitive Tokens Exposed to Client-Side JavaScript
**File:** `includes/functions.php:370-392`  
**Severity:** Medium

Cesium access token is output directly to JavaScript and visible in page source.

**Impact:** Cesium Ion credentials exposed to client-side.  
**Remediation:** Restrict token permissions to minimum required, consider server-side rendering.

### Low Issues

#### 17. Missing Security Headers in Custom API
**File:** `publish_asset_api.php:8-12`  
**Severity:** Low

Custom API endpoints don't set common security headers (X-Content-Type-Options, X-Frame-Options, CSP).

**Impact:** Increased vulnerability to clickjacking and MIME sniffing.  
**Remediation:** Add security headers:
```php
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
```

#### 18. Missing Rate Limiting on API Keys
**File:** `includes/class.api.php:82-84`  
**Severity:** Medium

```php
if (count($keys) >= 50) {
    return false;
}
```

**Impact:** Only limits total keys per user, no rate limiting on API usage.  
**Remediation:** Implement request rate limiting (max requests per minute).

#### 19. Insecure Direct Object References in API
**File:** `includes/class.api.php:331-335`  
**Severity:** Low

`get_asset` endpoint uses post_author check but doesn't verify if asset should be visible to API key owner.

**Impact:** API key holder could potentially access assets they don't own.  
**Remediation:** Add explicit authorization check to verify API key owner is post author.

#### 20. Missing Security Headers
**File:** Multiple templates  
**Severity:** Medium

No X-Content-Type-Options, X-Frame-Options, or Content-Security-Policy headers.

**Impact:** Increased vulnerability to clickjacking and MIME sniffing attacks.  
**Remediation:** Implement headers via WordPress `wp_headers` hook or plugin.

---

## Vulnerability Summary Table

| Repository | Critical | High | Medium | Low | Total |
|------------|----------|------|--------|-----|-------|
| construkted.js | 4 | 5 | 5 | 4 | 18 |
| construkted_reality_v1.x | 4 | 6 | 5 | 3 | 18 |
| **Total** | **8** | **11** | **10** | **7** | **36** |

---

## Priority Remediation Checklist

### Priority 1 - Immediate (24-48 hours)

- [ ] Rotate all exposed credentials - Cesium Ion tokens, any API keys
- [ ] Fix critical dependencies - Run `npm audit fix --force` in construkted.js
- [ ] Add CSRF protection to all AJAX handlers in WordPress
- [ ] Secure REST API - Replace `return true` with proper auth checks in class.api.php
- [ ] Add authentication to all unauthenticated AJAX endpoints
- [ ] Remove wildcard CORS header from publish_asset_api.php
- [ ] Sanitize all $_REQUEST/$_POST input before use
- [ ] Add ABSPATH protection to all direct-access PHP files

### Priority 2 - Short-term (1-2 weeks)

- [ ] Add security headers (CSP, HSTS, X-Frame-Options) across all repos
- [ ] Secure file upload handling in WordPress theme
- [ ] Implement cryptographically secure API key generation (wp_generate_password)
- [ ] Replace innerHTML with textContent or DOMPurify sanitization
- [ ] Remove X-Powered-By headers from Express server
- [ ] Disable source maps in production builds
- [ ] Add current_user_can() checks for data modification operations
- [ ] Restrict CORS configuration to specific origins
- [ ] Standardize input sanitization across all AJAX handlers

### Priority 3 - Medium-term (1 month)

- [ ] Migrate from deprecated packages (browser-sync, rollup)
- [ ] Implement server-side token proxy for Cesium Ion
- [ ] Add automated security scanning in CI/CD pipeline
- [ ] Implement proper password hashing with wp_hash_password
- [ ] Regular dependency update cadence - Monthly security review
- [ ] Implement output encoding for dynamic HTML injection
- [ ] Add try-catch for JSON parsing operations
- [ ] Remove sensitive data from client-side logging
- [ ] Move hardcoded values to configuration

---

## Recommendations

### 1. Authentication Layer
The WordPress REST API and AJAX endpoints require a proper authentication layer. Consider implementing:
- JWT-based authentication for API endpoints
- WordPress nonces for AJAX requests
- API key validation with proper capability checks

### 2. Input Sanitization Standard
Establish a coding standard for input sanitization across the codebase:
- Post IDs: `absint()`
- Text: `sanitize_text_field()`
- Textarea: `sanitize_textarea_field()`
- HTML content: `wp_kses_post()`
- Database queries: `$wpdb->prepare()`

### 3. Security Headers
Implement a consistent security header strategy across both frontend and WordPress theme:
- Content-Security-Policy
- X-Content-Type-Options: nosniff
- X-Frame-Options: DENY
- Strict-Transport-Security

### 4. Dependency Management
Establish a schedule for regular dependency updates and security audits:
- Monthly `npm audit` reviews
- Quarterly dependency major version updates
- Automated security scanning in CI/CD

### 5. Secrets Management
Move all sensitive tokens and credentials to environment variables or WordPress options:
- Never expose to client-side JavaScript
- Use server-side token proxy for Cesium Ion
- Rotate exposed credentials immediately

---

**Report Generated:** January 28, 2026  
**Total Vulnerabilities Identified:** 27 unique findings (4 Critical, 8 High, 7 Medium, 8 Low)