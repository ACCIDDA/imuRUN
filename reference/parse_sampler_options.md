# Pull sampler-option overrides out of the command-line arguments

Lets a user set 'Stan' sampler settings from a command wrapper: it scans
`args` for the recognized sampler flags (`--iter`, `--chains`, `--seed`,
`--warmup`), each written `--iter N` or `--iter=N`, validates their
values, and returns them separated from the remaining (positional)
arguments. Precedence is simple: an explicit flag overrides the built-in
default; unset options fall back to `imuGAP::stan_options()`'s defaults.
Unknown flags are left untouched in `rest` so the caller can handle
them.

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

## Examples

``` r
parse_sampler_options(c("data.xlsx", "--iter", "4000", "--chains=2"))
#> $overrides
#> $overrides$iter
#> [1] 4000
#> 
#> $overrides$chains
#> [1] 2
#> 
#> 
#> $rest
#> [1] "data.xlsx"
#> 
```
