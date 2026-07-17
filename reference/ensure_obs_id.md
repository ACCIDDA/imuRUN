# Assign a row-number obs_id when the observations sheet omits one

`obs_id` is not something a user should have to invent: if the
observations frame carries no `obs_id` column, assign one (`1:n`) so the
downstream imuGAP canonicalization has the unique key it needs.

## Usage

``` r
ensure_obs_id(obs)
```

## Arguments

- obs:

  a data.frame of observations.

## Value

`obs` with an `obs_id` column guaranteed present.
