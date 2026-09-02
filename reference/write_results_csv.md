# Write the by-target results to a CSV

The results-only output: one row per target with its posterior median
and credible interval, without the input sheets. For a user who wants to
load the estimates into something other than a spreadsheet.

## Usage

``` r
write_results_csv(results, path, overwrite = FALSE)
```

## Arguments

- results:

  data.frame of summarized targets, as returned by
  [`summarize_targets()`](https://accidda.github.io/imuRUN/reference/summarize_targets.md).

- path:

  character; destination `.csv` path.

- overwrite:

  logical; `TRUE` to replace an existing file.

## Value

Invisibly, `path`.

## See also

[`write_results_workbook()`](https://accidda.github.io/imuRUN/reference/write_results_workbook.md),
[`summarize_targets()`](https://accidda.github.io/imuRUN/reference/summarize_targets.md)

## Examples

``` r
res <- data.frame(
  target_id = "1", loc_id = "A", cohort = 5L, age = 5L, dose = 2L,
  n_draws = 100L, est_median = 0.8, est_lower = 0.7, est_upper = 0.9,
  ci_level = 0.95
)
out <- file.path(tempdir(), "results.csv")
write_results_csv(res, out, overwrite = TRUE)
```
