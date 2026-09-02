# Command-line interface dispatcher for imurun

Parses command-line arguments and dispatches to
[`run_fit()`](https://accidda.github.io/imuRUN/reference/run_fit.md),
[`imurun_init()`](https://accidda.github.io/imuRUN/reference/imurun_init.md),
or
[`imurun_copy_example()`](https://accidda.github.io/imuRUN/reference/imurun_copy_example.md).
Returns an integer exit code.

## Usage

``` r
cli_run_fit(args = commandArgs(trailingOnly = TRUE))
```

## Arguments

- args:

  character vector of command-line arguments.

## Value

Invisibly, an integer exit code (`0L` = success, `1L` = validation, `2L`
= model error, `3L` = I/O error).
