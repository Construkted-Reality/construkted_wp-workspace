# PHP Class Prefixes

All custom PHP classes must use a prefix to avoid WordPress naming conflicts.

## Accepted Prefixes

| Prefix | Usage |
|--------|-------|
| `CK_` | Construkted custom classes (preferred) |
| `construkted_` | Alternative Construkted prefix |
| `airkit_` | Parent theme (gowatch) classes only |
| `TSZF_` | Theme Suite Zero Framework (parent theme forms) |

## Examples

```php
// Correct
class CK_Projects { }
class CK_API { }
class construkted_PostMeta { }

// Wrong - no prefix
class Projects { }
class API { }
```

## Why

Prevents naming conflicts with WordPress core, plugins, and parent theme.
