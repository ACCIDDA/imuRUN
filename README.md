# imuRUN

<!-- badges: start -->
[![R-CMD-check](https://github.com/ACCIDDA/imuRUN/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/ACCIDDA/imuRUN/actions/workflows/R-CMD-check.yaml)
[![lint](https://github.com/ACCIDDA/imuRUN/actions/workflows/lint.yaml/badge.svg)](https://github.com/ACCIDDA/imuRUN/actions/workflows/lint.yaml)
[![test-coverage](https://github.com/ACCIDDA/imuRUN/actions/workflows/test-coverage.yaml/badge.svg)](https://github.com/ACCIDDA/imuRUN/actions/workflows/test-coverage.yaml)
[![Codecov test coverage](https://codecov.io/gh/ACCIDDA/imuRUN/graph/badge.svg)](https://app.codecov.io/gh/ACCIDDA/imuRUN)
<!-- badges: end -->

**Routine-Use Notebooks** (`imuRUN`) is a spreadsheet-first front-end to the
[`imuGAP`](https://github.com/ACCIDDA/imuGAP) model-fitting package. It is built
for people who are comfortable running a command at the R prompt but are not
power R users: describe the analysis in one Excel workbook, validate it with
spreadsheet-referenced messages, fit with `imuGAP::sampling()`, and read the
coverage estimates back in the same workbook.

## Features

- **Two input modes.** Use a single `.xlsx` workbook or a directory containing
  `observations`, `locations`, and `target` files (CSV or RDS). imuRUN derives
  imuGAP's population rows from each observation's location, reference cohort,
  age span, and dose.
- **Bundled template and example workbooks.** `imurun_init()` writes a blank
  template with instructions and sampler configuration; `imurun_copy_example()`
  writes a complete example derived from imuGAP's `*_sim` data.
- **Friendly validation.** Inputs are checked against the canonical schema
  ([`IMURUN_SCHEMA`]) via a layer over imuGAP's canonicalizers that names the
  offending sheet, column, or row and collects *every* problem it can find
  rather than stopping at the first.
- **Validate-only mode.** `run_fit(c("-h", <input>))` checks the workbook
  without fitting.
- **Human-readable results.** On success, the input workbook gains a `results`
  sheet containing medians and credible intervals beside the request context;
  `fit.rds` is also saved for advanced post-processing.
- **Scriptable.** The engine functions (`run_fit()`, `read_inputs()`,
  `validate_inputs()`, `read_workbook()`, and friends) are exported for use
  directly from R. The optional CLI wrapper returns shell exit codes
  (`0` success, `1` validation, `2` model, `3` I/O) for use in pipelines.

## Installation

`imuRUN` is a beta release; install it from GitHub for now:

```r
# install.packages("remotes")
remotes::install_github("ACCIDDA/imuRUN")
```

Once it is on CRAN you will be able to install the released version with:

```r
install.packages("imuRUN")
```

`imuRUN` depends on [`imuGAP`](https://github.com/ACCIDDA/imuGAP); fitting is
delegated to `imuGAP::sampling()`, which requires imuGAP's Stan-based model
backend (a working Stan toolchain). Reading and writing `.xlsx` workbooks uses
[`openxlsx2`](https://cran.r-project.org/package=openxlsx2).

The R functions are the primary interface. To additionally make `imuRUN`
available as a shell command, install the bundled wrapper onto your `PATH`:

```r
imuRUN::install_cli()          # symlinks into ~/.local/bin (Unix) or writes
                               # an imurun.cmd shim (Windows)
```

Make sure the target directory (`~/.local/bin` by default) is on your `PATH`.
If you would rather not install a launcher, you can always invoke the engine
from R with `imuRUN::run_fit(...)`.

## Usage

`run_fit()` accepts a workbook path (or a directory of CSV/RDS inputs). The
generated workbook's `configuration` sheet holds `iter`, `chains`, `seed`, and
`warmup`; automation flags may override those values.

### Walkthrough

1. **Get a workbook to fill in.** Scaffold a blank template into the current
   directory:

   ```r
   imuRUN::imurun_init(".")
   ```

   This writes `imurun_template.xlsx` with `instructions`, `configuration`,
   `observations`, `locations`, and `target` sheets. To start from a filled,
   runnable example, use `imuRUN::imurun_copy_example(".")`.

2. **Fill it in.** Enter sampled counts on `observations`, the hierarchy on
   `locations`, and prediction requests on `target`. Review the sampler values
   on `configuration`. The workbook instructions define every column.

3. **Validate.** Check the inputs without fitting:

   ```r
   imuRUN::run_fit(c("-h", "imurun_template.xlsx"))
   ```

   Any problems are reported all at once, in spreadsheet terms. Validation
   does not require the Stan toolchain.

4. **Fit.** Once validation passes, run the model:

   ```r
   imuRUN::run_fit("imurun_template.xlsx")
   ```

   imuRUN adds a **`results`** sheet to that workbook and writes **`fit.rds`**
   beside it. It refuses to replace existing results unless `--overwrite` is
   supplied.

The same steps work with a directory of CSV/RDS files in place of the workbook,
for example `run_fit("data")` where `data/` contains `observations.csv`,
`locations.csv`, and `target.csv`.

### From R

Every step is also available as an exported function, so you can drive the same
pipeline from a script:

```r
library(imuRUN)

# Copy the bundled example next to your work and inspect it
example <- imurun_copy_example(tempdir())

# Read and validate without fitting
inputs <- read_inputs(example)
validate_inputs(inputs)

# Or run the whole pipeline (amends the workbook and writes fit.rds)
run_fit(example)
```

See `?run_fit`, `?read_inputs`, `?validate_inputs`, and `?IMURUN_SCHEMA` for
details, and the [package website](https://accidda.github.io/imuRUN/) for the
full reference.

## Related

`imuRUN` is part of the `imu*` family and fronts
[`imuGAP`](https://github.com/ACCIDDA/imuGAP), the underlying model-fitting
package.
