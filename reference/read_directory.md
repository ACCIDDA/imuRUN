# Read imuGAP inputs from a directory of loose files

Reads `observations`, `locations`, and `target` files from `dir` (each
either `.csv` or `.rds`). Reports every missing file at once (mirroring
[`check_all_inputs()`](https://accidda.github.io/imuRUN/reference/check_all_inputs.md)
semantics) rather than failing on the first.

## Usage

``` r
read_directory(dir)
```

## Arguments

- dir:

  character; path to directory containing the input files.

## Value

A named list with `obs`, `locs`, and `target` data frames.

## Examples

``` r
dir <- system.file("extdata", package = "imuRUN")
```
