# Run the imurun fitting pipeline

The spreadsheet-first fitting entry point, also used by the optional
`imurun` command wrapper. Given a workbook or directory of inputs, it
validates the observations, locations, target requests, and workbook
configuration; fits with `imuGAP::sampling()`; writes `fit.rds`; and
adds a human-readable `results` sheet to the supplied workbook (or
creates `results.xlsx` for directory input).

The function never throws for expected failure modes; instead it prints
a human-readable message and returns an integer exit code, so it can
drive a shell command directly. The exit-code taxonomy is:

- 0:

  Success (or usage/validation-only request).

- 1:

  Input validation failed: the schema, or an invalid or unknown
  command-line option.

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

  character vector whose first non-flag value is the input workbook or
  directory and whose optional second value is the output directory. A
  leading `-h`/`--help` either prints usage (when alone) or requests
  validation-only mode. Workbook sampler settings come from its
  `configuration` sheet; `--iter`, `--chains`, `--seed`, and `--warmup`
  may override them for automation. See
  [`parse_sampler_options()`](https://accidda.github.io/imurun/reference/parse_sampler_options.md).

## Value

Invisibly, an integer exit code (see Description).

## Examples

``` r
# Usage text, no fitting:
run_fit(character(0))
#> imurun.R -- Minimal CLI for imuGAP model fitting
#> 
#> Usage: imurun <input> [output_dir] [sampler options]
#>        imurun -h <input>              (validate only, no model fitting)
#>        imurun init [dir]              (write a blank input template workbook)
#>        imurun example [dir]           (write a filled example workbook)
#>        imurun -h | --help             (show this message)
#> 
#> <input> is either a directory of CSV/RDS files or a single .xlsx workbook.
#> 
#> A directory must contain:
#>   observations.csv (or .rds)      -- columns: obs_id, loc_id, cohort, age_min, age_max, dose,
#>                                      positive, sample_n. cohort is the reference cohort, that of
#>                                      age_max; a single 'age' column works for a one-age count.
#>   locations.csv (or .rds)         -- columns: loc_id, parent_id (hierarchical; see package docs)
#> 
#> A workbook must have one sheet per input with the same column names
#> (run 'imurun init' to get a correctly-headed template).
#> 
#> Sampler options belong in the workbook's 'configuration' sheet. The generated
#> template supplies iter=2000 and chains=4; seed and warmup may be left blank.
#> For automation and older workflows, these flags override the sheet:
#>   --iter N        total iterations per chain (default 2000)
#>   --chains N      number of chains (default 4)
#>   --seed N        random seed for reproducibility
#>   --warmup N      warmup iterations per chain
#> Flags may appear anywhere and may be written --iter N or --iter=N.
#> 
#> Output options:
#>   --results PATH  write an amended copy instead of updating the input workbook
#>   --csv PATH      also write a results-only CSV
#>   --overwrite     replace existing output files (otherwise imurun refuses)
#> 
#> Output: for workbook input, a 'results' sheet of per-target medians and credible
#> intervals is added to that workbook; directory input writes results.xlsx.
#> fit.rds is also written for post-processing. output_dir defaults to input_dir.
#> Exit codes: 0=success, 1=validation, 2=model, 3=I/O.

# Validate inputs only (no Stan toolchain required):
dir <- tempfile("imurun_validate_")
dir.create(dir)
if (FALSE) { # \dontrun{
# Fit, amend the workbook, and write fit.rds (requires a Stan toolchain):
run_fit("path/to/inputs")
} # }
```
