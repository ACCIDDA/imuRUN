# Rename friendly column headers to imurun's canonical names

Renames any human-readable header present in
[IMURUN_HEADER_ALIASES](https://accidda.github.io/imurun/reference/IMURUN_HEADER_ALIASES.md)
to its canonical name (case-insensitively). Columns already using a
canonical name, and any unrecognized columns, pass through unchanged.
This lets the shipped template and example workbooks use human-readable
headers while the rest of imurun sees only canonical names.

## Usage

``` r
canonicalize_headers(df)
```

## Arguments

- df:

  a data.frame.

## Value

`df` with friendly headers renamed to canonical.
