# Target-request sheet schema

Required columns of the (required) `target` sheet that drives the
by-target predictions. A target-request row names one or more locations
(`loc_id`, a `;`-separated list), a target year (`year`), and an
inclusive age span (`age_low`..`age_high`).

A row that names only a `loc_id`, leaving
`year`/`age_low`/`age_high`/`dose` blank, inherits those values from the
row above (last-observation-carried- forward), so a run of locations
sharing one request need not repeat them.

## Usage

``` r
IMURUN_TARGET_SCHEMA
```

## Format

A character vector of the required target columns, in sheet order.

## See also

[`expand_targets()`](https://accidda.github.io/imuRUN/reference/expand_targets.md),
[`validate_targets()`](https://accidda.github.io/imuRUN/reference/validate_targets.md),
[`summarize_targets()`](https://accidda.github.io/imuRUN/reference/summarize_targets.md)

## Examples

``` r
IMURUN_TARGET_SCHEMA
#> [1] "loc_id"   "year"     "age_low"  "age_high"
```
