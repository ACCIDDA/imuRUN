# Check required columns and report them in spreadsheet terms

Compares the columns present on one input frame against the required
[IMURUN_SCHEMA](https://accidda.github.io/imuRUN/reference/IMURUN_SCHEMA.md)
columns for that sheet, returning a character vector of human-readable
problem messages (empty if none). Used by
[`validate_inputs()`](https://accidda.github.io/imuRUN/reference/validate_inputs.md).

## Usage

``` r
check_sheet_columns(df, sheet, required = IMURUN_SCHEMA[[sheet]])
```

## Arguments

- df:

  data.frame; the sheet contents.

- sheet:

  character; one of `"observations"`, `"populations"`, `"locations"` (or
  any sheet name used in the message).

- required:

  character; the required column names. Defaults to the
  [IMURUN_SCHEMA](https://accidda.github.io/imuRUN/reference/IMURUN_SCHEMA.md)
  entry for `sheet`; pass an explicit vector to check a sheet not in
  `IMURUN_SCHEMA` (e.g. the `target` sheet).

## Value

character vector of problem messages (possibly length zero).
