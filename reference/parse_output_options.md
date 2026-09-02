# Pull output-path options out of the command-line arguments

The counterpart to
[`parse_sampler_options()`](https://accidda.github.io/imuRUN/reference/parse_sampler_options.md)
for the output flags: `--results PATH` (where the amended workbook
goes), `--csv PATH` (also write a results-only CSV), and `--overwrite`
(allow replacing existing outputs). Each path flag may be written
`--csv PATH` or `--csv=PATH`. Unrecognized arguments are left in `rest`
for the caller.

## Usage

``` r
parse_output_options(args)
```

## Arguments

- args:

  character vector of command-line style arguments.

## Value

A list with `options` (a named list holding any of `results`, `csv`, and
`overwrite`) and `rest` (the arguments with the recognized output flags
and their values removed).

## See also

[`parse_sampler_options()`](https://accidda.github.io/imuRUN/reference/parse_sampler_options.md)

## Examples

``` r
parse_output_options(c("data.xlsx", "--csv", "out.csv", "--overwrite"))
#> $options
#> $options$csv
#> [1] "out.csv"
#> 
#> $options$overwrite
#> [1] TRUE
#> 
#> 
#> $rest
#> [1] "data.xlsx"
#> 
```
