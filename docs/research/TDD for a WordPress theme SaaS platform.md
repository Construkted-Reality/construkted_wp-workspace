# TDD for a WordPress theme SaaS platform: the complete playbook

**The optimal stack for adding test-driven development to a legacy WordPress child theme in 2025–2026 is PHPUnit 9.6, Brain Monkey 2.7, and the WordPress integration test suite, managed through Composer dev-only dependencies.** This combination supports the dual-track strategy this codebase demands: fast unit tests using Brain Monkey for new and refactored code, and integration tests via `WP_UnitTestCase` for characterizing existing tightly-coupled AJAX handlers. The approach works across DDEV, Local by Flywheel, and XAMPP through environment-variable-driven configuration, and gates deployments through a GitHub Actions CI pipeline with MySQL service containers.

The 177 AJAX handlers represent the highest-risk, highest-value testing target. A phased adoption plan—starting with infrastructure and characterization tests, progressing through the Sprout Method to service class extraction—can deliver meaningful coverage within three months and a full TDD culture within six to twelve. What follows is every piece needed to execute this plan.

---

## The right framework stack for WordPress testing in 2026

WordPress core's test suite currently supports **PHPUnit 8 and 9** using the Yoast PHPUnit Polyfills package. PHPUnit 10/11/12 compatibility remains in progress (WordPress Trac #62004), making **PHPUnit 9.6** the clear choice. Every mocking library in the WordPress ecosystem supports it, and it's what WordPress core itself tests against.

For mocking WordPress functions without loading WordPress, **Brain Monkey 2.7** (released February 2026) is the recommended library over WP_Mock 1.1.0. Brain Monkey auto-stubs common WordPress functions (translation, escaping, hook API), uses standard PHPUnit `TestCase` rather than a custom base class, and is recommended by Yoast's engineering team. WP_Mock, maintained by 10up/GoDaddy, remains viable but is locked to PHPUnit 9.x and requires its own bootstrap and base class.

| Tool | Version | Purpose | PHP requirement |
|------|---------|---------|-----------------|
| PHPUnit | **^9.6** | Test runner | ≥7.3 |
| Brain Monkey | **^2.7** | WordPress function/hook mocking | ≥7.2 |
| Mockery | **^1.6** | Object mocking (Brain Monkey dependency) | ≥7.3 |
| wp-phpunit | **^6.9** | WordPress integration test library via Composer | — |
| Yoast PHPUnit Polyfills | **^3.0** | Cross-version PHPUnit compatibility | ≥7.0 |

**Pest PHP is not viable** for this project. Pest v4.0 requires PHP 8.3+, and even Pest v2 requires PHP 8.1+. The WordPress Pest ecosystem remains in alpha. **Codeception/wp-browser** (v4.5.15, actively maintained) is excellent but requires PHP 8.0+ and adds heavyweight dependencies inappropriate for a team starting from zero tests.

A critical note on PHP versions: although the codebase targets **PHP 7.1+ compatibility**, tests should run on **PHP 7.4 or 8.x**. PHPUnit 9 requires PHP 7.3+, and Mockery 1.6 requires PHP 7.3+. This is standard practice—WordPress core writes PHP 7.2-compatible code but runs its test suite on modern PHP. Use PHPStan or PHP_CodeSniffer with the PHPCompatibility standard to enforce that production code avoids features unavailable in PHP 7.1.

---

## Composer strategy that keeps production clean

Since the theme has zero production Composer dependencies (dompdf is manually vendored), the `require` section stays empty. All test tooling lives exclusively in `require-dev`, meaning the `vendor/` directory is purely a development artifact that never touches production servers.

```json
{
    "name": "construkted/gowatch-child",
    "description": "Construkted Reality WordPress child theme",
    "type": "wordpress-theme",
    "require": {},
    "require-dev": {
        "phpunit/phpunit": "^9.6",
        "brain/monkey": "^2.7",
        "yoast/phpunit-polyfills": "^3.0",
        "wp-phpunit/wp-phpunit": "^6.9"
    },
    "autoload-dev": {
        "psr-4": {
            "CK\\Tests\\": "tests/"
        }
    },
    "scripts": {
        "test": "phpunit --testdox",
        "test:unit": "phpunit --testsuite unit --testdox",
        "test:integration": "phpunit --testsuite integration --testdox"
    }
}
```

Mockery is pulled automatically as a transitive dependency of Brain Monkey—no explicit require needed.

**The vendored dompdf conflict**: if dompdf currently lives in a `vendor/` directory at the theme root, move it to `lib/dompdf/` and update the `require_once` path. This lets Composer own `vendor/` exclusively. The `.gitignore` should include:

```gitignore
/vendor/
composer.lock
/.phpunit.cache/
tests/.phpunit.result.cache
```

**Deployment impact is zero.** Since `require` is empty, there's nothing to install in production. The existing GitHub Actions SSH deploy continues unchanged—it deploys theme files, and `vendor/` is gitignored. No `composer install --no-dev` step needed because there are no production Composer packages.

---

## Project structure and bootstrap for a child theme

The test infrastructure lives inside the theme directory, following the pattern established by WP-CLI's `wp scaffold theme-tests` command:

```
gowatch-child/                     ← Repo root
├── composer.json
├── phpunit.xml.dist
├── bin/
│   └── install-wp-tests.sh        ← Downloads WP core + test library
├── tests/
│   ├── bootstrap.php              ← Integration test bootstrap (loads WP)
│   ├── bootstrap-unit.php         ← Unit test bootstrap (no WP needed)
│   ├── unit/
│   │   ├── FunctionsTest.php
│   │   └── ProjectServiceTest.php
│   └── integration/
│       ├── AjaxSaveProjectTest.php
│       ├── RestApiGetAssetsTest.php
│       └── CptRegistrationTest.php
├── includes/
│   ├── ajax.php
│   ├── class.api.php
│   ├── functions.php
│   └── constants.php
├── lib/
│   └── dompdf/                    ← Vendored production library
├── style.css
└── functions.php
```

The **integration test bootstrap** handles the critical child-theme-specific setup. The WordPress test suite downloads to `/tmp/`, completely separate from the theme code. The bootstrap tells WordPress which themes to activate by filtering `pre_option_template` (parent theme) and `pre_option_stylesheet` (child theme):

```php
<?php
// tests/bootstrap.php — Integration test bootstrap
$_composer_autoload = dirname(__DIR__) . '/vendor/autoload.php';
if (file_exists($_composer_autoload)) {
    require_once $_composer_autoload;
}

$_tests_dir = getenv('WP_TESTS_DIR') ?: rtrim(sys_get_temp_dir(), '/\\') . '/wordpress-tests-lib';

if (!file_exists("{$_tests_dir}/includes/functions.php")) {
    echo "Could not find {$_tests_dir}/includes/functions.php — run bin/install-wp-tests.sh first.\n";
    exit(1);
}

require_once "{$_tests_dir}/includes/functions.php";

function _register_theme() {
    $child_theme_dir  = dirname(__DIR__);
    $child_theme_slug = basename($child_theme_dir);
    $theme_root       = dirname($child_theme_dir);
    $parent_theme_slug = 'flavor'; // goWatch parent directory name

    register_theme_directory($theme_root);

    add_filter('pre_option_template', function () use ($parent_theme_slug) {
        return $parent_theme_slug;
    });
    add_filter('pre_option_stylesheet', function () use ($child_theme_slug) {
        return $child_theme_slug;
    });
}
tests_add_filter('muplugins_loaded', '_register_theme');

require "{$_tests_dir}/includes/bootstrap.php";
```

The **unit test bootstrap** is far simpler—it loads only Composer's autoloader and Brain Monkey, with no WordPress dependency:

```php
<?php
// tests/bootstrap-unit.php — Unit test bootstrap (no WP, no DB)
require_once dirname(__DIR__) . '/vendor/autoload.php';

// Define constants that production code expects
if (!defined('META_KEY_PROJECT_TITLE')) {
    require_once dirname(__DIR__) . '/includes/constants.php';
}
```

The **PHPUnit configuration** defines both test suites so developers can run them independently:

```xml
<?xml version="1.0"?>
<phpunit
    bootstrap="tests/bootstrap.php"
    backupGlobals="false"
    colors="true"
    convertErrorsToExceptions="true"
    convertNoticesToExceptions="true"
    convertWarningsToExceptions="true"
>
    <testsuites>
        <testsuite name="unit">
            <directory suffix="Test.php">./tests/unit</directory>
        </testsuite>
        <testsuite name="integration">
            <directory suffix="Test.php">./tests/integration</directory>
        </testsuite>
    </testsuites>
    <groups>
        <exclude>
            <group>ajax</group>
        </exclude>
    </groups>
</phpunit>
```

The `ajax` group exclusion keeps slow AJAX tests out of the default run. Execute them explicitly with `vendor/bin/phpunit --group ajax`.

---

## Testing the 177 AJAX handlers: two complementary approaches

AJAX handler testing is the highest-value target and warrants both integration and unit test approaches, applied at different phases of adoption.

### Integration approach with WP_Ajax_UnitTestCase

WordPress core provides `WP_Ajax_UnitTestCase`, a specialized base class that intercepts `wp_die()` calls (which `wp_send_json_success()` and `wp_send_json_error()` trigger internally) and captures the response. The pattern uses exception catching—`WPAjaxDieStopException` fires when the handler produces output, and `WPAjaxDieContinueException` fires when it dies without output.

```php
<?php
/**
 * @group ajax
 */
class Test_Ajax_Save_Project extends WP_Ajax_UnitTestCase {

    public function test_save_project_success() {
        // Create user and set as current
        $admin_id = self::factory()->user->create(['role' => 'administrator']);
        wp_set_current_user($admin_id);

        // Create a project post to update
        $project_id = self::factory()->post->create([
            'post_type'   => 'project',
            'post_author' => $admin_id,
        ]);

        // Set POST data with valid nonce
        $_POST['_wpnonce'] = wp_create_nonce('save_project');
        $_POST['post_id']  = $project_id;
        $_POST['title']    = 'Updated Project Title';

        // Trigger the AJAX handler
        try {
            $this->_handleAjax('ck_save_project');
        } catch (WPAjaxDieStopException $e) {
            // Expected — wp_send_json_* calls wp_die()
        }

        // Parse and assert on the captured response
        $response = json_decode($this->_last_response);
        $this->assertTrue($response->success);
        $this->assertEquals($project_id, $response->data->post_id);

        // Verify the meta was actually saved
        $this->assertEquals(
            'Updated Project Title',
            get_post_meta($project_id, META_KEY_PROJECT_TITLE, true)
        );
    }

    public function test_save_project_rejects_bad_nonce() {
        $admin_id = self::factory()->user->create(['role' => 'administrator']);
        wp_set_current_user($admin_id);

        $_POST['_wpnonce'] = 'invalid_nonce';
        $_POST['post_id']  = 1;
        $_POST['title']    = 'Anything';

        try {
            $this->_handleAjax('ck_save_project');
        } catch (WPAjaxDieStopException $e) {
            // Nonce failure sends -1
        }

        $this->assertTrue(str_contains($this->_last_response, '-1'));
    }

    public function test_save_project_rejects_subscriber() {
        $subscriber_id = self::factory()->user->create(['role' => 'subscriber']);
        wp_set_current_user($subscriber_id);

        $_POST['_wpnonce'] = wp_create_nonce('save_project');
        $_POST['post_id']  = 1;
        $_POST['title']    = 'Anything';

        try {
            $this->_handleAjax('ck_save_project');
        } catch (WPAjaxDieStopException $e) {}

        $response = json_decode($this->_last_response);
        $this->assertFalse($response->success);
    }
}
```

**Key details**: `$this->_last_response` contains the raw output. `self::factory()->user->create()` and `self::factory()->post->create()` build test fixtures. All data is automatically rolled back via MySQL transactions after each test. Use `set_up()` and `tear_down()` (snake_case) since WordPress 5.9+.

### Unit approach with Brain Monkey

For faster feedback and testing refactored code, Brain Monkey mocks every WordPress function without loading WordPress:

```php
<?php
use PHPUnit\Framework\TestCase;
use function Brain\Monkey\setUp;
use function Brain\Monkey\tearDown;
use function Brain\Monkey\Functions\expect;
use function Brain\Monkey\Functions\stubs;

class Test_Ajax_BrainMonkey extends TestCase {

    protected function setUp(): void {
        parent::setUp();
        $_POST = [];
        setUp();
    }

    protected function tearDown(): void {
        tearDown();
        parent::tearDown();
    }

    public function test_save_project_calls_update_meta() {
        $_POST['post_id'] = 42;
        $_POST['title']   = 'New Title';

        expect('check_ajax_referer')->with('save_project', 'nonce')->once();
        expect('current_user_can')->with('edit_posts')->once()->andReturn(true);
        stubs(['sanitize_text_field', 'wp_unslash']);
        expect('update_post_meta')->with(42, META_KEY_PROJECT_TITLE, 'New Title')->once();
        expect('get_post_meta')->with(42, META_KEY_PROJECT_STATUS, true)->andReturn('draft');
        expect('wp_send_json_success')->once();

        // Call the handler function directly
        handle_save_project();
    }
}
```

Brain Monkey's `stubs()` function auto-returns the first argument, perfect for WordPress sanitization and escaping functions. The `expect()` function sets both mock behavior and assertions simultaneously.

---

## Testing REST API endpoints and mocking HTTP calls

REST API endpoint tests use `WP_REST_Server` to dispatch requests internally—no HTTP requests leave the process. The pattern initializes the server in `set_up()`, creates `WP_REST_Request` objects, and asserts on the `WP_REST_Response`:

```php
<?php
class Test_CK_REST_API extends WP_UnitTestCase {

    protected $server;
    protected static $admin_id;

    public static function wpSetUpBeforeClass($factory) {
        self::$admin_id = $factory->user->create(['role' => 'administrator']);
    }

    public function set_up() {
        parent::set_up();
        global $wp_rest_server;
        $this->server = $wp_rest_server = new WP_REST_Server();
        do_action('rest_api_init');
    }

    public function test_get_assets_returns_published_assets() {
        wp_set_current_user(self::$admin_id);

        self::factory()->post->create(['post_type' => 'video', 'post_status' => 'publish']);

        $request  = new WP_REST_Request('GET', '/ck/v1/getAssets');
        $response = $this->server->dispatch($request);

        $this->assertEquals(200, $response->get_status());
        $this->assertNotEmpty($response->get_data());
    }

    public function test_api_key_authentication() {
        wp_set_current_user(0); // Not logged in
        update_option('ck_api_keys', ['valid_key_123' => ['user_id' => self::$admin_id]]);

        $request = new WP_REST_Request('GET', '/ck/v1/getAsset/1');
        $request->set_header('X-API-Key', 'valid_key_123');

        $response = $this->server->dispatch($request);
        $this->assertEquals(200, $response->get_status());
    }
}
```

**Mocking external HTTP calls** to Wasabi S3 and the tile processing API uses the `pre_http_request` filter, which WordPress fires before every outgoing HTTP request. Returning a non-false value short-circuits the actual request:

```php
public function test_s3_presigned_url_generation() {
    add_filter('pre_http_request', function ($preempt, $args, $url) {
        if (strpos($url, 'wasabisys.com') === false) {
            return $preempt;
        }
        return [
            'response' => ['code' => 200, 'message' => 'OK'],
            'body'     => json_encode(['url' => 'https://bucket.wasabi.com/signed-url']),
            'headers'  => [],
            'cookies'  => [],
        ];
    }, 10, 3);

    $result = ck_generate_presigned_url('test-file.obj');
    $this->assertStringContainsString('signed-url', $result);
}

public function test_handles_s3_network_failure() {
    add_filter('pre_http_request', function () {
        return new WP_Error('http_request_failed', 'Connection timed out');
    });

    $result = ck_generate_presigned_url('test-file.obj');
    $this->assertFalse($result);
}
```

---

## Making tests work across DDEV, Local by Flywheel, and XAMPP

The three environments differ fundamentally in how they expose PHP and MySQL. The solution is **environment-variable-driven configuration** with per-environment `.env` files (gitignored).

| Aspect | DDEV | Local by Flywheel | XAMPP |
|--------|------|-------------------|-------|
| Run tests | `ddev exec vendor/bin/phpunit` | Open Site Shell → `vendor/bin/phpunit` | `vendor/bin/phpunit` directly |
| DB host | `db` (inside container) | `localhost:/path/to/mysqld.sock` | `localhost` |
| DB user/pass | `db`/`db` | `root`/`root` | `root`/`""` |
| Install WP tests | `ddev exec bash bin/install-wp-tests.sh wordpress_test db db db latest` | `bash bin/install-wp-tests.sh wordpress_test root root localhost latest` | `bash bin/install-wp-tests.sh wordpress_test root "" localhost latest` |

The `wp-tests-config.php` (generated by `install-wp-tests.sh`) normally hardcodes database credentials. Override this by having the bootstrap read environment variables with sensible defaults:

```php
// In tests/bootstrap.php, before requiring WP test includes:
// Environment variables override defaults for cross-environment compat.
// Set via .env file, phpunit.xml <php><env> blocks, or shell exports.
```

In `phpunit.xml.dist`, provide fallback values that work in CI:

```xml
<php>
    <env name="WP_TEST_DB_NAME" value="wordpress_test" force="false"/>
    <env name="WP_TEST_DB_USER" value="root" force="false"/>
    <env name="WP_TEST_DB_PASSWORD" value="" force="false"/>
    <env name="WP_TEST_DB_HOST" value="localhost" force="false"/>
</php>
```

The `force="false"` attribute means environment variables from the shell take precedence—each developer's local `.env` or shell exports override the defaults without touching version-controlled files.

**Practical recommendation**: prioritize Brain Monkey unit tests, which run identically across all three environments with zero environment-specific configuration (no database, no WordPress). Integration tests require one-time local setup per developer, documented in a `TESTING.md` file. If a developer cannot get integration tests running locally, they can run unit tests locally and rely on CI for integration validation.

Use Composer scripts as the universal interface: `composer test` works everywhere. In DDEV, prefix with `ddev`: `ddev composer test`. This is the only environment-specific difference.

---

## GitHub Actions CI pipeline that gates deployments

The CI workflow uses a MySQL service container, downloads the WordPress test suite, and runs PHPUnit as a gate before deployment:

```yaml
name: Tests
on:
  push:
    branches: [main, staging, develop]
  pull_request:
    branches: [main]

jobs:
  phpunit:
    name: PHPUnit (PHP ${{ matrix.php }})
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        php: ['8.0', '8.1', '8.2']

    services:
      mysql:
        image: mariadb:latest
        ports: ['3306:3306']
        env:
          MYSQL_ROOT_PASSWORD: root
          MYSQL_DATABASE: wordpress_test
        options: >-
          --health-cmd="mysqladmin ping -h 127.0.0.1 --silent"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=3

    steps:
      - uses: actions/checkout@v4

      - uses: shivammathur/setup-php@v2
        with:
          php-version: ${{ matrix.php }}
          extensions: mysqli, mbstring, xml, zip, intl, gd
          coverage: none
          tools: composer:v2

      - name: Cache Composer dependencies
        uses: actions/cache@v4
        with:
          path: ~/.composer/cache
          key: ${{ runner.os }}-composer-${{ hashFiles('composer.lock') }}

      - run: composer install --no-progress --prefer-dist

      - name: Install WordPress test suite
        run: bash bin/install-wp-tests.sh wordpress_test root root 127.0.0.1 latest true

      - name: Set up parent theme
        run: |
          mkdir -p /tmp/wordpress/wp-content/themes/
          # Download commercial parent theme from private artifact
          # git clone https://${{ secrets.THEME_TOKEN }}@github.com/org/flavor.git \
          #   /tmp/wordpress/wp-content/themes/flavor
          ln -s ${{ github.workspace }} /tmp/wordpress/wp-content/themes/gowatch-child

      - run: vendor/bin/phpunit --testdox

  deploy-staging:
    needs: phpunit
    if: github.ref == 'refs/heads/staging' && github.event_name == 'push'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.STAGING_HOST }}
          username: ${{ secrets.DEPLOY_USER }}
          key: ${{ secrets.DEPLOY_KEY }}
          script: cd /var/www/html/wp-content/themes/gowatch-child && git pull origin staging
```

The parent theme—a commercial product not in the repo—must be made available in CI. Store it as a GitHub release artifact or in a private repo accessed via `secrets.THEME_TOKEN`. The child theme is symlinked into the WordPress test installation's themes directory.

---

## The refactoring pattern: from coupled handlers to testable services

The existing AJAX handlers mix input validation, authorization, business logic, database access, and HTTP response formatting in a single function. The target architecture separates these into a thin AJAX controller, a service class containing business logic, and repository classes wrapping WordPress data access.

**Before** — a typical tightly-coupled handler:

```php
function handle_save_asset_details() {
    check_ajax_referer('save_asset', 'nonce');
    if (!current_user_can('edit_posts')) {
        wp_send_json_error('Unauthorized', 403);
    }
    $post_id = intval($_POST['post_id']);
    $title   = sanitize_text_field($_POST['title']);
    update_post_meta($post_id, CK_META_ASSET_TITLE, $title);
    $response = wp_remote_post(PROCESSING_API_URL, ['body' => ['id' => $post_id]]);
    if (is_wp_error($response)) {
        wp_send_json_error('Sync failed');
    }
    wp_send_json_success(['post_id' => $post_id]);
}
add_action('wp_ajax_ck_save_asset_details', 'handle_save_asset_details');
```

**After** — separated concerns:

```php
// Service: pure business logic, injectable dependencies
class AssetService {
    private $meta;
    private $api;

    public function __construct(MetaRepository $meta, ProcessingApiClient $api) {
        $this->meta = $meta;
        $this->api  = $api;
    }

    public function saveDetails(int $post_id, string $title): array {
        if (empty($title)) {
            throw new \InvalidArgumentException('Title required');
        }
        $this->meta->update($post_id, CK_META_ASSET_TITLE, $title);
        $this->api->syncAsset($post_id);
        return ['post_id' => $post_id];
    }
}

// Repository: wraps WordPress data access
class MetaRepository {
    public function get(int $post_id, string $key) {
        return get_post_meta($post_id, $key, true);
    }
    public function update(int $post_id, string $key, $value): bool {
        return (bool) update_post_meta($post_id, $key, $value);
    }
}

// AJAX controller: thin, handles only HTTP concerns
function handle_save_asset_details() {
    check_ajax_referer('save_asset', 'nonce');
    if (!current_user_can('edit_posts')) {
        wp_send_json_error('Unauthorized', 403);
    }
    try {
        $service = new AssetService(new MetaRepository(), new ProcessingApiClient());
        $result  = $service->saveDetails(
            intval($_POST['post_id']),
            sanitize_text_field($_POST['title'])
        );
        wp_send_json_success($result);
    } catch (\Exception $e) {
        wp_send_json_error($e->getMessage(), 500);
    }
}
```

The service class can now be unit-tested with Mockery mocks—**no WordPress, no database, millisecond execution**:

```php
class AssetServiceTest extends TestCase {
    use \Mockery\Adapter\Phpunit\MockeryPHPUnitIntegration;

    public function test_save_details_updates_meta_and_syncs() {
        $meta = Mockery::mock(MetaRepository::class);
        $api  = Mockery::mock(ProcessingApiClient::class);

        $meta->shouldReceive('update')->once()->with(42, CK_META_ASSET_TITLE, 'New Title');
        $api->shouldReceive('syncAsset')->once()->with(42);

        $service = new AssetService($meta, $api);
        $result  = $service->saveDetails(42, 'New Title');

        $this->assertEquals(['post_id' => 42], $result);
    }

    public function test_save_details_rejects_empty_title() {
        $service = new AssetService(
            Mockery::mock(MetaRepository::class),
            Mockery::mock(ProcessingApiClient::class)
        );
        $this->expectException(\InvalidArgumentException::class);
        $service->saveDetails(42, '');
    }
}
```

**Do not refactor first.** Write characterization tests against the existing coupled code using `WP_Ajax_UnitTestCase`, then extract service classes with those integration tests as a safety net. The integration tests verify end-to-end behavior survives the refactoring; the new unit tests verify the extracted logic in isolation.

---

## Handling 304 constants and other WordPress entanglements

PHP `define()` constants **cannot be redefined** once set. For a codebase with 304 constants, the pragmatic approach is threefold:

**Immediate**: load `includes/constants.php` in the test bootstrap. Since constants are typically meta keys and configuration values that don't change between tests, defining them once works fine. Wrap each define in `if (!defined(...))` guards if the constants file doesn't already have them:

```php
// tests/bootstrap-unit.php
if (!defined('CK_META_ASSET_TITLE')) {
    require_once dirname(__DIR__) . '/includes/constants.php';
}
```

**Gradual migration**: as files are touched, migrate from `define('CK_META_ASSET_TITLE', '_asset_title')` to class constants: `class MetaKeys { const ASSET_TITLE = '_asset_title'; }`. Class constants are still not redefinable, but they organize the codebase and signal intent.

**For truly configurable values**: extract into a `Config` class that accepts an array, making tests trivial to inject different values. This applies more to API endpoints or feature flags than to meta key names.

Testing hook registrations is straightforward with Brain Monkey. After calling the registration method, assert with `has_action()`:

```php
public function test_registers_ajax_hooks() {
    $handler = new CK_Projects();
    $handler->register_hooks();

    $this->assertNotFalse(has_action('wp_ajax_ck_save_project'));
    $this->assertNotFalse(has_action('wp_ajax_ck_delete_project'));
}
```

---

## Five-phase adoption plan with concrete milestones

### Phase 1: Infrastructure (days 1–5)

Install Composer dev dependencies. Create `phpunit.xml.dist`, both bootstrap files, the `bin/install-wp-tests.sh` script, and a `TESTING.md` documenting per-environment setup. Write one test—`$this->assertTrue(true)`—and get it passing locally and in GitHub Actions. **Milestone: green CI badge on the first PR.**

### Phase 2: Characterization tests for critical paths (weeks 2–6)

Identify the **10–15 highest-risk AJAX handlers** by business impact: asset save/delete, project permissions, S3 upload orchestration, API key management. Write integration tests using `WP_Ajax_UnitTestCase` covering three scenarios per handler: valid request succeeds, missing nonce is rejected, unauthorized user gets 403. Target **30–50 tests**. Mock external HTTP calls with `pre_http_request`. Write REST API tests for the `ck/v1/` endpoints using `WP_REST_Server::dispatch()`. **Milestone: test suite catches a real bug.**

### Phase 3: New code under test via Sprout Method (weeks 7–12)

Establish the rule: **no new code merges without tests.** All new features use the Sprout Method—new functionality goes into separate, tested service classes called from existing code. Extract the first 3–5 service classes from the simplest AJAX handlers (utility functions, data transformations). Write Brain Monkey unit tests for these. Target **100 tests, 15–20% of handlers have service classes.** **Milestone: first complete handler refactored with before/after tests.**

### Phase 4: Systematic refactoring (months 3–6)

Group related AJAX handlers into domain services: `AssetService`, `ProjectService`, `AnnotationService`, `GlobeService`. Extract `MetaRepository`, `S3Client`, `ProcessingApiClient`. Add tests for CPT registration, shortcodes. Target **300+ tests, 50% of handlers refactored.** **Milestone: developer can confidently modify any covered handler.**

### Phase 5: Full TDD culture (month 6 onward)

All new features written test-first. Remaining handlers get service classes when touched (Boy Scout Rule). Add acceptance tests for critical user flows. **Coverage target: 60–70%**—diminishing returns above this threshold. **Milestone: incoming bug reports get a failing test written before the fix.**

**Timeline reality**: functional test suite in ~3 months, TDD culture in 6–12 months. Total effort for Phase 1 is roughly one focused day.

---

## Honest assessment of what will hurt

**WordPress was never designed for testability.** Global state is everywhere—`global $wpdb`, `$_POST` superglobals, the entire hook system is a global event bus. This is the fundamental friction. Accept it rather than fighting it.

The **`wp_die()`/`exit()` problem** is the most common stumbling block. Every `wp_send_json_*` call terminates the PHP process. `WP_Ajax_UnitTestCase` handles this with custom die handlers and exception catching, but it's counterintuitive. Brain Monkey avoids the problem entirely by mocking `wp_send_json_success` to not actually die.

**Mocking is verbose for tightly-coupled code.** Testing a single existing AJAX handler with Brain Monkey requires mocking 5–10 WordPress functions. This is tedious and makes tests fragile to implementation changes. This is exactly why the strategy is "integration tests first for existing code, unit tests for new/refactored code."

**Integration tests are slow.** The WordPress bootstrap takes **3–8 seconds**, and each `WP_UnitTestCase` test runs in **50–200ms** due to database transactions. A suite of 50 integration tests takes 10–20 seconds. Keep unit tests and integration tests in separate suites and run unit tests first for fast feedback.

The most common failure modes are trying to achieve 100% coverage at once (overwhelming), starting with unit tests on tightly-coupled code (too much mocking), not running tests in CI (tests rot), and making it a solo effort rather than a team commitment. The antidote to all of these is Phase 1: get a single test passing in CI on day one, then grow incrementally.

## Conclusion

The path from zero tests to a TDD workflow on a WordPress child theme is well-trodden, with mature tooling and clear patterns. **PHPUnit 9.6 + Brain Monkey 2.7** is the optimal stack for 2026, supporting both integration tests against real WordPress and fast unit tests against mocked functions. The Composer dev-only strategy adds zero deployment risk. The dual test suite architecture (unit tests for speed, integration tests for confidence) works across all three development environments through environment-variable configuration.

The single most important insight is sequencing: **characterize first, then refactor under test coverage.** Write integration tests against the existing coupled handlers to capture current behavior, then extract service classes with those tests as a safety net. The 177 AJAX handlers are not a wall—they're a prioritized backlog. Start with the 10 that matter most, and let coverage grow outward from there. The infrastructure investment is roughly one day; meaningful coverage takes three months; a TDD culture takes a year. Each phase delivers compounding returns.