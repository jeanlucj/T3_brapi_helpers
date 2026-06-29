
<!-- README.md is generated from README.Rmd. Please edit README.Rmd -->

# T3BrapiHelpers

<!-- badges: start -->

[![R-CMD-check](https://github.com/jeanlucj/T3BrapiHelpers/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/jeanlucj/T3BrapiHelpers/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

Helpers for working with **BrAPI** services and **The Triticeae Toolbox
(T3)** from R. This package provides small, composable utilities that
make it easier to authenticate, query, and transform BrAPI data into
formats suitable for downstream T3 workflows.

------------------------------------------------------------------------

## Requirements

This package operates on `BrAPIConnection` R6 objects created by the
**BrAPI** package.

- Install BrAPI from GitHub (not CRAN)
- Functions expect a valid `BrAPIConnection` its methods
- Examples that query live servers require an internet connection

------------------------------------------------------------------------

## Installation

There are dependencies. “gdsfmt” and “SNPRelate” are useful for working
with VCF files. They are bioconductor packages. “BrAPI” is a package
developed and maintained by David Waring. It is on GitHub. Use
“devtools” to install packages from GitHub.

``` r

if (!require("gdsfmt") | !require("SNPRelate")){
  if (!require("BiocManager")){
    install.packages("BiocManager")
  }
  BiocManager::install(c("gdsfmt", "SNPRelate"))
}
#> Loading required package: gdsfmt
#> Loading required package: SNPRelate

if (!require("devtools")){
  install.packages("devtools")
}
#> Loading required package: devtools
#> Loading required package: usethis
if (!require("BrAPI")){
  install_github("TriticeaeToolbox/BrAPI.R")
}
#> Loading required package: BrAPI
#> Loading required package: httr
#> Loading required package: askpass

devtools::install_github("jeanlucj/T3BrapiHelpers")
#> Using GitHub PAT from the git credential store.
#> Skipping install of 'T3BrapiHelpers' from a github remote, the SHA1 (9c54a70d) has not changed since last install.
#>   Use `force = TRUE` to force installation
```

------------------------------------------------------------------------

## Package goals

The main goals of **T3BrapiHelpers** are to:

- simplify common BrAPI queries used in T3 pipelines
- reduce redundant code going from BrAPI responses to data.frames
- make exploratory BrAPI work easier from R

------------------------------------------------------------------------

## Quick start

``` r
# Connect to a BrAPI endpoint
brapiConn <- BrAPI::createBrAPIConnection("wheat-sandbox.triticeaetoolbox.org",
                                          is_breedbase = TRUE)

# Retrieve trial metadata for "Wheat"
all_trials <- T3BrapiHelpers::get_all_trial_meta_data(brapiConn, "Wheat")
head(all_trials)
#> # A tibble: 6 × 12
#>   study_db_id study_name  study_type study_description location_name trial_db_id
#>   <chr>       <chr>       <chr>      <chr>             <chr>         <chr>      
#> 1 7658        1RS-Dry_20… phenotypi… , 1RS drought ex… Davis, CA     343        
#> 2 7040        1RS-Irr_20… phenotypi… , 1RS drought ex… Davis, CA     343        
#> 3 8128        2017_WestL… <NA>       2017 trial        West Lafayet… 368        
#> 4 8129        2018_WestL… <NA>       2018 trial        West Lafayet… 368        
#> 5 8200        2020_Y1_1   phenotypi… 2020 Y1-1 ACRE    West Lafayet… 9287       
#> 6 8202        2020_Y1_2   phenotypi… 2020 Y1-2 ACRE    West Lafayet… 9287       
#> # ℹ 6 more variables: start_date <dttm>, end_date <dttm>, program_name <chr>,
#> #   common_crop_name <chr>, experimental_design <chr>, create_date <dttm>
```

------------------------------------------------------------------------

## Typical workflow

A common pattern when using this package is:

1.  Connect to a BrAPI server
2.  Retrieve core objects (studies, trials, germplasm)
3.  Normalize or reshape results
4.  Export or pass results to scripts using T3 data

``` r
wheatConn <- BrAPI::createBrAPIConnection("wheat.triticeaetoolbox.org",
                                          is_breedbase = TRUE)

predict_trial_vec_Wheat <- c("10673", "10674", "10675", "10676", "10677", "10678", "10679", "10680", "10681")

predict_trial_meta <- predict_trial_vec_Wheat |>
  T3BrapiHelpers::get_trial_meta_data_from_trial_vec(wheatConn)

predict_germ <- predict_trial_meta$study_db_id |>
  T3BrapiHelpers::get_germplasm_from_trial_vec(wheatConn)
#> ■■■■ 11% | ETA: 12s ■■■■■■■■ 22% | ETA: 13s ■■■■■■■■■■■ 33% | ETA: 11s
#> ■■■■■■■■■■■■■■ 44% | ETA: 10s ■■■■■■■■■■■■■■■■■■ 56% | ETA: 11s
#> ■■■■■■■■■■■■■■■■■■■■■ 67% | ETA: 7s ■■■■■■■■■■■■■■■■■■■■■■■■ 78% | ETA: 5s
#> ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 89% | ETA: 3s

nAccPerTrial <- predict_germ |> dplyr::group_by(study_db_id) |>
  dplyr::summarise(n_acc_in_trial=dplyr::n())
```

------------------------------------------------------------------------

## Relationship to other tools

- **BrAPI**: This package assumes familiarity with the BrAPI
  specification and does not attempt to mirror it completely.

------------------------------------------------------------------------

## Documentation

Full documentation is available at\
<https://jeanlucj.github.io/T3BrapiHelpers/>

------------------------------------------------------------------------

## Development status

This package is under active development.

- APIs may change
- Function names and signatures are not yet stable
- Feedback and issues are welcome

------------------------------------------------------------------------

## Contributing

Issues are welcome. Please include a minimal reproducible example when
reporting bugs.

------------------------------------------------------------------------

## License

MIT © Jean-Luc Jannink
