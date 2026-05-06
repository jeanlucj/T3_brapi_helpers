---
editor_options: 
  markdown: 
    wrap: 80
---

<!-- README.md is generated from README.Rmd. Please edit README.Rmd -->

# T3_brapi_helpers

<!-- badges: start -->

[![R-CMD-check](https://github.com/jeanlucj/T3_brapi_helpers/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/jeanlucj/T3_brapi_helpers/actions/workflows/R-CMD-check.yaml)

<!-- badges: end -->

Helpers for working with **BrAPI** services and **The Triticeae Toolbox (T3)**
from R. This package provides small, composable utilities that make it easier to
authenticate, query, and transform BrAPI data into formats suitable for
downstream T3 workflows.

--------------------------------------------------------------------------------

## Requirements

This package operates on `BrAPIConnection` R6 objects created by the **BrAPI**
package.

-   Install BrAPI from GitHub (not CRAN)
-   Functions expect a valid `BrAPIConnection` its methods
-   Examples that query live servers require an internet connection

--------------------------------------------------------------------------------

## Installation

You can install the development version from GitHub:

``` r
# install.packages("pak")
pak::pak("jeanlucj/T3_brapi_helpers")
#>  Found [30m[48;5;249m 1 [49m[39m deps for [30m[48;5;249m 0/1 [49m[39m pkgs [⠋] Resolving jeanlucj/T3_brapi_helpers Found [30m[48;5;249m 1 [49m[39m deps for [30m[48;5;249m 0/1 [49m[39m pkgs [⠙] Resolving jeanlucj/T3_brapi_helpers Found [30m[48;5;249m 1 [49m[39m deps for [30m[48;5;249m 0/1 [49m[39m pkgs [⠹] Resolving jeanlucj/T3_brapi_helpers Found [30m[48;5;249m 1 [49m[39m deps for [30m[48;5;249m 0/1 [49m[39m pkgs [⠸] Resolving jeanlucj/T3_brapi_helpers Found [30m[48;5;249m 11 [49m[39m deps for [30m[48;5;249m 1/1 [49m[39m pkgs [⠼] Resolving standard (CRAN/BioC) packages                                                                             
#> [36mℹ[39m No downloads are needed
#>  Installing...              [32m✔[39m 1 pkg + 37 deps: kept 38 [38;5;249m[38;5;249m[1.1s][38;5;249m[39m
```

--------------------------------------------------------------------------------

## Package goals

The main goals of **T3_brapi_helpers** are to:

-   simplify common BrAPI queries used in T3 pipelines
-   reduce redundant code going from BrAPI responses to data.frames
-   make exploratory BrAPI work easier from R

--------------------------------------------------------------------------------

## Quick start

``` r
# Connect to a BrAPI endpoint
brapiConn <- BrAPI::createBrAPIConnection("wheat-sandbox.triticeaetoolbox.org",
                                          is_breedbase = TRUE)

# Retrieve trial metadata for "Wheat"
all_trials <- T3_brapi_helpers::getAllTrialMetaData(brapiConn, "Wheat")
head(all_trials)
#> # A tibble: 6 × 12
#>   study_db_id study_name     study_type study_description location_name trial_db_id
#>   <chr>       <chr>          <chr>      <chr>             <chr>         <chr>      
#> 1 7658        1RS-Dry_2012_… phenotypi… , 1RS drought ex… Davis, CA     343        
#> 2 7040        1RS-Irr_2012_… phenotypi… , 1RS drought ex… Davis, CA     343        
#> 3 8128        2017_WestLafa… <NA>       2017 trial        West Lafayet… 368        
#> 4 8129        2018_WestLafa… <NA>       2018 trial        West Lafayet… 368        
#> 5 8200        2020_Y1_1      phenotypi… 2020 Y1-1 ACRE    West Lafayet… 9287       
#> 6 8202        2020_Y1_2      phenotypi… 2020 Y1-2 ACRE    West Lafayet… 9287       
#> # ℹ 6 more variables: start_date <dttm>, end_date <dttm>, program_name <chr>,
#> #   common_crop_name <chr>, experimental_design <chr>, create_date <dttm>
```

--------------------------------------------------------------------------------

## Typical workflow

A common pattern when using this package is:

1.  Connect to a BrAPI server
2.  Retrieve core objects (studies, trials, germplasm)
3.  Normalize or reshape results
4.  Export or pass results to T3 tooling

``` r
wheatConn <- BrAPI::createBrAPIConnection("wheat.triticeaetoolbox.org",
                                          is_breedbase = TRUE)

predict_trial_vec_Wheat <- c("10673", "10674", "10675", "10676", "10677", "10678", "10679", "10680", "10681")

predict_trial_meta <- predict_trial_vec_Wheat |>
  T3_brapi_helpers::getTrialMetaDataFromTrialVec(wheatConn)

predict_germ <- predict_trial_meta$study_db_id |>
  T3_brapi_helpers::getGermplasmFromTrialVec(wheatConn)
#> ■■■■ 11% | ETA: 0s ■■■■■■■■ 22% | ETA: 9s ■■■■■■■■■■■ 33% | ETA: 10s
#> ■■■■■■■■■■■■■■ 44% | ETA: 10s ■■■■■■■■■■■■■■■■■■ 56% | ETA: 12s
#> ■■■■■■■■■■■■■■■■■■■■■ 67% | ETA: 8s ■■■■■■■■■■■■■■■■■■■■■■■■ 78% | ETA: 5s
#> ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 89% | ETA: 3s

nAccPerTrial <- predict_germ |> dplyr::group_by(studyDbId) |>
  dplyr::summarise(nAccInTrial=dplyr::n())
```

--------------------------------------------------------------------------------

## Relationship to other tools

-   **BrAPI**: This package assumes familiarity with the BrAPI specification and
    does not attempt to mirror it completely.

--------------------------------------------------------------------------------

## Documentation

Full documentation is available at\
<https://jeanlucj.github.io/T3_brapi_helpers/>

--------------------------------------------------------------------------------

## Development status

This package is under active development.

-   APIs may change
-   Function names and signatures are not yet stable
-   Feedback and issues are welcome

--------------------------------------------------------------------------------

## Contributing

Issues are welcome. Please include a minimal reproducible example when reporting
bugs.

--------------------------------------------------------------------------------

## License

MIT © Jean-Luc Jannink
