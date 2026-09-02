# Normalize imuGAP prediction draws before summarizing them

Bridges the one naming difference between the two halves of the
by-target path:
[`imuGAP::predict.imugap_fit()`](https://accidda.github.io/imuGAP/reference/predict.imugap_fit.html)
returns the predicted coverage column as `coverage`, while
[`summarize_targets()`](https://accidda.github.io/imuRUN/reference/summarize_targets.md)
consumes `p_obs`. Kept as a named function rather than an inline rename
so the coupling is visible and has a test of its own; if imuGAP ever
renames the column, this is the single place that changes.

## Usage

``` r
as_target_draws(pred)
```

## Arguments

- pred:

  the object returned by
  [`predict()`](https://rdrr.io/r/stats/predict.html) on an imuGAP fit.

## Value

A data.frame with a `p_obs` column, ready for
[`summarize_targets()`](https://accidda.github.io/imuRUN/reference/summarize_targets.md).
