# Route setting overrides to the sampler, its control list, or the model

Splits `run_fit(...)` arguments the same way the configuration sheet is
split, so `run_fit(x, adapt_delta = 0.9)` behaves like an `adapt_delta`
row.

## Usage

``` r
split_setting_overrides(args)
```

## Arguments

- args:

  named list of overrides.

## Value

A list with `stan_opts` and `imugap_opts`.
