# Check that a year column uses four-digit calendar years

Check that a year column uses four-digit calendar years

## Usage

``` r
check_calendar_year_column(df, sheet, col = "year")
```

## Arguments

- df:

  data.frame; sheet contents.

- sheet:

  character; sheet name (for messages).

- col:

  character; year column name.

## Value

character vector of problem messages (possibly length zero).
