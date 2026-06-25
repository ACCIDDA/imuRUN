# Check that a count-like column is numeric, in spreadsheet terms

Check that a count-like column is numeric, in spreadsheet terms

## Usage

``` r
check_numeric_column(df, sheet, col)
```

## Arguments

- df:

  data.frame; sheet contents.

- sheet:

  character; sheet name (for messages).

- col:

  character; column to check.

## Value

character vector of problem messages (possibly length zero).
