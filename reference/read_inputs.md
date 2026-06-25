# Read all imuGAP inputs from a directory or workbook

Convenience entry point that loads the raw (un-canonicalized)
`observations`, `populations`, and `locations` data, ready to be passed
to
[`validate_inputs()`](https://accidda.github.io/imurun/reference/validate_inputs.md)
or [`run_fit()`](https://accidda.github.io/imurun/reference/run_fit.md).

`read_inputs()` accepts either:

- a directory:

  containing `observations`, `populations`, and `locations` files as CSV
  or RDS (the original behavior); or

- a single `.xlsx` workbook:

  with one sheet per input, read via
  [`read_workbook()`](https://accidda.github.io/imurun/reference/read_workbook.md).

Missing inputs (files or sheets) are all reported at once.

## Usage

``` r
read_inputs(path)
```

## Arguments

- path:

  character; a directory of CSV/RDS files, or the path to a single
  `.xlsx` workbook.

## Value

A named list with elements `obs`, `pops`, and `locs`.

## Examples

``` r
dir <- tempfile("imurun_read_")
dir.create(dir)
write.csv(data.frame(obs_id = 1, positive = 1, sample_n = 10),
          file.path(dir, "observations.csv"), row.names = FALSE)
write.csv(data.frame(obs_id = 1, loc_id = 1, cohort = 2000, age = 1,
                     dose = 1, weight = 1),
          file.path(dir, "populations.csv"), row.names = FALSE)
write.csv(data.frame(loc_id = 1, parent_id = NA),
          file.path(dir, "locations.csv"), row.names = FALSE)
inputs <- read_inputs(dir)
names(inputs)
#> [1] "obs"  "pops" "locs"
```
