# Run the imurun fitting pipeline

The core engine behind the `imurun` command-line interface, exposed as
an ordinary R function. Given a directory of inputs it loads the
`observations` and `locations` files (CSV or RDS), validates them
against the canonical 'imuGAP' schema, fits the model with
`imuGAP::sampling()`, and writes `fit.rds` to the output directory.

The function never throws for expected failure modes; instead it prints
a human-readable message and returns an integer exit code, so it can
drive a shell command directly. The exit-code taxonomy is:

- 0:

  Success (or usage/validation-only request).

- 1:

  Schema validation failed.

- 2:

  Model fitting failed.

- 3:

  Input/output error (missing directory, unreadable or unwritable
  files).

## Usage

``` r
run_fit(args = commandArgs(trailingOnly = TRUE))
```

## Arguments

- args:

  character vector of command-line style arguments. The first non-flag
  argument is the input directory; an optional second is the output
  directory (defaults to the input directory). A leading `-h`/`--help`
  either prints usage (when alone) or requests validation-only mode
  (when followed by an input directory).

## Value

Invisibly, an integer exit code (see Description).

## Examples

``` r
# Usage text, no fitting:
run_fit(character(0))
#> imurun.R -- Minimal CLI for imuGAP model fitting
#> 
#> Usage: imurun <input> [output_dir]
#>        imurun -h <input>              (validate only, no model fitting)
#>        imurun init [dir]              (write a blank input template workbook)
#>        imurun example [dir]           (write a filled example workbook)
#>        imurun -h | --help             (show this message)
#> 
#> <input> is either a directory of CSV/RDS files or a single .xlsx workbook.
#> 
#> A directory must contain:
#>   observations.csv (or .rds)      -- columns: obs_id, loc_id, cohort, age, dose, positive, sample_n
#>   locations.csv (or .rds)         -- columns: loc_id, parent_id (hierarchical; see package docs)
#> 
#> A workbook must have one sheet per input with the same column names
#> (run 'imurun init' to get a correctly-headed template).
#> 
#> Output: fit.rds (raw stanfit object for post-processing).
#> output_dir defaults to input_dir. Exit codes: 0=success, 1=validation, 2=model, 3=I/O.

# Validate inputs only (no Stan toolchain required):
dir <- tempfile("imurun_validate_")
dir.create(dir)
if (FALSE) { # \dontrun{
# Fit and write fit.rds (requires a working Stan toolchain):
run_fit("path/to/inputs")
} # }
```
