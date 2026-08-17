# Construct an imuGAP populations frame from an observations frame

imurun has no populations sheet: each observation carries its own
`loc_id`/`cohort`/`age_min`/`age_max`/`dose`, and the imuGAP populations
are derived from it. An observation spanning ages `age_min`..`age_max`
becomes one population row per age in the span, all sharing its
`obs_id`.

## Usage

``` r
build_populations(obs)
```

## Arguments

- obs:

  a data.frame of observations with `obs_id`, `loc_id`, `cohort`,
  `dose`, and either `age_min`/`age_max` or a single `age` column.

## Value

a data.frame with `obs_id`, `loc_id`, `cohort`, `age`, `dose`, and
`weight`, with one row per (observation x age in its span).

## Details

An observation carries *counts* (`positive`/`sample_n`) for the whole
span, so the span's rows are a mixture rather than separate
observations: 'imuGAP' requires a population's weights to sum to 1
within an `obs_id`, and the Stan model reads them as the mixing
proportions of that observation's modeled probability. Two conventions
follow:

- Weights:

  Each age in the span gets `1 / (age_max - age_min + 1)`. The sheet
  carries no age-specific denominators, so a population- proportional
  split is not derivable from the input; equal weights are the
  documented default, and explicit per-age weights are possible future
  functionality.

- Cohorts:

  `cohort` is the **reference** cohort, that of `age_max`, and the
  cohort of each younger age is derived so that `age + cohort` is held
  constant: `cohort_at_age = cohort + age_max - age`. This is a snapshot
  in time, and is the same relation `imuGAP::create_target()` applies in
  `"snapshot"` mode, so an observation and a target written over the
  same span describe the same populations.

A single-age observation (`age_min == age_max`) reduces to exactly the
former behavior: one row, `weight = 1`, `cohort` unchanged.

A row whose span is missing or inverted is emitted as a single row at
`age_max` rather than expanded, so that the downstream canonicalizer
reports the offending value instead of this function failing on it or
silently producing a backwards span.
