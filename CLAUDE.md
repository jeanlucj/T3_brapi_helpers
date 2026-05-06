# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

T3BrapiHelpers is an R package providing helper functions for working with BrAPI (Breeding API) services and The Triticeae Toolbox (T3). The package simplifies querying BrAPI endpoints and transforming responses into tidy data frames for downstream analysis in plant breeding workflows.

## Development Commands

### Package Development
- **Load package for development**: `devtools::load_all()` - loads all functions without installing
- **Generate documentation**: `devtools::document()` - updates .Rd files from roxygen2 comments
- **Check package**: `devtools::check()` - runs R CMD check locally
- **Run tests**: `devtools::test()` - if tests exist (currently no test directory)
- **Install locally**: `devtools::install()` or `pak::pak(".")`
- **Build package**: `R CMD build .` or `devtools::build()`

### Documentation
- Documentation is generated from roxygen2 comments in R files
- Website is built with pkgdown and deployed to https://jeanlucj.github.io/T3BrapiHelpers/
- After changing roxygen2 comments, always run `devtools::document()` to update man/ files

## Architecture

### Core Function Categories

1. **Trial/Study Functions** (`R/brapi_trials.R`)
   - Query trial metadata, traits, and location information
   - Pattern: `get_all_trial_meta_data()`, `get_trial_meta_data_from_trial_vec()`, `get_traits_from_single_trial()`, `get_traits_from_trial_vec()`, `get_lat_long_elev_from_location_vec()`

2. **Germplasm Functions** (`R/brapi_germplasm.R`)
   - Query germplasm (accession) metadata from trials
   - Pattern: `get_germplasm_from_single_trial()`, `get_germplasm_from_trial_vec()`, `get_trial_from_single_germplasm()`, `get_trial_from_germplasm_vec()`

3. **Compound Functions** (`R/compound_functions.R`)
   - Higher-level workflows that combine multiple BrAPI queries
   - `find_other_studies_evaluating_same_germplasm()`: finds trials with common germplasm
   - `make_predictathon_file_structure()`: creates standardized output for T3 Predictathon competitions

4. **Statistical Utilities** (`R/covariance_combiner.R`)
   - EM algorithm for combining partial covariance matrices
   - Used for genomic relationship matrix operations

### Function Naming Patterns

- `get_x_from_y()`: retrieves X for a single Y (e.g., `get_germplasm_from_single_trial()`)
- `get_x_from_y_vec()`: retrieves X for a vector of Y values (e.g., `get_germplasm_from_trial_vec()`)
- `get_all_x()`: retrieves all X for a given crop (e.g., `get_all_trial_meta_data()`)
- Internal helpers: `make_row_from_trial_result()`, `make_row_from_germ_result()` convert BrAPI responses to data.frame rows
- **Naming convention**: All functions use snake_case (changed from camelCase as of May 2026)

### Data Conventions

- **Terminology**: Use "study" in variable names that interact with BrAPI (e.g., `study_id`, `studyDbId`), but use "trial" in plain English contexts and function names
- **Column names**: Use snake_case for data.frame column names (enforced by `janitor::clean_names()`)
- **Dates**: Convert BrAPI date strings to POSIXct with UTC timezone
- **Missing values**: Use `%||%` operator (from BrAPI package presumably) to replace NULL with NA

## Key Dependencies

- **BrAPI**: Must be installed from GitHub (`github::TriticeaeToolbox/BrAPI.R`), not CRAN. All functions expect a `BrAPIConnection` R6 object created by `BrAPI::createBrAPIConnection()`
- **tidyverse packages**: dplyr, purrr, tibble for data manipulation
- **janitor**: For cleaning column names to snake_case
- **httr**: For HTTP POST requests
- **Matrix**: For linear algebra operations in covariance functions

## BrAPI Connection Pattern

All exported functions expect a BrAPI connection object as an argument:

```r
# Create connection
brapi_conn <- BrAPI::createBrAPIConnection("wheat.triticeaetoolbox.org", is_breedbase = TRUE)

# Use with helper functions
trials <- T3BrapiHelpers::get_all_trial_meta_data(brapi_conn, "Wheat")
germplasm <- T3BrapiHelpers::get_germplasm_from_single_trial("8128", brapi_conn)
```

Key BrAPI connection methods used internally:
- `$get(endpoint)`: GET request, returns list with `$content$result`
- `$search(data_type, body=list(...))`: POST search request, returns object with `$combined_data`
- `$wizard(data_type, filters=list(...))`: Higher-level query wrapper

## Testing and CI

- GitHub Actions runs R CMD check on macOS, Windows, and Ubuntu
- Tests multiple R versions: devel, release, oldrel-1
- No unit tests currently exist in `tests/` directory
- Package must pass R CMD check to merge PRs

## Notes for Development

- Package is under active development; APIs may change
- When adding new functions, follow the existing patterns: vectorized functions with `_vec` suffix, single-item functions without
- **Use snake_case for all function names, variables, and parameters**
- Always add roxygen2 documentation with `@param`, `@return`, `@examples` (use `\dontrun{}` for examples requiring internet)
- Export functions by adding `#' @export` to roxygen2 block
- Add required package imports with `@importFrom` rather than using `::` everywhere
- The package assumes familiarity with BrAPI specification and does not attempt to mirror it completely
- **CRITICAL**: When extracting data from BrAPI API responses, use camelCase field names (e.g., `data$studyDbId`, `data$germplasmName`) because the API returns JSON with camelCase keys. Output data frames are converted to snake_case via `janitor::clean_names()`
