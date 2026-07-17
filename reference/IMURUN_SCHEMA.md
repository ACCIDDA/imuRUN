# Canonical imuGAP input schema

The column schema that imurun targets for each of its two inputs. imurun
simplifies imuGAP's inputs: rather than a separate populations sheet,
each observation row carries its own `loc_id`/`cohort`/`age`/`dose`, and
imurun constructs the imuGAP populations from the observations (one
`weight = 1` row per observation). This trades imuGAP's multi-row
weighted populations for a simpler one-sheet input; a future version may
add an optional populations sheet as a pure expansion. Extra columns are
permitted and ignored; only the required columns are enforced.

Each element of `IMURUN_SCHEMA` describes one sheet/input:

- observations:

  One row per observation. Columns: `obs_id` (a unique identifier – the
  loader assigns one automatically if you omit it, so it is not a user
  column), `loc_id` (must exist in locations), `cohort` (positive
  integer), `age` (positive integer), `dose` (integer in `1:max_dose`),
  `positive` (non-negative integer count of positive results),
  `sample_n` (positive integer sample size, with
  `positive <= sample_n`). Optional: `censored` (`NA` or `1`).

- locations:

  The location hierarchy. Required columns: `loc_id` (unique
  identifier), `parent_id` (the parent's `loc_id`, or `NA` for the
  single root).

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
#> [1] "obs_id"   "loc_id"   "cohort"   "age"      "dose"     "positive" "sample_n"
IMURUN_SCHEMA$locations
#> [1] "loc_id"    "parent_id"
```
