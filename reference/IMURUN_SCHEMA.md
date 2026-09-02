# Canonical imuGAP input schema

The column schema that imurun targets for each of its two inputs.

## Usage

``` r
IMURUN_SCHEMA
```

## Format

A named list of two character vectors (`observations`, `locations`),
each giving the required column names in schema order.

## Details

imurun simplifies imuGAP's inputs: rather than a separate populations
sheet, each observation row carries its own
`loc_id`/`year`/`age_min`/`age_max`/`dose`, and imurun constructs the
imuGAP populations from the observations (see
[`build_populations()`](https://accidda.github.io/imuRUN/reference/build_populations.md)).
This list gives the column names that are expected once header aliases
(see
[IMURUN_HEADER_ALIASES](https://accidda.github.io/imuRUN/reference/IMURUN_HEADER_ALIASES.md))
have been applied and before types and values are enforced.

Each element of `IMURUN_SCHEMA` describes one sheet/input:

- `observations`: One row per observation. Columns: `obs_id` (a unique
  identifier – the loader assigns one automatically if you omit it, so
  it is not a user column), `loc_id` (must exist in locations), `year`
  (positive integer observation year), `age_min` and `age_max` (positive
  integers giving the inclusive age span the count was drawn over, with
  `age_min <= age_max`), `dose` (integer in `1:max_dose`), `positive`
  (non-negative integer count of positive results), `sample_n` (positive
  integer sample size, with `positive <= sample_n`). Optional:
  `censored` (`NA` or `1`).

  A single-age observation may be written with one `age` column instead
  of `age_min`/`age_max`; the loader expands it to
  `age_min = age_max = age` (see
  [`expand_obs_age()`](https://accidda.github.io/imuRUN/reference/expand_obs_age.md)).

- `locations`: The location hierarchy. Required columns: `loc_id`
  (unique identifier), `parent_id` (the parent's `loc_id`, or `NA` for
  the single root).

## See also

[`validate_inputs()`](https://accidda.github.io/imuRUN/reference/validate_inputs.md),
[`read_inputs()`](https://accidda.github.io/imuRUN/reference/read_inputs.md),
[IMURUN_TARGET_SCHEMA](https://accidda.github.io/imuRUN/reference/IMURUN_TARGET_SCHEMA.md)

## Examples

``` r
IMURUN_SCHEMA$observations
#> [1] "obs_id"   "loc_id"   "year"     "age_min"  "age_max"  "dose"     "positive"
#> [8] "sample_n"
IMURUN_SCHEMA$locations
#> [1] "loc_id"    "parent_id"
```
