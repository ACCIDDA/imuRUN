# Canonical imuGAP input schema

## Usage

``` r
IMURUN_SCHEMA
```

## Format

A named list of two character vectors (`observations`, `locations`),
each giving the required column names in schema order.

## See also

[`validate_inputs()`](https://accidda.github.io/imurun/reference/validate_inputs.md),
[`read_inputs()`](https://accidda.github.io/imurun/reference/read_inputs.md),
[`imurun_template()`](https://accidda.github.io/imurun/reference/imurun_template.md)

## Examples

``` r
IMURUN_SCHEMA$observations
#> [1] "obs_id"   "loc_id"   "cohort"   "age_min"  "age_max"  "dose"     "positive"
#> [8] "sample_n"
IMURUN_SCHEMA$locations
#> [1] "loc_id"    "parent_id"
```
