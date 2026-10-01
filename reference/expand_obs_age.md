# Expand a single `age` column into the `age_min`/`age_max` span

The observations sheet describes the inclusive age span a count was
drawn over (`age_min`..`age_max`), but the overwhelmingly common case is
a count at one age. Rather than make every such row repeat itself, a
sheet that carries a lone `age` column is read as
`age_min = age_max = age`.

Only applied when neither span column is present: a sheet that supplies
`age_min`/`age_max` is authoritative, and any `age` column alongside
them is an ordinary ignored extra column.

Likewise a single age may be given as `age_min` alone: a blank (or
absent) `age_max` takes that row's `age_min`.

## Usage

``` r
expand_obs_age(obs)
```

## Arguments

- obs:

  a data.frame of observations.

## Value

`obs`, with `age_min`/`age_max` present whenever `age` was, and
`age_max` filled from `age_min` wherever it was blank.
