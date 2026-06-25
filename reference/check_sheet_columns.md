# Check required columns and report them in spreadsheet terms

Compares the columns present on one input frame against the required
[IMURUN_SCHEMA](https://accidda.github.io/imurun/reference/IMURUN_SCHEMA.md)
columns for that sheet, returning a character vector of human-readable
problem messages (empty if none). Used by
[`validate_inputs()`](https://accidda.github.io/imurun/reference/validate_inputs.md).

## Usage

``` r
check_sheet_columns(df, sheet)
```

## Arguments

- df:

  data.frame; the sheet contents.

- sheet:

  character; one of `"observations"`, `"populations"`, `"locations"`.

## Value

character vector of problem messages (possibly length zero).
