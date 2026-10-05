# Run the imurun fitting pipeline

The spreadsheet-first fitting entry point. Given a workbook (or an
in-memory inputs list), it validates the observations, locations, target
requests, and configuration; fits with `imuGAP::sampling()`; and outputs
requested deliverables (`results` sheet in workbook, results CSV, and/or
`fit.rds`).

## Usage

``` r
run_fit(
  input,
  output_dir = NULL,
  dryrun = FALSE,
  result = c("xlsx"),
  overwrite = TRUE,
  ...
)
```

## Arguments

- input:

  character path to a `.xlsx` workbook, or a pre-loaded `inputs` list
  (from
  [`read_inputs()`](https://accidda.github.io/imuRUN/reference/read_inputs.md)).

- output_dir:

  character path to output directory. Defaults to the directory of
  `input` (for workbooks) or the working directory (for list inputs).

- dryrun:

  logical; if `TRUE`, validates inputs without fitting the model and
  returns `invisible(0L)` on success. Default is `FALSE`.

- result:

  character vector of requested outputs, e.g. `c("xlsx")` (default),
  `c("rds")`, `c("csv")`, or combinations/custom paths.

- overwrite:

  logical; if `TRUE` (default), overwrites existing output files. If
  `FALSE` and a destination exists, prompts in interactive sessions or
  stops.

- ...:

  optional arguments passed to override configuration settings.

## Value

Invisibly, an integer exit code (`0L` for success).

## Details

imuGAP numbers birth cohorts from 1, so the saved `fit.rds` works in
rebased cohorts. Its `"imurun_cohort_origin"` attribute is the birth
cohort numbered 1; convert
[`expand_targets()`](https://accidda.github.io/imuRUN/reference/expand_targets.md)
cohorts before calling
[`predict()`](https://rdrr.io/r/stats/predict.html):
`targets$cohort <- targets$cohort - attr(fit, "imurun_cohort_origin") + 1L`.

## Examples

``` r
if (FALSE) { # \dontrun{
# Validate inputs only:
run_fit("imurun_example.xlsx", dryrun = TRUE)

# Fit and update spreadsheet with results:
run_fit("imurun_example.xlsx")

# Fit and save raw RDS object:
run_fit("imurun_example.xlsx", result = c("rds"))
} # }
```
