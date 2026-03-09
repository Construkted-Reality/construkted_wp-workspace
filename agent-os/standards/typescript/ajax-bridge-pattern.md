# AJAX Bridge Pattern

Communication between TypeScript viewer and WordPress backend.

## Global Data Object
WordPress passes data via `window.CONSTRUKTED_AJAX`:
```typescript
const CONSTRUKTED_AJAX = window.CONSTRUKTED_AJAX;
CONSTRUKTED_AJAX.post_id;      // Current post ID
CONSTRUKTED_AJAX.ajaxurl;      // WordPress admin-ajax.php URL
CONSTRUKTED_AJAX.is_owner;     // User permissions
```

## Making AJAX Calls
```typescript
const jQuery = window.jQuery;

jQuery.ajax({
    url: CONSTRUKTED_AJAX.ajaxurl,
    type: 'post',
    data: {
        action: 'action_name',      // WordPress action hook
        post_id: CONSTRUKTED_AJAX.post_id,
        // ... other data
    },
    success: function(response) { },
    error: function() { alert('error'); }
});
```

## Loader UI (optional)
Show loading indicator for user-initiated operations:
```typescript
jQuery('.ck-processing-loader').addClass('shown');  // Show
jQuery('.ck-processing-loader').removeClass('shown'); // Hide
```
Use judgment - not all AJAX calls need visible loading state.

## Update Global After Save
Keep `CONSTRUKTED_AJAX` in sync after successful saves:
```typescript
success: function(response) {
    CONSTRUKTED_AJAX.asset_geo_location = newGeolocation;
}
```
