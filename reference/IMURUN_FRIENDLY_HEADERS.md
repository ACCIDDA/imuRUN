# Human-readable column headers, per sheet

The friendly header each canonical column carries in the shipped
template and example workbooks. Validation messages name columns by
these headers, so a problem points at the column the user actually sees.
`data-raw/make_workbooks.R` writes the workbooks from this map.

## Usage

``` r
IMURUN_FRIENDLY_HEADERS
```
