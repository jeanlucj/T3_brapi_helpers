# Using lintr for Code Style in T3_brapi_helpers

## What is lintr?

`lintr` is an R package that performs static code analysis - it checks your code for style issues without running it. It helps enforce consistent coding standards, including the snake_case naming convention.

## Installation

If you don't have lintr installed:

``` r
install.packages("lintr")
```

## Configuration

The `.lintr` file in the package root configures lintr rules:

- **`object_name_linter`**: Enforces snake_case for all variable and function names
- **`line_length_linter`**: Warns if lines exceed 120 characters
- **`T_and_F_symbol_linter`**: Requires `TRUE`/`FALSE` instead of `T`/`F`
- **Disabled linters**: indentation, commented code, object usage, object length (to reduce noise)

## How to Use lintr

### Option 1: Lint the entire package (recommended)

``` r
library(lintr)
lint_package()
```

This checks all R files in the `R/` directory.

### Option 2: Lint a single file

``` r
library(lintr)
lint("R/brapi_trials.R")
```

### Option 3: Lint only new/changed code

Before committing, lint only files you've changed:

``` r
library(lintr)

# Get changed files from git
changed_files <- system("git diff --name-only HEAD | grep '\\.R$'", intern = TRUE)
lapply(changed_files, lint)
```

## Common Issues and Fixes

### 1. **snake_case naming violations**

❌ Bad:

``` r
getAllData <- function(studyID) { ... }
myVariable <- 42
```

✅ Good:

``` r
get_all_data <- function(study_id) { ... }
my_variable <- 42
```

### 2. **Use FALSE/TRUE instead of F/T**

❌ Bad:

``` r
function(verbose = F)
```

✅ Good:

``` r
function(verbose = FALSE)
```

### 3. **Spacing around braces and operators**

❌ Bad:

``` r
function(x){
  if(x==5){
    return(TRUE)
  }
}
```

✅ Good:

``` r
function(x) {
  if (x == 5) {
    return(TRUE)
  }
}
```

### 4. **Explicit return() not needed**

❌ Bad:

``` r
my_function <- function(x) {
  result <- x + 1
  return(result)
}
```

✅ Good:

``` r
my_function <- function(x) {
  result <- x + 1
  result
}
```

(The last expression is automatically returned in R)

## Integration with RStudio

If you use RStudio, you can:

1.  Install the `lintr` package
2.  Open a file
3.  In the console, run: `lintr::lint("R/your_file.R")`
4.  Click on issues in the "Markers" pane to jump to the line

## Integration with GitHub Actions (CI)

To automatically lint on every pull request, add this to `.github/workflows/R-CMD-check.yaml`:

``` yaml
- name: Lint
  run: |
    Rscript -e 'install.packages("lintr")'
    Rscript -e 'lintr::lint_package()'
```

## Pre-commit Hook (Advanced)

To automatically lint before each commit, create `.git/hooks/pre-commit`:

``` bash
#!/bin/bash
Rscript -e '
library(lintr)
files <- system("git diff --cached --name-only | grep \"\\\\.R$\"", intern=TRUE)
if (length(files) > 0) {
  results <- lapply(files, lint)
  results <- unlist(results, recursive=FALSE)
  if (length(results) > 0) {
    print(results)
    cat("\n❌ Commit blocked - fix linting issues first\n")
    quit(status=1)
  }
}
'
```

Make it executable:

``` bash
chmod +x .git/hooks/pre-commit
```

## Ignoring Specific Lines

If you need to ignore a specific linting rule on one line:

``` r
# nolint start
my_legacy_camelCase <- function() { }
# nolint end
```

Or for a specific linter:

``` r
myVar <- 42  # nolint: object_name_linter
```

## Workflow Recommendation

1.  **Before starting work**: Run `lintr::lint_package()` to see current state
2.  **While coding**: Use your editor's lintr integration (if available)
3.  **Before committing**: Lint your changed files
4.  **Before pushing**: Run `lintr::lint_package()` one final time

## Customizing Rules

Edit `.lintr` to adjust rules. For example, to allow some camelCase:

``` r
linters: linters_with_defaults(
    object_name_linter = object_name_linter(styles = c("snake_case", "camelCase"))
  )
```

But for this package, we enforce pure snake_case!
