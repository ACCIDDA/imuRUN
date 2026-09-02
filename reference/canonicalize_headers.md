# Rename friendly column headers to imurun's canonical names

Renames any human-readable header present in
[IMURUN_HEADER_ALIASES](https://accidda.github.io/imuRUN/reference/IMURUN_HEADER_ALIASES.md)
to its canonical name (case-insensitively). Columns already using a
canonical name, and any unrecognized columns, pass through unchanged.
This lets the shipped template and example workbooks use human-readable
headers while the rest of imurun sees only canonical names.

When `sheet` names a sheet with entries in
[IMURUN_SHEET_ALIASES](https://accidda.github.io/imuRUN/reference/IMURUN_SHEET_ALIASES.md),
those entries win over the shared map. That is what lets `observations`
and `target` both label their age span "Youngest age" / "Oldest age"
while canonicalizing to `age_min`/`age_max` and `age_low`/`age_high`
respectively.

## Usage

``` r
canonicalize_headers(df, sheet = NULL)
```

## Arguments

- df:

  a data.frame.

- sheet:

  character or `NULL`; which sheet `df` came from. `NULL` uses only the
  shared map.

## Value

`df` with friendly headers renamed to canonical.
