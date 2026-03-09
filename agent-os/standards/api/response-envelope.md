# Response Envelope

Two envelope formats are used depending on the endpoint type.

## Backend API (construkted_api)

All Express endpoints use `{errCode, errMsg, ...data}`:

```json
{ "errCode": 0, "errMsg": "success", "taskId": "abc123" }
{ "errCode": 1, "errMsg": "Invalid input", "taskId": null }
```

- `errCode: 0` = success
- `errCode: non-zero` = error
- Use `http.send(res, errCode, errMsg, data)` from `lib/http.ts`

## WordPress AJAX (gowatch-child)

All `wp_ajax_*` handlers use `{status, msg, data}`:

```json
{ "status": 200, "msg": "Key added successfully", "data": {...} }
{ "status": 400, "msg": "Key could not be added" }
```

- `status: 200` = success
- `status: 400` = error
- Use `wp_send_json($response)` to return

## When Parsing Responses

- Backend calling WordPress: check `response.data.errCode === 0`
- WordPress/JS calling backend: check `response.errCode === 0`
- Frontend JS calling WordPress AJAX: check `res.status === 200`
