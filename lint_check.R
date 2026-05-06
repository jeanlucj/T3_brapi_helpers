#!/usr/bin/env Rscript
# Quick linting check script for T3_brapi_helpers
# Usage: Rscript lint_check.R [file1.R file2.R ...]
#   or just: Rscript lint_check.R     (to lint entire package)

library(lintr)

args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  # Lint entire package
  cat("Linting entire package...\n\n")
  results <- lint_package()
} else {
  # Lint specific files
  cat("Linting specified files...\n\n")
  results <- unlist(lapply(args, lint), recursive = FALSE)
}

if (length(results) == 0) {
  cat("✓ No linting issues found!\n")
  quit(status = 0)
}

# Categorize by linter type
linter_counts <- table(sapply(results, function(x) x$linter))

cat("=== Linting Summary ===\n")
cat("Total issues:", length(results), "\n\n")

cat("Issues by type:\n")
print(sort(linter_counts, decreasing = TRUE))

# Check for snake_case violations specifically
snake_case_issues <- sum(grepl("object_name", names(linter_counts)))
cat("\n✓ Snake_case naming issues:", snake_case_issues)
if (snake_case_issues == 0) {
  cat(" (GOOD!)")
}
cat("\n")

# Show first few issues
cat("\nFirst 5 issues:\n")
for (i in seq_len(min(5, length(results)))) {
  issue <- results[[i]]
  cat(sprintf("\n%s:%d:%d\n  %s\n",
              issue$filename,
              issue$line_number,
              issue$column_number,
              issue$message))
}

if (length(results) > 5) {
  cat(sprintf("\n... and %d more issues\n", length(results) - 5))
}

cat("\nRun the full results to see all issues:\n")
cat("  library(lintr); lint_package()\n")

quit(status = 1)
