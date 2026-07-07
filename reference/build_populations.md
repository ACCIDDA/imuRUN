# Construct an imuGAP populations frame from an observations frame

imurun has no populations sheet: each observation carries its own
`loc_id`/`cohort`/`age`/`dose`, so the imuGAP populations are one
`weight = 1` row per observation. This is the limited
(single-row-per-observation) flavor of imuGAP's populations flexibility.

## Usage

``` r
build_populations(obs)
```

## Arguments

- obs:

  a data.frame of observations with `obs_id`, `loc_id`, `cohort`, `age`,
  and `dose` columns.

## Value

a data.frame with `obs_id`, `loc_id`, `cohort`, `age`, `dose`, and
`weight` (all `1`).
