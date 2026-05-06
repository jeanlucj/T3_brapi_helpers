# T3_brapi_helpers 1.0.0

## BREAKING CHANGES

This is a major release with comprehensive breaking changes to align the entire package with snake_case naming conventions.

### Package Renamed
- **Package name**: `T3BrapiHelpers` → `T3_brapi_helpers`
- Update your code: `library(T3BrapiHelpers)` → `library(T3_brapi_helpers)`
- GitHub Pages URL updated: https://jeanlucj.github.io/T3_brapi_helpers/

### Function Names (All Renamed)
All exported functions now use snake_case:

**Trial/Study Functions:**
- `getAllTrialMetaData()` → `get_all_trial_meta_data()`
- `getTrialMetaDataFromTrialVec()` → `get_trial_meta_data_from_trial_vec()`
- `getTraitsFromSingleTrial()` → `get_traits_from_single_trial()`
- `getTraitsFromTrialVec()` → `get_traits_from_trial_vec()`
- `getLatLongElevFromLocationVec()` → `get_lat_long_elev_from_location_vec()`

**Germplasm Functions:**
- `getGermplasmFromSingleTrial()` → `get_germplasm_from_single_trial()`
- `getGermplasmFromTrialVec()` → `get_germplasm_from_trial_vec()`
- `getGenoProtocolFromSingleGerm()` → `get_geno_protocol_from_single_germ()`
- `getGenoProtocolFromGermVec()` → `get_geno_protocol_from_germ_vec()`
- `getTrialFromSingleGermplasm()` → `get_trial_from_single_germplasm()`
- `getTrialFromGermplasmVec()` → `get_trial_from_germplasm_vec()`

**Compound Functions (already snake_case, no change):**
- `find_other_studies_evaluating_same_germplasm()` ✓
- `make_predictathon_file_structure()` ✓
- `covariance_combiner()` ✓

### Parameter Names
- All function parameters now use snake_case
- `brapiConnection` → `brapi_connection` (affects all functions)

### Migration Guide

**Before (v0.1.33):**
```r
library(T3BrapiHelpers)
conn <- BrAPI::createBrAPIConnection("wheat.triticeaetoolbox.org", is_breedbase = TRUE)
trials <- T3BrapiHelpers::getAllTrialMetaData(conn, "Wheat")
germ <- T3BrapiHelpers::getGermplasmFromSingleTrial("8128", conn)
```

**After (v1.0.0):**
```r
library(T3_brapi_helpers)
conn <- BrAPI::createBrAPIConnection("wheat.triticeaetoolbox.org", is_breedbase = TRUE)
trials <- T3_brapi_helpers::get_all_trial_meta_data(conn, "Wheat")
germ <- T3_brapi_helpers::get_germplasm_from_single_trial("8128", conn)
```

### Internal Changes
- All internal helper functions renamed to snake_case
- All internal variables renamed to snake_case
- Documentation updated throughout
- Added `.lintr` configuration to enforce snake_case going forward

### What Didn't Change
- Function arguments (except names)
- Return values and data structures
- BrAPI API field extraction (still uses camelCase from JSON responses)
- Output data frame columns (already snake_case via `janitor::clean_names()`)

## New Features
- Added `LINTING.md` guide for code style enforcement
- Added `.lintr` configuration file
- Added `lint_check.R` helper script

---

# T3BrapiHelpers 0.1.33 and earlier

Previous versions used camelCase naming conventions. See git history for details.
