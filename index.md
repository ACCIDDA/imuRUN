# imurun

`imurun` is a lean, beginner-friendly command-line front-end to the
[`imuGAP`](https://github.com/ACCIDDA/imuGAP) model-fitting package. You
hand it your data — either a directory of `observations` / `populations`
/ `locations` files (CSV or RDS) or a single Excel workbook with one
sheet per input — and it reads the inputs, validates them against
imuGAP’s canonical schema with friendly, spreadsheet-referenced error
messages, fits the model with `imuGAP::sampling()`, and writes the
result to `fit.rds`. No R scripting is required to run a fit, but every
step of the engine is also exported as an ordinary R function, so the
same pipeline works from a shell command, from a scripted R session, or
anywhere in between.

## Features

- **Two input modes.** Point `imurun` at a directory of `observations`,
  `populations`, and `locations` files (CSV or RDS, CSV taking
  precedence), or at a single `.xlsx` workbook with one sheet per input
  — convenient for people who do not work in R.
- **Bundled template and example workbooks.** `imurun init` drops a
  blank template (correct headers plus an instructions sheet) into a
  directory; `imurun example` drops a small, complete, runnable example
  derived from imuGAP’s `*_sim` data.
- **Friendly validation.** Inputs are checked against the canonical
  schema (\[`IMURUN_SCHEMA`\]) via a layer over imuGAP’s canonicalizers
  that names the offending sheet, column, or row and collects *every*
  problem it can find rather than stopping at the first.
- **Validate-only mode.** `imurun -h <input>` checks the inputs without
  fitting, so you can confirm a workbook is well-formed before
  committing to a model run.
- **Fits and saves.** On success it runs `imuGAP::sampling()` and writes
  `fit.rds` (the raw `stanfit` object) to the output directory for
  post-processing.
- **Scriptable.** The engine functions
  ([`run_fit()`](https://accidda.github.io/imurun/reference/run_fit.md),
  [`read_inputs()`](https://accidda.github.io/imurun/reference/read_inputs.md),
  [`validate_inputs()`](https://accidda.github.io/imurun/reference/validate_inputs.md),
  [`read_workbook()`](https://accidda.github.io/imurun/reference/read_workbook.md),
  and friends) are all exported for use directly from R, and the CLI
  returns shell exit codes (`0` success, `1` validation, `2` model, `3`
  I/O) for use in pipelines.

## Installation

`imurun` is a beta release; install it from GitHub for now:

``` r

# install.packages("remotes")
remotes::install_github("ACCIDDA/imurun")
```

Once it is on CRAN you will be able to install the released version
with:

``` r

install.packages("imurun")
```

`imurun` depends on [`imuGAP`](https://github.com/ACCIDDA/imuGAP);
fitting is delegated to `imuGAP::sampling()`, which requires imuGAP’s
Stan-based model backend (a working Stan toolchain). Reading `.xlsx`
workbooks additionally uses [`readxl`](https://readxl.tidyverse.org).

To make `imurun` available as a shell command, install the bundled CLI
onto your `PATH`:

``` r

imurun::install_cli()          # symlinks into ~/.local/bin (Unix) or writes
                               # an imurun.cmd shim (Windows)
```

Make sure the target directory (`~/.local/bin` by default) is on your
`PATH`. If you would rather not install a launcher, you can always
invoke the engine from R with `imurun::run_fit(...)`.

## Usage

The CLI takes an input path and an optional output directory:

    imurun <input> [output_dir]
    imurun -h <input>              # validate only, no model fitting
    imurun init [dir]              # write a blank input template workbook
    imurun example [dir]           # write a filled example workbook
    imurun -h | --help             # show usage

`<input>` is either a directory of CSV/RDS files or a single `.xlsx`
workbook. `output_dir` defaults to the input directory (or, for a
workbook, the directory containing it), and the fit is written there as
`fit.rds`.

### Walkthrough

1.  **Get a workbook to fill in.** Scaffold a blank template into the
    current directory:

        imurun init .

    This writes `imurun_template.xlsx` with one sheet each for
    `observations`, `populations`, and `locations` (correct headers)
    plus an `instructions` sheet. To start from a filled, runnable
    example instead, use `imurun example .` to get
    `imurun_example.xlsx`.

2.  **Fill it in.** Open the workbook and enter your data on the three
    sheets. The required columns are `obs_id, positive, sample_n`
    (observations); `obs_id, loc_id, cohort, age, dose` (populations);
    and `loc_id, parent_id` (locations). Extra columns are ignored.

3.  **Validate.** Check the inputs without fitting:

        imurun -h imurun_template.xlsx

    Any problems are reported all at once, in spreadsheet terms.
    Validation does not require the Stan toolchain.

4.  **Fit.** Once validation passes, run the model:

        imurun imurun_template.xlsx

    `imurun` loads the inputs, validates them, runs
    `imuGAP::sampling()`, and writes **`fit.rds`** (the raw `stanfit`
    object) to the output directory — next to the workbook by default,
    or into `output_dir` if you supply one.

The same steps work with a directory of CSV/RDS files in place of the
workbook, for example `imurun data/` where `data/` contains
`observations.csv`, `populations.csv`, and `locations.csv`.

### From R

Every step is also available as an exported function, so you can drive
the same pipeline from a script:

``` r

library(imurun)

# Copy the bundled example next to your work and inspect it
example <- imurun_copy_example(tempdir())

# Read and validate without fitting
inputs <- read_inputs(example)
validate_inputs(inputs)

# Or run the whole pipeline (writes fit.rds), returning a shell exit code
run_fit(example)
```

See [`?run_fit`](https://accidda.github.io/imurun/reference/run_fit.md),
[`?read_inputs`](https://accidda.github.io/imurun/reference/read_inputs.md),
[`?validate_inputs`](https://accidda.github.io/imurun/reference/validate_inputs.md),
and
[`?IMURUN_SCHEMA`](https://accidda.github.io/imurun/reference/IMURUN_SCHEMA.md)
for details, and the [package website](https://accidda.github.io/imurun)
for the full reference.

## Related

`imurun` is part of the `imu*` family and fronts
[`imuGAP`](https://github.com/ACCIDDA/imuGAP), the underlying
model-fitting package.
