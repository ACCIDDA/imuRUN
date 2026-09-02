# Read all imuGAP inputs from a directory or workbook

Convenience entry point that loads the raw (un-canonicalized) inputs
regardless of storage format. Dispatches to
[`read_workbook()`](https://accidda.github.io/imuRUN/reference/read_workbook.md)
when `path` is an `.xlsx` file, and
[`read_directory()`](https://accidda.github.io/imuRUN/reference/read_directory.md)
when `path` is a directory.

## Usage

``` r
read_inputs(path)
```

## Arguments

- path:

  character; path to a directory or a `.xlsx` file.

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
