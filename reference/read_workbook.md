# Read all required sheets from an .xlsx workbook

Reads the `observations`, `populations`, and `locations` sheets from a
single Excel workbook into data frames. Reports every missing sheet at
once (mirroring
[`check_all_inputs()`](https://accidda.github.io/imurun/reference/check_all_inputs.md)
semantics) rather than failing on the first.

Sheet names are matched case-insensitively against the required
[IMURUN_SHEETS](https://accidda.github.io/imurun/reference/IMURUN_SHEETS.md).
The reader package ('readxl') is only needed at call time; an
informative error is raised if it is not installed.

## Usage

``` r
read_workbook(path)
```

## Arguments

- path:

  character; path to a `.xlsx` workbook.

## Value

A named list with elements `obs`, `pops`, and `locs`, each a
`data.frame`.

## Examples

``` r
wb <- system.file("extdata", "imurun_example.xlsx", package = "imurun")
if (nzchar(wb) && requireNamespace("readxl", quietly = TRUE)) {
  inputs <- read_workbook(wb)
  names(inputs)
}
#> [1] "obs"  "pops" "locs"
```
