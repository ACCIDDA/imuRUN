# Read all imuGAP inputs from a directory

Convenience entry point that checks for all required inputs and reads
them. Returns a named list with the raw (un-canonicalized)
`observations`, `populations`, and `locations` data, ready to be passed
to [`run_fit()`](https://accidda.github.io/imurun/reference/run_fit.md).

## Usage

``` r
read_inputs(dir)
```

## Arguments

- dir:

  character; directory containing `observations`, `populations`, and
  `locations` as CSV or RDS.

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
