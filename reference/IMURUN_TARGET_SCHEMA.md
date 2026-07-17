# Target-request sheet schema

Required columns of the (required) `target` sheet that drives the
by-target predictions. A target-request row names one or more locations
(`loc_id`, a `;`-separated list), a reference birth-cohort index
(`cohort`), and an inclusive age span (`age_low`..`age_high`). The row
is expanded in snapshot mode (via `imuGAP::create_target()`): `cohort`
is the cohort of the oldest age in the span, and a cohort is derived for
each age so that `age + cohort` stays constant. All columns use the same
integer-index representation as the `populations` sheet – there is no
calendar-year translation. Optional columns are `dose` (a blank cell
defaults to the final dose) and `target_id` (a free-text label echoed
into the results).

A row that names only a `loc_id`, leaving
`cohort`/`age_low`/`age_high`/`dose` blank, inherits those values from
the row above (last-observation-carried- forward), so a run of locations
sharing one request need not repeat them.

## Usage

``` r
IMURUN_TARGET_SCHEMA
```

## Format

A character vector of the required target columns, in sheet order.

## See also

[`expand_targets()`](https://accidda.github.io/imurun/reference/expand_targets.md),
[`validate_targets()`](https://accidda.github.io/imurun/reference/validate_targets.md),
[`summarize_targets()`](https://accidda.github.io/imurun/reference/summarize_targets.md)

## Examples

``` r
IMURUN_TARGET_SCHEMA
#> [1] "loc_id"   "cohort"   "age_low"  "age_high"
```
