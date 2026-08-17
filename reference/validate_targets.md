# Validate a target-request sheet with friendly, row-referenced errors

Checks a `target` sheet the same way
[`validate_inputs()`](https://accidda.github.io/imurun/reference/validate_inputs.md)
checks the input sheets: it collects *all* problems and reports them at
once in spreadsheet terms, naming the offending column and row. Problems
detected include missing/renamed required columns (per
[IMURUN_TARGET_SCHEMA](https://accidda.github.io/imurun/reference/IMURUN_TARGET_SCHEMA.md)),
non-numeric `cohort`/`age_low`/`age_high`/`dose`, `loc_id` values absent
from the locations sheet, an inverted age span (`age_low > age_high`),
out-of-range `cohort`/`age`/`dose`, and a snapshot span whose expansion
(`cohort + (age_high - age_low)`) reaches beyond the model's cohort
count.

On success the (unmodified) target frame is returned invisibly. On
failure a single error is raised whose message lists every problem
found.

## Usage

``` r
validate_targets(targets, loc_ids, max_cohort, max_age, max_dose = 2L)
```

## Arguments

- targets:

  data.frame of target-request rows.

- loc_ids:

  character; the known location identifiers (the `loc_id` column of the
  locations sheet).

- max_cohort, max_age:

  integer upper bounds for `cohort` and the age span.

- max_dose:

  integer; the maximum allowed `dose` (default `2`).

## Value

Invisibly, the validated `targets` data.frame.

## See also

[`expand_targets()`](https://accidda.github.io/imurun/reference/expand_targets.md),
[`validate_inputs()`](https://accidda.github.io/imurun/reference/validate_inputs.md)

## Examples

``` r
tg <- data.frame(loc_id = "A;B", cohort = 5, age_low = 5, age_high = 7)
validate_targets(tg, loc_ids = c("A", "B"), max_cohort = 15, max_age = 8)
```
