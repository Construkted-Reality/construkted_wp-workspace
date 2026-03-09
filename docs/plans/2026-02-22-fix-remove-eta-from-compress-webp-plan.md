---
title: "Remove --eta flag from compress-webp.sh"
type: fix
status: completed
date: 2026-02-22
---

# Remove --eta flag from compress-webp.sh

Remove the `--eta` flag from the `parallel` command in `construkted_api/compress-webp.sh`. The `--eta` option outputs an estimated time of arrival for job completion, which adds unnecessary noise to the script output. The script already tracks and prints its own elapsed time (lines 46-47), making `--eta` redundant.

## Acceptance Criteria

- [x] `--eta` is removed from the `parallel` invocation on line 41 of `compress-webp.sh`
- [x] The rest of the `parallel` command remains unchanged (`--jobs "$(nproc)"` and the function call)
- [x] Script still runs correctly without the flag

## Context

**File:** `construkted_api/compress-webp.sh:41`

**Current line:**

```bash
find "$src_folder" -type f -name '*.png' | parallel --eta --jobs "$(nproc)" convert_to_webp {} "$src_folder" "$dst_folder"
```

**Updated line:**

```bash
find "$src_folder" -type f -name '*.png' | parallel --jobs "$(nproc)" convert_to_webp {} "$src_folder" "$dst_folder"
```

## Sources

- File: `construkted_api/compress-webp.sh:41`
