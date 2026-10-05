# Read all imuGAP inputs from a workbook or list

Convenience entry point that loads the raw (un-canonicalized) inputs.
Reads an `.xlsx` workbook with
[`read_workbook()`](https://accidda.github.io/imuRUN/reference/read_workbook.md),
or normalizes an in-memory list of data frames.

## Usage

``` r
read_inputs(path)
```

## Arguments

- path:

  character; path to a `.xlsx` workbook, or a list with `obs` and `locs`
  (and optionally `target` and `config`) data frames.

## Value

A named list with `obs`, `locs`, and `target` (and optionally `config`)
data frames.

## Examples

``` r
wb <- system.file("extdata", "imurun_example.xlsx", package = "imuRUN")
if (nzchar(wb)) {
  inputs <- read_inputs(wb)
  names(inputs)
}
#> [1] "obs"    "locs"   "target" "config"
```
