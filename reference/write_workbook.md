# Write imurun inputs to an .xlsx workbook

The inverse of
[`read_workbook()`](https://accidda.github.io/imuRUN/reference/read_workbook.md):
writes an inputs list (as returned by
[`read_inputs()`](https://accidda.github.io/imuRUN/reference/read_inputs.md))
back to a single `.xlsx` workbook, one sheet per element
(`observations`, `locations`, `configuration`, and `target` when
present). Uses the 'openxlsx2' package.

## Usage

``` r
write_workbook(inputs, path)
```

## Arguments

- inputs:

  a list with `obs` and `locs` (and optionally `target`) data frames,
  e.g. the result of
  [`read_inputs()`](https://accidda.github.io/imuRUN/reference/read_inputs.md).

- path:

  character; destination `.xlsx` path.

## Value

Invisibly, `path`.

## Examples

``` r
inputs <- list(
  obs = data.frame(obs_id = 1, loc_id = "A", cohort = 5, age = 5,
                   dose = 2, positive = 3, sample_n = 10),
  locs = data.frame(loc_id = "A", parent_id = NA)
)
out <- file.path(tempdir(), "inputs.xlsx")
write_workbook(inputs, out)
```
