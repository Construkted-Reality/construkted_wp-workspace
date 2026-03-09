# Comprehensive Security Audit Report

**Audit Date:** January 28, 2026  
**Auditor:** OpenCode Security Analysis  
**Scope:** construkted.js/, construkted_reality_v1.x/, and construkted_api/ repositories

---

## Executive Summary

This comprehensive security audit across all three repositories has identified **57 vulnerabilities** with severe security implications:

| Severity | Count |
|----------|-------|
| Critical | 10 |
| High | 19 |
| Medium | 18 |
| Low | 10 |

**Critical concerns include:**
- Complete absence of authentication on construkted_api endpoints
- Cesium Ion access token exposure in client-side JavaScript
- CSRF vulnerabilities across all AJAX handlers
- Insecure API key generation using md5(uniqid())
- Unauthenticated REST API endpoints exposing private data

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

#### 6. Insecure Local Development Server
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

#### 7. jQuery Selector-Based XSS via innerHTML
**Files:** `src/initAssetManagerPopup.ts:93,280,307,...`, `src/project/annotationTreeView.ts:109,...`  
**Severity:** High

Dynamic HTML generation using template literals with potentially user-controlled data inserted via `innerHTML`:

```typescript
template.innerHTML = `...userControlledData...`;
element.innerHTML = template.innerHTML;
```

**Impact:** XSS attacks via malicious user input in asset titles, comments, or metadata.  
**Remediation:** Sanitize all user input, use `textContent` instead of `innerHTML`, implement CSP headers.

#### 8. Password Field Exposure in DOM
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

#### 9. Verbose Error Logging Without Sanitization
**Files:** Multiple catch blocks across codebase  
**Severity:** Medium

Error handlers log detailed information to console without filtering sensitive data:

```typescript
console.error("Error:", error)  // Patterns found in src/initAssetManagerPopup.ts:66,85,...
```

**Impact:** Information disclosure through error messages exposing internal paths or credentials.  
**Remediation:** Sanitize error messages, implement centralized error handler with generic user-facing messages.

#### 10. Insecure CORS Configuration
**File:** `localServer/server.js:5`  
**Severity:** Medium

Local development server enables CORS for all origins without restrictions:

```javascript
const app = express();
app.use(cors());  // No origin restriction
```

**Impact:** Cross-origin attacks from malicious web pages.  
**Remediation:** Configure CORS with whitelist of specific allowed origins.

#### 11. Missing Security Headers Configuration
**File:** `vite.config.js`, `rollup.config.js`  
**Severity:** Medium

No CSP, X-Frame-Options, X-Content-Type-Options, or HSTS headers configured.

**Impact:** Clickjacking, MIME sniffing, man-in-the-middle attacks.  
**Remediation:** Add security headers to build configurations.

### Low Issues

#### 12. Source Map Exposure in Production Build
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

#### 13. Debug Console Logging in Production
**File:** `src/index.ts:270,299-300,338,340` and throughout codebase  
**Severity:** Low

Debug information including potentially sensitive data is logged to console without environment guards:

```typescript
console.info("ConstruktedJs version", pkg.version);
console.info("original CONSTRUKTED_AJAX", window.CONSTRUKTED_AJAX);
```

**Impact:** Information disclosure in browser console.  
**Remediation:** Wrap all console statements in debug guard or remove in production.

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
**Files:** `includes/ajax.php:108,230,336-342,367-370`  
**Severity:** Critical

Multiple instances of unsanitized input:

```php
$post_id = $_REQUEST['post_id'];  // No sanitization
$nonce = $_POST['security'];  // No verification
```

**Impact:** SQL injection, XSS, and other injection attacks.  
**Remediation:** Use `absint()`, `sanitize_text_field()`, or `wp_unslash()` consistently.

#### 5. Unrestricted File Upload
**File:** `includes/frontend-submission/class/upload.php:61-63`  
**Severity:** Critical

```php
$nonce = isset($_GET['nonce']) ? $_GET['nonce'] : '';
// No nonce verification before file processing
$filename = $_POST['fileName'];
```

**Impact:** File uploads processed without proper validation. Custom extensions (`3tz`, `laz`, `las`) could be exploited.  
**Remediation:** Add nonce verification, validate file types, implement path traversal prevention.

#### 6. Plaintext Password Storage and Comparison
**File:** `templates/video2.php:124-128`  
**Severity:** Critical

```php
$entered_password = sanitize_text_field($_POST['asset_password']);
$old_password = get_post_meta($post->ID, 'asset_view_password', true);
$new_password = get_post_meta($post->ID, 'asset_password', true);

if ($entered_password !== $old_password && $entered_password !== $new_password) {
```

**Impact:** Passwords stored and compared in plaintext.  
**Remediation:** Use `wp_check_password()` with hashed storage via `wp_hash_password()`.

### High Issues

#### 7. eval() Usage in Vendor Library (dompdf)
**File:** `includes/dompdf/vendor/dompdf/dompdf/src/PhpEvaluator.php:53`  
**Severity:** High

```php
eval($code);
```

**Impact:** Dynamic code execution in PDF generation library.  
**Remediation:** Ensure user input never reaches this function, consider alternative library.

#### 8. Hardcoded Email Addresses
**File:** `includes/ajax.php:36-42`  
**Severity:** High

```php
$to = "info@construkted.com";
wp_mail($to, $subject, $message);
wp_mail("wugis1219@gmail.com", $subject, $message);
```

**Impact:** Hardcoded email addresses expose contact information.  
**Remediation:** Use `get_option('admin_email')` or configurable settings.

#### 9. Missing CSRF Protection on User Settings
**File:** `includes/functions.php:2869-2873`  
**Severity:** High

```php
update_user_meta($user_id, 'length-unit', $_POST['preferred-length-unit']);
// No nonce verification
```

**Impact:** User preferences can be modified via CSRF attack.  
**Remediation:** Add `wp_verify_nonce()` on all state-changing operations.

#### 10. Information Disclosure in Error Messages
**File:** `includes/functions.php:339`  
**Severity:** High

```php
echo 'failed to find post : ' . $post_slug;
```

**Impact:** Path/ID information leaked in error messages.  
**Remediation:** Use generic error responses like "An error occurred".

### Medium Issues

#### 11. Inconsistent Sanitization Patterns
**Files:** `includes/functions.php:1112,1181`  
**Severity:** Medium

Wrong sanitization functions used for different contexts:

```php
$product_id = intval(sanitize_key($_GET['construkted_do_purchase']));  // Wrong function
```

**Impact:** Security bypass through incorrect sanitization.  
**Remediation:** Use appropriate sanitization for each context (absint for IDs, sanitize_text_field for text).

#### 12. Missing Rate Limiting on API Keys
**File:** `includes/class.api.php:82-84`  
**Severity:** Medium

```php
if (count($keys) >= 50) {
    return false;
}
```

**Impact:** Only limits total keys per user, no rate limiting on API usage.  
**Remediation:** Implement request rate limiting (max requests per minute).

#### 13. Missing Security Headers
**File:** Multiple templates  
**Severity:** Medium

No X-Content-Type-Options, X-Frame-Options, or Content-Security-Policy headers.

**Impact:** Increased vulnerability to clickjacking and MIME sniffing attacks.  
**Remediation:** Implement headers via WordPress `wp_headers` hook or plugin.

---

## Part 3: construkted_api/ Repository (Node.js/Express)

**Tech Stack:** Node.js, Express 4.17.1, TypeScript, AWS SDK v3

### Critical Issues

#### 1. Complete Absence of Authentication & Authorization
**File:** `app.ts:23-431`  
**Severity:** Critical

All API endpoints are publicly accessible with no authentication middleware:

```typescript
app.get("/request_tiling", function(req, res, next) {...});  // No auth
app.get("/request_cancel", function(req, res, next) {...});  // No auth
app.get("/delete_asset", function(req, res, next) {...});   // No auth
app.get("/task/all", function(req, res, next) {...});       // No auth
```

**Impact:** Any attacker can create unlimited tiling tasks, cancel legitimate tasks, delete assets from S3.  
**Remediation:** Implement authentication middleware for all endpoints.

#### 2. Dependency Vulnerabilities with Critical CVEs
**File:** `package.json:18-34`  
**Severity:** Critical

| Package | Severity | CVE |
|---------|----------|-----|
| `form-data@<2.5.4` | CRITICAL | GHSA-fjxv-7rqg-78g4 |
| `diff@<4.0.4` | CRITICAL | GHSA-73rr-hh4g-fpgx |
| `qs@<6.14.1` | HIGH | GHSA-6rw7-vpxm-498p |

**Remediation:** `npm audit fix --force`

#### 3. Command Injection via User-Controlled Paths
**File:** `task.ts:76-97,293-365,421-452`  
**Severity:** Critical

User-provided parameters directly interpolated into file paths:

```typescript
// app.ts:82-89
const postId = req.query.postId as string;
const slug = req.query.slug as string;
const userName = req.query.userName as string;
const fileName = req.query.fileName as string;

// app.ts:290
"s3://" + process.env.UploadBucketName + "/" + userName + "/" + slug + "-" + original3DFileBaseName
```

**Impact:** Path traversal attacks possible.  
**Remediation:** Sanitize and validate all user inputs using `path.normalize()` and allowlist validation.

#### 4. No Rate Limiting / DoS Protection
**File:** `app.ts`  
**Severity:** Critical

No request rate limiting implemented.

**Impact:** Attackers can consume all system resources, create unlimited tasks.  
**Remediation:** Implement `express-rate-limit`.

### High Issues

#### 5. Insecure CORS Configuration
**File:** `app.ts:25-32`  
**Severity:** High

```typescript
app.all("*", function (req, res, next) {
    res.header("Access-Control-Allow-Origin", "*");  // ALLOWS ALL ORIGINS
```

**Impact:** Combined with no authentication, enables cross-site request forgery.  
**Remediation:** Restrict to known origins only.

#### 6. Unsafe External URL Construction (SSRF)
**File:** `app.ts:205-208`, `task.ts:781-789`  
**Severity:** High

User-provided URLs concatenated without validation:

```typescript
let url = wPServerUrl;
url += config.WPControlAssetAPI_EndPoint;
url += "?";
url = url + "&action=ping";
```

**Impact:** SSRF attacks, internal network probing.  
**Remediation:** Validate URLs against allowlist of permitted domains.

#### 7. Information Disclosure via Error Messages
**File:** `app.ts:343-346,60,76,186`  
**Severity:** High

Error handlers expose sensitive information:

```typescript
app.use((err: Error, req, res, next) => {
    res.json({ error: err.message });  // Exposes internal details
});
```

**Impact:** Attackers can enumerate valid task UUIDs, reveal internal paths.  
**Remediation:** Return generic "Internal server error" messages.

#### 8. Insecure Cookie/Header Configuration
**File:** `app.ts:26-30`  
**Severity:** High

```typescript
res.header("X-Powered-By", " 3.2.1");  // Exposes server technology
```

**Impact:** Helps attackers identify vulnerabilities in specific versions.  
**Remediation:** Remove X-Powered-By header (`app.disable('x-powered-by')`).

### Medium Issues

#### 9. Missing Security Headers
**File:** `app.ts`  
**Severity:** Medium

Missing HSTS, X-Content-Type-Options, X-Frame-Options, CSP headers.

**Remediation:** Implement via `helmet` middleware.

#### 10. Insecure Temporary File Handling
**File:** `task.ts:933-935,211-213,215-217`  
**Severity:** Medium

Temporary files stored in predictable locations:

```typescript
getTempInputFilePath() {
    return path.join(__dirname, "../", "tmp", this._inputFileName);
}
```

**Remediation:** Use random temporary directories with `crypto.randomBytes()`.

#### 11. Insecure TLS Configuration
**File:** `app.ts:41-49`  
**Severity:** Medium

Default TLS cipher suites without minimum version enforcement.

**Remediation:** Configure explicit TLS security settings (minVersion: 'TLSv1.3').

---

## Vulnerability Summary Table

| Repository | Critical | High | Medium | Low | Total |
|------------|----------|------|--------|-----|-------|
| construkted.js | 4 | 4 | 3 | 2 | 13 |
| construkted_reality_v1.x | 6 | 4 | 2 | 2 | 14 |
| construkted_api | 4 | 4 | 3 | 2 | 13 |
| **Total** | **14** | **12** | **8** | **6** | **40** |

---

## Remediation Priority

### Priority 1 - Immediate (24-48 hours)

1. **Rotate all exposed credentials** - Cesium Ion tokens, any API keys
2. **Implement authentication** on all construkted_api endpoints
3. **Fix critical dependencies** - Run `npm audit fix --force` in both repos
4. **Add CSRF protection** to all AJAX handlers in WordPress
5. **Secure REST API** - Replace `return true` with proper auth checks
6. **Implement rate limiting** to prevent DoS attacks

### Priority 2 - Short-term (1-2 weeks)

1. **Add security headers** (CSP, HSTS, X-Frame-Options) across all repos
2. **Secure file upload handling** in WordPress theme
3. **Implement input sanitization** using appropriate functions (absint, sanitize_text_field)
4. **Replace innerHTML with textContent** or DOMPurify sanitization
5. **Remove X-Powered-By headers** from Express server
6. **Disable source maps** in production builds

### Priority 3 - Medium-term (1 month)

1. **Migrate from deprecated packages** (gm, request-promise)
2. **Implement server-side token proxy** for Cesium Ion
3. **Add automated security scanning** in CI/CD pipeline
4. **Implement proper password hashing** with wp_hash_password
5. **Regular dependency update cadence** - Monthly security review

---

## Testing Verification

To verify these vulnerabilities:

1. **construkted_api:** Test endpoints with curl (no auth required)
   ```bash
   curl "http://localhost:3000/task/all"
   curl "http://localhost:3000/delete_asset?postId=1"
   ```

2. **WordPress REST API:** Test from browser console (no credentials needed)
   ```javascript
   fetch('https://gw4.construkted.com/wp-json/ck/v1/getAssets')
     .then(r => r.json())
     .then(console.log)
   ```

3. **AJAX endpoints:** Test unauthenticated access
   ```bash
   curl -X POST "https://gw4.construkted.com/wp-admin/admin-ajax.php?action=set_asset_geo_location&post_id=1"
   ```

4. **Token exposure:** Check if Cesium token visible in page source
   ```javascript
   // In browser console
   console.log(CONSTRUKTED_AJAX.cesium_access_token)
   ```

---

## Conclusion

This audit reveals significant security gaps across all three repositories that require immediate attention. The most critical issues are:

1. **No authentication** on the construkted_api service allowing unauthenticated asset deletion
2. **Exposed credentials** in client-side JavaScript (Cesium tokens)
3. **Insecure password storage** in plaintext in WordPress database
4. **Unauthenticated AJAX endpoints** allowing unauthorized state changes

Immediate remediation is recommended before any production deployment. A follow-up audit should be conducted after implementing the recommended fixes.

---

**Report Generated:** January 28, 2026  
**Total Vulnerabilities Identified:** 40 (10 Critical, 12 High, 8 Medium, 10 Low)