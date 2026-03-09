# API Authentication

WordPress REST API (`/ck/v1/*`) uses API key authentication.

## Request Format

Pass the API key in the `X-Api-Key` HTTP header:

```
GET /wp-json/ck/v1/getAssets
X-Api-Key: your-api-key-here
```

## Permission Levels

| Level | Allows |
|-------|--------|
| `read` | View assets (`getAssets`, `getAsset`, `getTilesets`) |
| `write` | Read + create/modify assets (`addAsset`) |

## Key Storage

Keys stored in WordPress user meta `ck_api_keys`:

```php
$keys = get_user_meta($user_id, 'ck_api_keys', true);
// Returns: ['key123' => ['action' => 'read', 'date' => '...', 'description' => '...']]
```

## Key Management

- Users manage keys in their WordPress profile
- Max 50 keys per user
- Keys are MD5 hashes: `md5(uniqid(rand(), true))`

## Validation (PHP)

```php
// Read endpoints
$this->validate_api_key($this->api_key);  // default 'read'

// Write endpoints
$this->validate_api_key($this->api_key, 'write');
```

## WordPress REST Endpoints

| Endpoint | Method | Permission |
|----------|--------|------------|
| `/ck/v1/getAssets` | GET | read |
| `/ck/v1/getAsset/{id}` | GET | read |
| `/ck/v1/getTilesets/{id}` | GET | read |
| `/ck/v1/addAsset` | POST | write |
