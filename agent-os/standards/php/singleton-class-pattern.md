# Singleton Class Pattern

All major PHP classes use singleton pattern with static `get_instance()` factory.

```php
class CK_Example {
    private static $instance;

    public static function get_instance() {
        if (null === self::$instance) {
            self::$instance = new self();
        }
        return self::$instance;
    }

    private function __construct() {
        // Register hooks here
    }
}
```

## Usage

```php
// Correct
$projects = CK_Projects::get_instance();

// Wrong - never instantiate directly
$projects = new CK_Projects();
```

## Why

Legacy pattern maintained for consistency. All classes follow this regardless of whether state sharing is needed.

## Classes using this pattern

- `CK_Projects` - Project/annotation management
- `CK_API` - REST API endpoints
- `CK_Albums` - Album management
- `CONSTRUKTED_Admin` - Admin settings
