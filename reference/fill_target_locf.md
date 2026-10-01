# Carry non-location target columns forward into blank rows

Fills the `target` sheet the way a spreadsheet user expects: a blank
`year`, `age_low`, or `age_high` cell inherits the value from the
nearest row above that supplied it. Each of those columns is carried
forward independently, so a run of location-only rows all share the
preceding request's year and ages. A blank cell with no value above it
is left blank (the first row cannot inherit).

`dose` is different: a blank `dose` means the final dose, so it is
carried forward only into location-only rows (those that leave `year`,
`age_low`, and `age_high` all blank), which repeat the request above
them in full. A blank `dose` on a row that states its own year or ages
stays blank and falls back to the default in
[`expand_targets()`](https://accidda.github.io/imuRUN/reference/expand_targets.md).

## Usage

``` r
fill_target_locf(targets)
```

## Arguments

- targets:

  data.frame of target-request rows.

## Value

The `targets` data.frame with blank cells filled from the row above.
