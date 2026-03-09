# Deep Research Prompt: TDD Best Practices for a WordPress Theme-Based SaaS Platform

## Context

I'm adding a test-driven development workflow to a commercial WordPress child theme that powers a SaaS platform (Construkted Reality — a 3D asset management and viewing platform). There are currently ZERO automated tests. I want to adopt TDD going forward, starting with unit tests and later adding integration tests.

This prompt is specifically about the **WordPress PHP theme layer**. The JavaScript viewer and the Node.js API are covered by separate research prompts.

## Technology Stack (Exact)

- **WordPress**: Classic (non-block) theme, no Gutenberg/block editor
- **Parent theme**: goWatch by TouchSize (commercial theme, Bootstrap 3, jQuery)
- **Child theme**: gowatch-child (the custom code I control)
- **PHP version**: 7.1+ (must support 7.1+ based on dompdf dependency; likely running 8.x in production)
- **No Composer** at the project root — the only composer-managed code is a vendored dompdf library
- **No existing build pipeline** for PHP — no webpack, no Laravel Mix, no PHP-CS-Fixer

### Codebase Characteristics

The child theme contains:

1. **~177 WordPress AJAX action handlers** registered via `wp_ajax_*` hooks in `includes/ajax.php` (1587 lines) and scattered across other files. These handle:
   - Asset management (save/get details, thumbnails, geo-location, processing)
   - Project CRUD (create, update, delete, permissions)
   - Annotation CRUD (create, get, delete, tree operations, comments, attachments)
   - Camera viewpoints (save, get, delete)
   - Globe operations (submit, approve, reject)
   - File upload orchestration (S3 presigned URL generation via Wasabi)
   - API key management

2. **REST API endpoints** under namespace `ck/v1/` defined in `includes/class.api.php` (982 lines):
   - `GET /ck/v1/getAssets`
   - `GET /ck/v1/getAsset/{id}`
   - `GET /ck/v1/getTilesets/{id}`
   - `POST /ck/v1/addAsset`
   - `GET /ck/v1/get_items`
   - `GET /ck/v1/assets/user/{user}`

3. **Custom Post Types**: `project`, `annotation`, `album`, `training_services`, `scanning_services`, plus `video` (from parent theme, used as the main "asset" post type)

4. **PHP classes**:
   - `CK_API` — REST API with API key management
   - `CK_Projects` — Project and annotation CPT registration + AJAX handlers
   - `CK_Albums` — Album CPT
   - `CK_Postmeta` — Post meta management
   - `CK_Compilator` — Template compilation

5. **External service integrations** in PHP:
   - Wasabi S3 (presigned URL generation for file uploads)
   - External tile processing API (version compatibility checks, status callbacks)
   - dompdf (PDF generation from HTML)

6. **WordPress hooks used extensively**: `add_action`, `add_filter`, `wp_ajax_*`, `register_rest_route`, `register_post_type`, `add_shortcode`, `wp_enqueue_script`, CRON scheduling

7. **Large utility functions file**: `includes/functions.php` (~2921 lines) with REST route registrations and helper functions

8. **Constants file**: `includes/constants.php` (304 lines of `define()` calls for meta keys, asset types, coordinate systems)

9. **Frontend template files**: PHP templates for single-project, single-album, globe-page, XR page, forms, sidebars (16 sidebar popup templates)

10. **No autoloading** — files are included manually via `require_once` in `functions.php`

### Deployment

- GitHub Actions SSH deploy to 4 environments (production, staging, dev1, dev2)
- Only the theme directories are version-controlled (WordPress core, plugins, uploads are gitignored)
- The repo does NOT contain a full WordPress installation

## Research Questions

### 1. Test Framework Selection (2025-2026 state of the art)

- What is the current best practice for unit testing WordPress themes/plugins in 2025-2026?
- **PHPUnit** with **WP_UnitTestCase** vs alternatives — what are the tradeoffs?
- Is **Pest PHP** viable for WordPress testing? What about **Codeception**?
- What version of PHPUnit works with current WordPress test suite? (WordPress historically pins PHPUnit versions)
- How does **wp-env** (the official WordPress development environment) compare to **DDEV**, **Lando**, or **Docker-based** test environments for running tests?
- What is the recommended way to set up a test database for WordPress unit tests?

### 2. Testing WordPress AJAX Handlers

This is the highest-priority testing target. With 177 AJAX handlers, I need a practical pattern for testing them.

- What is the best practice for testing `wp_ajax_*` handlers in isolation?
- How do you mock `$_POST`/`$_GET` superglobals, `wp_send_json_success()`/`wp_send_json_error()`, and `wp_die()` in tests?
- How do you handle AJAX handlers that depend on `current_user_can()` and WordPress nonce verification?
- Are there established patterns for testing AJAX handlers that interact with `wp_postmeta`, custom post types, and taxonomy terms?
- How do you test AJAX handlers that make external HTTP calls (e.g., to S3 or a processing API)?

### 3. Testing WordPress REST API Endpoints

- Best practices for testing `register_rest_route` endpoints in WordPress?
- How do you test REST API authentication (API key-based, not cookie-based)?
- How do you use `WP_REST_Request` and `WP_REST_Response` in tests?
- Patterns for testing REST endpoints that read/write postmeta and custom post types?

### 4. Testing Custom Post Types and Meta

- How do you test CPT registration and capabilities?
- Patterns for testing code that heavily uses `get_post_meta()`, `update_post_meta()`, `delete_post_meta()`?
- How do you set up test fixtures for posts, postmeta, users, and taxonomies?
- Does WordPress's test suite provide factory methods for creating test data?

### 5. Project Structure for Tests

- Where should test files live relative to the theme? Inside `wp-content/themes/gowatch-child/tests/`? Or outside the theme directory?
- How do you bootstrap WordPress's test environment for a theme (not a plugin)?
- What does a typical `phpunit.xml` look like for a WordPress theme?
- How do you handle the parent theme dependency in tests (gowatch parent must be active)?
- How do you handle the fact that this repo doesn't include WordPress core?

### 6. TDD Workflow Specifics

- What does a practical TDD red-green-refactor cycle look like for WordPress development?
- How fast should WordPress unit tests run? What's achievable? (The WordPress bootstrap is notoriously slow)
- Strategies for keeping test execution fast when tests need a WordPress database
- How do you run tests locally without a full WordPress installation? (remember: this repo only contains the theme)
- Can tests run in CI (GitHub Actions) without deploying to a WordPress server?

### 7. Testing Code That's Tightly Coupled to WordPress

- The codebase uses WordPress functions everywhere (`get_option`, `get_post`, `get_current_user_id`, `wp_upload_dir`, `wp_remote_get`, etc.). What are the strategies for testing this code?
- Should I refactor business logic out of AJAX handlers into testable service classes? What does that pattern look like in WordPress?
- What's the recommended approach for testing code that uses `define()` constants extensively (304 constants)?
- How do you test shortcode callbacks?
- How do you test `add_action`/`add_filter` hook registrations?

### 8. Mocking and Test Doubles in WordPress

- What mocking libraries work well with WordPress? (Mockery, PHPUnit mocks, Brain Monkey, WP_Mock)
- **Brain Monkey** vs **WP_Mock** — which is current best practice in 2025-2026? Are either of them maintained?
- When should you use WP_UnitTestCase (which loads real WordPress) vs mocking WordPress functions entirely?
- How do you mock `wp_remote_get`/`wp_remote_post` for testing external API calls?

### 9. Gradual Adoption Strategy

- For a codebase with zero tests and 177 AJAX handlers, what's the recommended order of adoption?
- How do you introduce TDD into an existing WordPress theme without rewriting everything?
- What's the minimum viable test infrastructure to get started?
- Which types of code should be tested first for maximum ROI?

### 10. CI/CD Integration

- How do you run PHPUnit WordPress tests in GitHub Actions?
- What GitHub Actions are available for WordPress testing? (wp-env, MySQL service containers, etc.)
- How do you set up a test database in CI?
- What does a practical CI pipeline look like for a WordPress theme with unit tests?

## What I Need From This Research

1. **Specific framework and tool recommendations** with version numbers (not just "use PHPUnit")
2. **Code examples** of test setups, bootstrap files, and actual test cases for WordPress AJAX handlers and REST endpoints
3. **Comparison tables** where multiple options exist (e.g., WP_Mock vs Brain Monkey vs WP_UnitTestCase)
4. **A recommended project structure** for adding tests to an existing WordPress child theme
5. **A phased adoption plan** — what to set up first, what to test first, how to build momentum
6. **Links to authoritative sources** — WordPress developer docs, well-tested open source WordPress plugins/themes I can study, blog posts from recognized WordPress testing experts
7. **Honest assessment of pain points** — what's genuinely hard about WordPress TDD and what the common failure modes are
