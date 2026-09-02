# Validate target-request rows against model extents and schema

Checks that `targets` matches
[IMURUN_TARGET_SCHEMA](https://accidda.github.io/imuRUN/reference/IMURUN_TARGET_SCHEMA.md),
that every named location exists in `loc_ids`, that
`age_low <= age_high`, and that the requested ages and derived cohorts
fall within `max_age` and `max_cohort`.

## Usage

``` r
validate_targets(targets, loc_ids, max_cohort, max_age, max_dose = 2L)
```

## Arguments

- targets:

  data.frame of target requests.

- loc_ids:

  character vector of valid location identifiers.

- max_cohort:

  integer; upper bound on the derived cohort.

- max_age:

  integer; upper bound on the requested age.

- max_dose:

  integer; upper bound on the dose (default 2).

## Value

Invisibly, `targets` on success; raises an error describing all problems
found otherwise.

## See also

[`expand_targets()`](https://accidda.github.io/imuRUN/reference/expand_targets.md),
[IMURUN_TARGET_SCHEMA](https://accidda.github.io/imuRUN/reference/IMURUN_TARGET_SCHEMA.md)

## Examples

``` r
tg <- data.frame(loc_id = "A;B", year = 12, age_low = 5, age_high = 7)
validate_targets(tg, loc_ids = c("A", "B"), max_cohort = 15, max_age = 8)
```
