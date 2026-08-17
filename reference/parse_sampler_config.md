# Read sampler settings from a workbook configuration sheet

Parses the `Setting`/`Value` rows supplied in generated imurun
workbooks. Recognized settings are `iter`, `chains`, `seed`, and
`warmup`; blank values use the package/default value. The same
whole-number rules as the compatibility CLI flags apply. Unknown or
repeated populated settings are reported rather than silently ignored.

## Usage

``` r
parse_sampler_config(config)
```

## Arguments

- config:

  optional data.frame read from the `configuration` sheet.

## Value

A named list of sampler-option overrides.
