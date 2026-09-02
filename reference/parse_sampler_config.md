# Read calculation settings from a workbook configuration sheet or list

Parses the `Setting`/`Value` rows supplied in generated imurun workbooks
or a configuration list, categorizing them into `stan_opts` (for
[`flexstanr::stan_options`](https://accidda.github.io/flexstanr/reference/stan_options.html)
/
[`imuGAP::stan_options`](https://accidda.github.io/flexstanr/reference/stan_options.html))
and `imugap_opts` (for
[`imuGAP::imugap_options`](https://accidda.github.io/imuGAP/reference/imugap_options.html)).

## Usage

``` r
parse_sampler_config(config)
```

## Arguments

- config:

  optional data.frame or list with configuration settings.

## Value

A named list with `stan_opts` and `imugap_opts` sub-lists.
