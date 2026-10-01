# Format data-row indices as spreadsheet row numbers

Every input sheet has a header row, so data row `i` is spreadsheet row
`i + 1` (and line `i + 1` of a CSV file). Lists at most the first 20.

## Usage

``` r
sheet_rows(idx)
```

## Arguments

- idx:

  integer vector of data-row indices.

## Value

character scalar, e.g. `"2, 5, 9"`.
