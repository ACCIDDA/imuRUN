# Add results to the supplied workbook

The primary human-readable output. When `source` is supplied, its
worksheets, formatting, validation, and notes are preserved and a
`results` sheet is added. `path` may be the same as `source` (the
default fit workflow, which updates the supplied workbook) or a
different path. Without `source`, a new workbook is constructed from
`inputs` for directory inputs.

## Usage

``` r
write_results_workbook(inputs, results, path, overwrite = FALSE, source = NULL)
```

## Arguments

- inputs:

  a list with `obs`, `locs`, and optionally `target` data frames, e.g.
  the result of
  [`read_inputs()`](https://accidda.github.io/imuRUN/reference/read_inputs.md).

- results:

  data.frame of summarized targets, as returned by
  [`summarize_targets()`](https://accidda.github.io/imuRUN/reference/summarize_targets.md).

- path:

  character; destination `.xlsx` path.

- overwrite:

  logical; `TRUE` to replace an existing file.

- source:

  optional character path to an existing input workbook to amend.

## Value

Invisibly, `path`.

## Details

Each results row carries the `target_id` label and the resolved
`loc_id`/`cohort`/`age`/`dose` identity, so a reader can trace it back
to the `target` sheet row it came from. A single target-request row
expands to one results row per location and per age in its span (see
[`expand_targets()`](https://accidda.github.io/imuRUN/reference/expand_targets.md)),
which is why the estimates land on their own sheet rather than being
appended to the request rows.

## See also

[`write_results_csv()`](https://accidda.github.io/imuRUN/reference/write_results_csv.md),
[`write_workbook()`](https://accidda.github.io/imuRUN/reference/write_workbook.md),
[`summarize_targets()`](https://accidda.github.io/imuRUN/reference/summarize_targets.md)

## Examples

``` r
inputs <- list(
  obs = data.frame(
    obs_id = 1, loc_id = "A", cohort = 5, age = 5,
    dose = 2, positive = 3, sample_n = 10
  ),
  locs = data.frame(loc_id = "A", parent_id = NA)
)
res <- data.frame(
  target_id = "1", loc_id = "A", cohort = 5L, age = 5L, dose = 2L,
  n_draws = 100L, est_median = 0.8, est_lower = 0.7, est_upper = 0.9,
  ci_level = 0.95
)
out <- file.path(tempdir(), "results.xlsx")
write_results_workbook(inputs, res, out, overwrite = TRUE)
```
