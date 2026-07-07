# Carry non-location target columns forward into blank rows

Fills the `target` sheet the way a spreadsheet user expects: a row that
names only a `loc_id` (leaving `cohort`, `age_low`, `age_high`, and/or
`dose` blank) inherits those values from the nearest row above that
supplied them. Each of those columns is carried forward independently,
so a run of location-only rows all share the preceding request's
cohort/age/dose. A blank cell with no value above it is left blank (the
first row cannot inherit, and a never-supplied `dose` still falls back
to the default).

## Usage

``` r
fill_target_locf(targets)
```

## Arguments

- targets:

  data.frame of target-request rows.

## Value

The `targets` data.frame with blank `cohort`/`age_low`/`age_high`/
`dose` cells filled from the row above.
