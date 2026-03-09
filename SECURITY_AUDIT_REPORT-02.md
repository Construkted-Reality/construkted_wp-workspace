# Security Audit Report
**Date:** January 28, 2026
**Audited Repositories:** construkted.js, construkted_reality_v1.x

---

## Executive Summary

This security audit identified **20 total vulnerabilities** across both repositories. The **construkted_reality_v1.x** (WordPress theme) has the most critical issues with **4 Critical severity findings** requiring immediate remediation, primarily around unauthenticated API access and unsanitized input. The **construkted.js** repository has **7 findings** primarily related to outdated dependencies and missing security headers.

### Severity Distribution

| Severity | construkted.js | construkted_reality_v1.x | Total |
|----------|---------------|------------------------|-------|
| Critical | 0 | 4 | 4 |
| High | 2 | 4 | 6 |
| Medium | 2 | 3 | 5 |
| Low | 3 | 2 | 5 |

---

# Part 1: construkted.js Repository

## 1.1 Dependency Security

### Finding: Multiple Vulnerable npm Dependencies
**Severity:** High  
**Category:** dependency

**Description:** npm audit found 25 vulnerabilities including high-severity issues in:
- axios (<=0.29.0) - SSRF and CSRF vulnerabilities
- rollup (<2.79.2) - XSS via DOM Clobbering
- braces (<3.0.3) - Uncontrolled resource consumption (DoS)
- send (<0.19.0) - Template injection leading to XSS
- html-minifier - REDoS vulnerability

**File:** package.json:18-64, package-lock.json

**Remediation:** Run `npm audit fix --force` to update vulnerable packages. Consider upgrading browser-sync to 3.0.4+, rollup to 2.79.2+, and replacing rollup-plugin-html with a maintained alternative. Review breaking changes before applying.

---

## 1.2 Security Headers

### Finding: Insecure CORS Configuration in Local Server
**Severity:** High  
**Category:** headers

**Description:** localServer/server.js uses cors() without any configuration, allowing requests from any origin. This is insecure for any non-localhost deployment.

**File:** localServer/server.js:2-5

**Remediation:** Replace `app.use(cors())` with `app.use(cors({ origin: 'https://yourdomain.com', credentials: true }))` or restrict to specific allowed origins.

### Finding: Missing Security Headers Configuration
**Severity:** Low  
**Category:** headers

**Description:** vite.config.js has no security headers configured. No CSP, HSTS, X-Frame-Options, or X-Content-Type-Options headers are set.

**File:** vite.config.js

**Remediation:** Add security headers plugin to vite.config.js. For development, use `crossOriginEmbedderPolicy: false`, `contentSecurityPolicy: false`. For production, configure proper CSP.

---

## 1.3 Input Validation & Sanitization

### Finding: Potential XSS via Unsafe HTML Injection
**Severity:** Medium  
**Category:** input

**Description:** Multiple template strings insert unsanitized response data directly into HTML using jQuery. For example, construkted_ajax.ts:141 inserts response.data into img src without sanitization.

**File:** construkted_ajax.ts:141

**Remediation:** Sanitize all dynamic content before HTML insertion using a sanitizer library. Use textContent instead of innerHTML where possible, or encode HTML entities.

### Finding: Unsafe JSON Parsing Without Error Handling
**Severity:** Medium  
**Category:** input

**Description:** parseAjax.ts:6 uses JSON.parse() directly without try-catch. Malformed JSON will cause uncaught exceptions.

**File:** parseAjax.ts:6, index.ts:119, index.ts:128-130

**Remediation:** Wrap JSON.parse() in try-catch blocks with proper error handling and user-friendly error messages.

---

## 1.4 Code Security

### Finding: Sensitive Data Logging in Development
**Severity:** Low  
**Category:** code

**Description:** index.ts:299-303, 330 logs window.CONSTRUKTED_AJAX which may contain sensitive data like post_id and potentially access tokens to browser console.

**File:** index.ts:299-303, 330

**Remediation:** Remove console.log statements that output sensitive configuration data, or wrap them in environment checks for production builds.

### Finding: Hardcoded Localhost URL
**Severity:** Low  
**Category:** code

**Description:** fetchLocalData.ts:1 hardcodes 'http://localhost:1218' which exposes development server intent.

**File:** fetchLocalData.ts:1

**Remediation:** Move the server URL to environment configuration and only enable local server fetching in development mode.

---

# Part 2: construkted_reality_v1.x Repository

## 2.1 Authentication & Authorization

### Finding: REST API Endpoints Allow Unauthenticated Access
**Severity:** Critical  
**Category:** auth

**Description:** All REST API routes in class.api.php (lines 72-99) have permission_callback that returns true, allowing unauthenticated access to asset data. Endpoints: getAssets, getAsset, getTilesets, addAsset expose sensitive data and functionality.

**File:** wp-content/themes/gowatch-child/includes/class.api.php:72-99

**Remediation:** Implement proper authentication in permission_callback. Check if user is authenticated or has valid API key before returning true.

### Finding: Unauthenticated AJAX Endpoints with Sensitive Operations
**Severity:** Critical  
**Category:** auth

**Description:** Multiple AJAX handlers are registered with both wp_ajax_ and wp_ajax_nopriv_ hooks allowing unauthenticated access to sensitive operations including: ck_get_slug_list, submit_asset_globe_display_status, remove_asset_from_globe, and various viewer state setters.

**File:** wp-content/themes/gowatch-child/includes/ajax.php:731,444,464

**Remediation:** Remove wp_ajax_nopriv_ hook registrations for sensitive operations. Only allow unauthenticated access for read-only public data operations.

### Finding: Missing Capability Checks in Data Modification Operations
**Severity:** High  
**Category:** auth

**Description:** Several AJAX handlers like handle_save_project_details check ownership but many others like set_bg_color allow any authenticated user to modify any post's metadata without authorization verification.

**File:** wp-content/themes/gowatch-child/includes/ajax.php:385-390

**Remediation:** Add current_user_can() checks or ownership verification before allowing post modifications.

### Finding: Insecure Direct Object References in API
**Severity:** Low  
**Category:** auth

**Description:** get_asset endpoint uses the post_author check but doesn't verify if the asset should be visible to the API key owner. An API key holder could potentially access assets they don't own.

**File:** wp-content/themes/gowatch-child/includes/class.api.php:331-335

**Remediation:** Add explicit authorization check to verify API key owner is the post author before returning asset data.

---

## 2.2 Input Validation

### Finding: Direct use of Unvalidated Input in Critical Operations
**Severity:** Critical  
**Category:** input

**Description:** File publish_asset_api.php (line 18-19) directly uses $_REQUEST['post_id'] without sanitization before critical operations like wp_publish_post(). Multiple instances of direct $_REQUEST access without validation.

**File:** wp-content/themes/gowatch-child/publish_asset_api.php:18-19

**Remediation:** Use `absint()` for post IDs: `$post_id = absint($_REQUEST['post_id']);` Add existence checks and permission verification before any operations.

### Finding: Inconsistent Input Sanitization in AJAX Handlers
**Severity:** High  
**Category:** input

**Description:** Multiple AJAX handlers use mixed sanitization approaches. Some use intval() while others use direct $_POST access without sanitization. Example: set_asset_ignore_original_transform uses $_REQUEST directly without sanitization.

**File:** wp-content/themes/gowatch-child/includes/ajax.php:367-368

**Remediation:** Establish consistent sanitization pattern using absint() for IDs, sanitize_text_field() for text, sanitize_textarea_field() for descriptions, and wp_kses_post() for HTML content.

### Finding: Potential SQL Injection in Meta Queries
**Severity:** Medium  
**Category:** input

**Description:** functions.php uses LIKE queries with user-generated data (lines 354-364) without proper escaping. The meta_query pattern with LIKE could be vulnerable to SQL injection.

**File:** wp-content/themes/gowatch-child/functions.php:354-364

**Remediation:** Use prepare() for database queries or ensure all meta_query values are properly sanitized before use.

---

## 2.3 Secrets Management

### Finding: Weak API Key Generation
**Severity:** High  
**Category:** secrets

**Description:** API keys are generated using `md5(uniqid(rand(), true))` (class.api.php line 549). This creates predictable keys. S3 credentials are retrieved from database options and output to JavaScript.

**File:** wp-content/themes/gowatch-child/includes/class.api.php:549

**Remediation:** Use `wp_generate_password()` or `random_bytes()/bin2hex()` for cryptographically secure key generation.

### Finding: Sensitive Tokens Exposed to Client-Side JavaScript
**Severity:** Medium  
**Category:** secrets

**Description:** Cesium access token is output directly to JavaScript (functions.php lines 370-392) and visible in page source.

**File:** wp-content/themes/gowatch-child/includes/functions.php:370-392

**Remediation:** Restrict token permissions to minimum required. Consider server-side rendering of Cesium assets rather than client-side tokens.

---

## 2.4 Security Headers

### Finding: Wildcard CORS Policy Exposes Sensitive API
**Severity:** Critical  
**Category:** headers

**Description:** publish_asset_api.php sets `Access-Control-Allow-Origin: *` (line 12) allowing any origin to access this internal API endpoint performing sensitive operations like publishing posts.

**File:** wp-content/themes/gowatch-child/publish_asset_api.php:12

**Remediation:** Remove wildcard CORS header or restrict to specific trusted origins.

### Finding: Missing Security Headers in Custom API
**Severity:** Low  
**Category:** headers

**Description:** Custom API endpoints like publish_asset_api.php don't set common security headers (X-Content-Type-Options, X-Frame-Options, CSP).

**File:** wp-content/themes/gowatch-child/publish_asset_api.php:8-12

**Remediation:** Add security headers:
```php
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
```

---

## 2.5 Code Security

### Finding: Missing ABSPATH Protection in Template Files
**Severity:** High  
**Category:** code

**Description:** Template files like publish_asset_api.php and delete_attachment_api.php lack ABSPATH check at the beginning. Any direct access could execute code outside WordPress context.

**File:** wp-content/themes/gowatch-child/publish_asset_api.php:1

**Remediation:** Add ABSPATH check at start of all PHP files:
```php
if (!defined('ABSPATH')) { die('Direct access forbidden'); }
```

### Finding: Hardcoded Email Addresses in Production Code
**Severity:** Medium  
**Category:** code

**Description:** Hardcoded email addresses used for notifications: info@construkted.com and wugis1219@gmail.com.

**File:** wp-content/themes/gowatch-child/includes/ajax.php:36,41

**Remediation:** Move email addresses to WordPress options or configuration. Use `get_option('admin_email')` for admin notifications.

---

# Priority Remediation Checklist

## Critical Priority (Immediate)
- [ ] Add authentication to REST API endpoints in class.api.php
- [ ] Remove unauthenticated wp_ajax_nopriv_ hooks for sensitive operations
- [ ] Sanitize all $_REQUEST/$_POST input before use
- [ ] Remove wildcard CORS header from publish_asset_api.php
- [ ] Add ABSPATH protection to all direct-access PHP files

## High Priority (This Week)
- [ ] Run npm audit fix to update vulnerable dependencies
- [ ] Restrict CORS configuration to specific origins
- [ ] Add current_user_can() checks for data modification operations
- [ ] Implement cryptographically secure API key generation
- [ ] Standardize input sanitization across all AJAX handlers

## Medium Priority (This Month)
- [ ] Implement output encoding for dynamic HTML injection
- [ ] Add try-catch for JSON parsing operations
- [ ] Remove sensitive data from client-side logging
- [ ] Restrict Cesium token exposure
- [ ] Add security headers to API responses
- [ ] Move hardcoded values to configuration

## Low Priority (Next Quarter)
- [ ] Configure CSP headers for production builds
- [ ] Move hardcoded URLs to environment configuration
- [ ] Add proper authorization for asset access
- [ ] Review and update any deprecated security patterns

---

# Recommendations

1. **Authentication Layer:** The WordPress REST API and AJAX endpoints require a proper authentication layer. Consider implementing JWT-based authentication or WordPress nonces for API key validation.

2. **Input Sanitization Standard:** Establish a coding standard for input sanitization across the codebase:
   - Post IDs: `absint()`
   - Text: `sanitize_text_field()`
   - Textarea: `sanitize_textarea_field()`
   - HTML content: `wp_kses_post()`
   - Database queries: `$wpdb->prepare()`

3. **Security Headers:** Implement a consistent security header strategy across both frontend and WordPress theme.

4. **Dependency Management:** Establish a schedule for regular dependency updates and security audits.

5. **Secrets Management:** Move all sensitive tokens and credentials to environment variables or WordPress options, never expose to client-side JavaScript.