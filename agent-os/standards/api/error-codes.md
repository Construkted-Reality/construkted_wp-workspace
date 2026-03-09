# Error Codes

Numeric codes grouped by category. Use `${XXX}` placeholder in adminErrorMsg for dynamic details.

## Code Ranges
| Range | Category |
|-------|----------|
| 100-199 | Download errors |
| 200-299 | Archive extraction |
| 300-399 | Mesh tiling (UltraMesh) |
| 400-499 | 3D Tiles validation |
| 500-599 | Point cloud tiling |
| 600-699 | Imagery/orthomosaic tiling |
| 700-799 | Asset upload to Wasabi |
| 800-899 | Input file operations |
| 900-999 | Cesium Ion REST API |
| 1000+ | WordPress integration |

## Structure
```typescript
{
  code: number,           // Numeric identifier
  adminErrorMsg: string,  // Detailed message (use ${XXX} for dynamic values)
  userErrorMsg: string,   // User-facing message (empty = 'contact support')
  description: string     // Documentation
}
```

## User Message Rules
- Show user message when they can fix it (bad format, missing files)
- Empty userErrorMsg defaults to "contact support@construkted.com"
- Judgment call based on whether message helps user

## Source file
`construkted_api/lib/taskErrorInfos.ts`
