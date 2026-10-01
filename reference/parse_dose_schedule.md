# Read a dose schedule from a configuration value

A spreadsheet cell holds the schedule as text, e.g. `"1, 4"`: the age at
which each dose is given, separated by commas, semicolons, or spaces.

## Usage

``` r
parse_dose_schedule(v)
```

## Arguments

- v:

  character; the raw value.

## Value

integer vector of dose ages.
