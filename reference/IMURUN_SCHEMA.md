# Canonical imuGAP input schema

The column schema that imurun targets for each of the three inputs.
These are the columns required by the 'imuGAP' canonicalizers
(`canonicalize_observations()`, `canonicalize_populations()`, and
`canonicalize_locations()` from 'imuGAP') and reflected in the shipped
template and example workbooks. Extra columns are permitted and ignored
by 'imuGAP'; only the required columns are enforced.

Each element of `IMURUN_SCHEMA` describes one sheet/input:

- observations:

  One row per observation. Required columns: `obs_id` (unique
  non-missing identifier), `positive` (non-negative integer count of
  positive results), `sample_n` (positive integer sample size, with
  `positive <= sample_n`). Optional: `censored` (`NA` or `1`).

- populations:

  Cohort/age/dose breakdown that each observation covers, one or more
  rows per `obs_id`. Required columns: `obs_id` (must match the
  observations), `loc_id` (must exist in locations), `cohort` (positive
  integer), `age` (positive integer), `dose` (integer in `1:max_dose`).
  Optional: `weight` (positive numeric summing to 1 within each
  `obs_id`).

- locations:

  The location hierarchy. Required columns: `loc_id` (unique
  identifier), `parent_id` (the parent's `loc_id`, or `NA` for the
  single root).

## Usage

``` r
IMURUN_SCHEMA
```

## Format

A named list of three character vectors (`observations`, `populations`,
`locations`), each giving the required column names in schema order.

## See also

[`validate_inputs()`](https://accidda.github.io/imurun/reference/validate_inputs.md),
[`read_inputs()`](https://accidda.github.io/imurun/reference/read_inputs.md),
[`imurun_template()`](https://accidda.github.io/imurun/reference/imurun_template.md)

## Examples

``` r
IMURUN_SCHEMA$observations
#> [1] "obs_id"   "positive" "sample_n"
IMURUN_SCHEMA$populations
#> [1] "obs_id" "loc_id" "cohort" "age"    "dose"  
IMURUN_SCHEMA$locations
#> [1] "loc_id"    "parent_id"
```
