# Custom Post Types

Post types use lowercase singular names without prefixes.

## Registered Types

| Post Type | Purpose | File |
|-----------|---------|------|
| `project` | Main project container | class.projects.php |
| `annotation` | Annotations within projects | class.projects.php |
| `album` | Photo/media albums | class.albums.php |
| `video` | Asset/video files | parent theme |
| `training_services` | Service offerings | functions.php |
| `scanning_services` | Service offerings | functions.php |

## Registration Pattern

```php
register_post_type('project', [
    'label' => 'Projects',
    'public' => true,
    'show_in_rest' => false,  // Always false
    'supports' => ['title', 'editor', 'thumbnail', 'author'],
]);
```

## Rules

- `show_in_rest` must be `false` — use custom `ck/v1` REST endpoints instead
- Names are lowercase singular (not `projects`, not `ck_project`)
- Register in class constructor via `add_action('init', ...)`
