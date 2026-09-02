# Pull sampler-option overrides out of the command-line arguments

Pull sampler-option overrides out of the command-line arguments

## Usage

``` r
parse_sampler_options(args)
```

## Arguments

- args:

  character vector of command-line style arguments.

## Value

A list with `overrides` (a named list of the supplied sampler options,
coerced to integers) and `rest` (the arguments with the recognized
sampler flags and their values removed).
