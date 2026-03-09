# gowatch Theme Migration Plan

## Executive Summary

**Current State:**
- **Parent theme (gowatch):** 20MB, 106 PHP files, heavily bloated with legacy features
- **Child theme (gowatch-child):** 72MB, 248 PHP files (active development)
- **Dependencies:** 70+ `airkit_*` functions, `tszf_` frontend submission system, CSS/JS from parent

**Goal:** Create a standalone clean theme that eliminates dependencies on bloated parent while preserving all functionality.

**Timeline Estimate:** 4-6 weeks (depending on resource allocation)

---

## Phase 1: Analysis & Preparation (Week 1)

### 1.1 Dependency Audit

**Objective:** Document all parent theme dependencies to create accurate migration roadmap.

**Critical Findings:**
- **70+ airkit_* functions** used throughout child theme
- **3 tszf_* functions** for frontend submission
- **CSS dependencies:** `gowatch-style`, `gowatch-bootstrap`, `gowatch-widgets`
- **JS dependencies:** Minimal (most is custom in child)
- **3 get_template_directory_uri()** references to parent

**Output:** `dependency-map.json`

### 1.2 Functional Mapping

**Core Child Components to Preserve:**

1. **CesiumJS Integration** (`construkted/`)
   - 3D viewer with 4 modes (AssetViewer, AssetExplorer, AssetExplorerV2, FrontendSubmission)
   - 40,000+ lines of JavaScript
   - **Zero WordPress dependencies** - pure JS

2. **REST API** (`class.api.php`) - 982 lines
   - 10 endpoints: getAssets, getAsset, getTilesets, addAsset, etc.

3. **AJAX Handlers** (`ajax.php`) - 1,482 lines
   - Upload, processing, asset management

4. **Project System** (`class.projects.php`) - 1,884 lines
   - CRUD for projects, collaborators, permissions

5. **Album System** (`class.albums.php`) - 877 lines
   - Asset grouping and organization

6. **Post Meta** (`class.postmeta.php`) - 1,660 lines
   - 15+ custom meta keys for assets

7. **Frontend Submission** (`frontend-submission/`)
   - Custom upload handler (replaces tszf)

8. **Admin Panel** (`admin/`)
   - Dashboard, monitoring, asset management

---

## Phase 2: Standalone Foundation (Week 1-2)

### 2.1 Create New Theme Skeleton

**Structure:**
```
construkted-theme/
├── style.css              # Theme declaration (NO Template: gowatch)
├── functions.php          # Main entry point (no parent requires)
├── index.php              # Basic fallback
├── header.php             # Custom (replace airkit_header_and_footer)
├── footer.php             # Custom
├── screenshot.png         # 1200x900px
├── includes/
│   ├── constants.php      # All constants
│   ├── functions.php     # Helper functions
│   ├── class.loader.php  # Autoloader
│   ├── class.api.php     # REST API (copy from child)
│   ├── class.projects.php
│   ├── class.albums.php
│   ├── class.postmeta.php
│   ├── ajax.php          # AJAX handlers
│   ├── admin/           # Admin panel
│   ├── construkted/     # CesiumJS integration
│   └── frontend-submission/
├── templates/           # Custom templates
├── woocommerce/        # WooCommerce overrides
├── assets/
│   ├── js/             # Custom JS
│   ├── css/           # Custom CSS (minimal)
│   └── font/          # Icons (gw3icons, ngmIcons)
└── images/
```

### 2.2 Replicate Core Theme Functions

**Critical `airkit_*` Functions to Reimplement:**

**Priority 1 - Used Everywhere:**
- `airkit_rand_string()` - Random string generator
- `airkit_get_logo()` - Logo retrieval
- `airkit_breadcrumbs()` - Breadcrumb navigation
- `airkit_option_value()` - Theme options (**CRITICAL** - create CK_Options)
- `airkit_no_results()` - Empty state component
- `airkit_featured_image()` - Image with options
- `airkit_entry_content()` - Content display
- `airkit_excerpt()` - Excerpt generation

**Priority 2 - Layout System:**
- `airkit_Compilator` class - **5,677 lines in parent** - this is the BIGGEST dependency
  - Options: Reimplement minimal needed version OR build custom solution
  - **Recommendation:** Build custom lightweight layout system

**Priority 3 - UI Components:**
- `airkit_icon()` - Icon display
- `airkit_sharing()` - Social sharing
- `airkit_sidebar()` - Sidebar rendering
- `airkit_banner()` - Banner display

### 2.3 CSS/JS Dependency Removal

**CSS Strategy:**

Current (from functions.php:113):
```php
wp_enqueue_style('gowatch-child-style', ..., array('gowatch-style', 'gowatch-bootstrap', 'gowatch-widgets'));
```

**Migration:**
1. Extract CSS from parent (~200KB combined)
2. Identify actual CSS dependencies used by child
3. Copy only necessary styles to new theme
4. **Target:** ~100KB total (vs 200KB+ from parent)

**JS Strategy:**
- Core jQuery is bundled with WordPress (no dependency)
- Most JS is custom in child theme
- Remove 3 `get_template_directory_uri()` JS references

---

## Phase 3: Component Migration (Week 2-4)

### 3.1 Migration Order

**Day 1-2:** Constants & Functions Base
- Move all constants to `constants.php`
- Extract helper functions
- Create `CK_Options` class

**Day 3-5:** API & AJAX Layer
- Copy `class.api.php` (no parent dependencies)
- Copy `ajax.php` (no parent dependencies)

**Day 5-10:** Business Logic
- Copy `class.projects.php`
- Copy `class.albums.php`
- Copy `class.postmeta.php`

**Day 10-15:** Frontend Systems
- Copy `frontend-submission/` directory
- Replace `tszf_` functions with custom implementations

### 3.2 Admin Panel Migration

- Copy entire `admin/` directory from child
- Update any `airkit_` function calls to new equivalents
- Replace theme options calls with `CK_Options`

### 3.3 CesiumJS Integration

**Strategy:** Copy entire `construkted/` directory as-is
- CesiumJS has **NO WordPress dependencies**
- It's pure JavaScript
- Only need proper `wp_enqueue_script` handling

---

## Phase 4: Frontend Submission System (Week 3-4)

### 4.1 tszf Replacement

**Current State:**
- Frontend submission uses `tszf_` system
- Child theme already overrides upload script (functions.php:547-572)

**Functions to Replace:**
- `tszf_allowed_extensions()` → `ck_allowed_extensions()`
- `tszf_get_option()` → `ck_get_option()`
- `tszf_dashboard_query` filter → `ck_dashboard_query` filter

**Already Custom (Keep As-Is):**
- `construkted.upload.js` - custom upload handler

---

## Phase 5: Testing & Quality Assurance (Week 4-5)

### 5.1 Test Categories

**Core Functions:**
- [ ] Theme activation, post types registration
- [ ] Custom taxonomies, menus
- [ ] Featured image, custom logo support

**Asset Viewer:**
- [ ] 3D model display (CesiumJS)
- [ ] Point cloud rendering, orthomosaics
- [ ] Annotation display, download

**Project System:**
- [ ] Project CRUD, collaborator management
- [ ] Permission handling, asset association

**User Functions:**
- [ ] Registration/login, profile, dashboard
- [ ] Upload workflow, favorites

**Admin Functions:**
- [ ] Dashboard stats, asset management
- [ ] Processing monitoring, settings

### 5.2 Compatibility Testing

- WordPress 6.4+
- PHP 8.2+ (current uses 8.4)
- MySQL 8.0+
- Apache + Nginx
- WooCommerce, WPML, BuddyPress compatibility

### 5.3 Performance Targets

- Reduce CSS from 200KB+ to <100KB
- Maintain JS performance (CesiumJS is heavy)
- API response under 500ms

---

## Phase 6: Deployment (Week 5-6)

### 6.1 Rollout Strategy

**Option A: Direct Switch (Recommended)**
1. Backup production
2. Activate new theme
3. Test critical paths
4. Rollback if issues

**Option B: Gradual Rollout**
1. Deploy to staging, test thoroughly
2. Switch small percentage of users
3. Monitor errors, gradual increase to 100%

### 6.2 Rollback Plan

- Keep old theme as backup for 30 days
- Document exact rollback steps
- Test rollback before going live

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|---------|------------|
| Layout system breaks | High | Critical | Build custom lightweight layout |
| CesiumJS integration fails | Low | Critical | No WP dependencies; should work |
| Admin panel has issues | Medium | High | Copy as-is, update calls, test |
| Performance regression | Medium | Medium | Optimize CSS, monitor metrics |
| User upload breaks | Medium | High | Already custom; just rehook |
| Plugin conflicts | Low | Low | Test in staging |

---

## Resource Requirements

- **1 Senior PHP/WordPress Developer:** 40-60 hours/week for 4-6 weeks
- **Total:** 160-360 hours
- **1 QA Engineer (part-time):** 20-40 hours for testing

---

## Success Criteria

**Functional:**
- [ ] All current features work identically
- [ ] API endpoints respond correctly
- [ ] CesiumJS viewer functional
- [ ] No parent theme dependencies

**Technical:**
- [ ] CSS reduced from 200KB+ to <100KB
- [ ] No get_template_directory() calls to parent
- [ ] All PHP 8.4 compatible

---

## Key Function Reference

**airkit_* Functions to Reimplement (Priority 1):**
```
airkit_rand_string, airkit_get_logo, airkit_breadcrumbs
airkit_option_value, airkit_no_results, airkit_featured_image
airkit_entry_content, airkit_excerpt
```

**tszf_* Functions to Replace:**
```
tszf_allowed_extensions, tszf_get_option, tszf_dashboard_query
```

---

**Timeline:** 4-6 weeks | **Approach:** Phased migration with thorough testing