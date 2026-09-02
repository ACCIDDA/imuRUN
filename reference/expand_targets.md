# Expand a compact target-request sheet into explicit target rows

Turns each row of the `target` sheet into the explicit
`(loc_id, cohort, age, dose)` rows that imuGAP's by-target prediction
path consumes. imurun is a thin adapter here: the actual expansion is
delegated to
[`imuGAP::create_target()`](https://accidda.github.io/imuGAP/reference/create_target.html)
in `"snapshot"` mode, one call per target-request row.

## Usage

``` r
expand_targets(targets, default_dose)
```

## Arguments

- targets:

  data.frame of target-request rows (see
  [IMURUN_TARGET_SCHEMA](https://accidda.github.io/imuRUN/reference/IMURUN_TARGET_SCHEMA.md)).

- default_dose:

  integer; the dose used when a row's `dose` cell is blank. Typically
  the model's final dose (`fit$data$n_doses`).

## Value

A data.frame with columns `obs_id`, `target_id`, `loc_id`, `cohort`,
`age`, `dose`, `weight` – one row per distinct target identity.

## Details

Each row's `year` represents the timing of the target snapshot.
`create_target(mode = "snapshot")` fans the row out over its location
list (`loc_id`) and inclusive age span (`age_low`..`age_high`), deriving
a cohort for each age so that `age + cohort = year` is held constant
(`cohort_i = year - age_i`). A blank `dose` cell takes `default_dose`
(typically the final dose). Every expanded row is an independent target
carrying `weight = 1`. Identical target identities (across rows) are
dropped as duplicates, and a unique integer `obs_id` is assigned so the
posterior draws can be grouped unambiguously by target.

## See also

[`validate_targets()`](https://accidda.github.io/imuRUN/reference/validate_targets.md),
[`summarize_targets()`](https://accidda.github.io/imuRUN/reference/summarize_targets.md),
[`imuGAP::create_target()`](https://accidda.github.io/imuGAP/reference/create_target.html)

## Examples

``` r
tg <- data.frame(
  loc_id = "Bunting School; Cardinal Academy",
  year = 20, age_low = 1, age_high = 5
)
expand_targets(tg, default_dose = 2L)
#>    obs_id target_id           loc_id cohort age dose weight
#> 1       1         1   Bunting School     19   1    2      1
#> 2       2         1 Cardinal Academy     19   1    2      1
#> 3       3         1   Bunting School     18   2    2      1
#> 4       4         1 Cardinal Academy     18   2    2      1
#> 5       5         1   Bunting School     17   3    2      1
#> 6       6         1 Cardinal Academy     17   3    2      1
#> 7       7         1   Bunting School     16   4    2      1
#> 8       8         1 Cardinal Academy     16   4    2      1
#> 9       9         1   Bunting School     15   5    2      1
#> 10     10         1 Cardinal Academy     15   5    2      1
```
