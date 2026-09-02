# Reduce posterior draws to a median and credible interval per target

Collapses the long posterior draws returned by 'imuGAP”s by-target
prediction path into one wide row per target: the posterior median and a
symmetric credible interval of the predicted coverage probability
(`p_obs`). 'imuGAP' returns draws only; this is the small reduction
imurun layers on top.

## Usage

``` r
summarize_targets(draws, ci_level = 0.95)
```

## Arguments

- draws:

  data.frame of posterior draws with (at least) an `obs_id` key and a
  `p_obs` column, one row per (draw x target). Any of the identity
  columns `target_id`, `loc_id`, `cohort`, `age`, `dose` present are
  carried through to the output.

- ci_level:

  numeric in `(0, 1)`; the credible-interval level (default `0.95`, i.e.
  the 2.5% and 97.5% quantiles).

## Value

A data.frame with one row per target: the carried identity columns plus
`n_draws`, `est_median`, `est_lower`, `est_upper`, and `ci_level`.

## See also

[`expand_targets()`](https://accidda.github.io/imuRUN/reference/expand_targets.md)

## Examples

``` r
draws <- data.frame(
  obs_id = 1L, loc_id = "A", cohort = 5L, age = 5L, dose = 2L,
  p_obs = seq(0, 1, length.out = 201)
)
summarize_targets(draws, ci_level = 0.95)
#>   loc_id cohort age dose n_draws est_median est_lower est_upper ci_level
#> 1      A      5   5    2     201        0.5     0.025     0.975     0.95
```
