# imuRUN

**Routine-Use Notebooks** (`imuRUN`) is a spreadsheet-first front-end to
the [`imuGAP`](https://github.com/ACCIDDA/imuGAP) model-fitting package.
It is built for people who are comfortable running a command at the R
prompt but are not power R users: describe the analysis in one Excel
workbook, validate it with spreadsheet-referenced messages, fit with
`imuGAP::sampling()`, and read the coverage estimates back in the same
workbook.

## Features

- **One workbook in.** Describe the analysis in a single `.xlsx`
  workbook with `observations`, `locations`, and `target` sheets. imuRUN
  derives imuGAP’s population rows from each observation’s location,
  reference cohort, age span, and dose.
- **Bundled template and example workbooks.**
  [`imurun_init()`](https://accidda.github.io/imuRUN/reference/imurun_init.md)
  writes a blank template with instructions and sampler configuration;
  [`imurun_copy_example()`](https://accidda.github.io/imuRUN/reference/imurun_copy_example.md)
  writes a complete example derived from imuGAP’s `*_sim` data.
- **Friendly validation.** Inputs are checked against the canonical
  schema (\[`IMURUN_SCHEMA`\]) via a layer over imuGAP’s canonicalizers
  that names the offending sheet, column, or row and collects *every*
  problem it can find rather than stopping at the first.
- **Validate-only mode.** `run_fit(<input>, dryrun = TRUE)` checks the
  workbook without fitting.
- **Human-readable results.** On success, the input workbook gains a
  `results` sheet containing medians and credible intervals beside the
  request context. A results CSV and the fitted model (`.rds`, for
  advanced post-processing) are available on request.
- **Scriptable.** The engine functions
  ([`run_fit()`](https://accidda.github.io/imuRUN/reference/run_fit.md),
  [`read_inputs()`](https://accidda.github.io/imuRUN/reference/read_inputs.md),
  [`validate_inputs()`](https://accidda.github.io/imuRUN/reference/validate_inputs.md),
  [`read_workbook()`](https://accidda.github.io/imuRUN/reference/read_workbook.md),
  and friends) are exported for use directly from R. The optional CLI
  wrapper returns shell exit codes (`0` success, `1` validation, `2`
  model, `3` I/O) for use in pipelines.

## Installation

`imuRUN` is a beta release; install it from GitHub for now:

``` r

# install.packages("remotes")
remotes::install_github("ACCIDDA/imuRUN")
```

Once it is on CRAN you will be able to install the released version
with:

``` r

install.packages("imuRUN")
```

`imuRUN` depends on [`imuGAP`](https://github.com/ACCIDDA/imuGAP), which
fits a precompiled Stan model. With R from
[CRAN](https://cran.r-project.org/) on Windows or macOS, imuGAP installs
ready-built and no compiler is needed. With Homebrew’s R or on Linux,
packages are built from source, so you need a C++ compiler (Xcode
Command Line Tools on macOS, or `build-essential` or equivalent on
Linux), and the first install takes several minutes. Reading and writing
`.xlsx` workbooks uses
[`openxlsx2`](https://cran.r-project.org/package=openxlsx2).

The R functions are the primary interface. To additionally make `imuRUN`
available as a shell command, install the bundled wrapper onto your
`PATH`:

``` r

imuRUN::install_cli()          # symlinks into ~/.local/bin (Unix) or writes
                               # an imurun.cmd shim (Windows)
```

Make sure the target directory (`~/.local/bin` by default) is on your
`PATH`. If you would rather not install a launcher, you can always
invoke the engine from R with `imuRUN::run_fit(...)`.

## Usage

[`run_fit()`](https://accidda.github.io/imuRUN/reference/run_fit.md)
accepts a workbook path. The generated workbook’s `configuration` sheet
starts with `iter` and `chains`. Add `seed` or `warmup` as rows when
needed; automation flags may override them.

### Walkthrough

1.  **Get a workbook to fill in.** Scaffold a blank template into the
    current directory:

    ``` r

    imuRUN::imurun_init(".")
    ```

    This writes `imurun_template.xlsx` with `instructions`,
    `configuration`, `observations`, `locations`, and `target` sheets.
    To start from a filled, runnable example, use
    `imuRUN::imurun_copy_example(".")`.

2.  **Fill it in.** Enter sampled counts on `observations`, the
    hierarchy on `locations`, and prediction requests on `target`.
    Review the sampler values on `configuration`. The workbook
    instructions define every column.

3.  **Validate.** Check the inputs without fitting:

    ``` r

    imuRUN::run_fit("imurun_template.xlsx", dryrun = TRUE)
    ```

    Any problems are reported all at once, in spreadsheet terms.
    Validation does not require the Stan toolchain.

4.  **Fit.** Once validation passes, run the model:

    ``` r

    imuRUN::run_fit("imurun_template.xlsx")
    ```

    imuRUN adds a **`results`** sheet to that workbook, replacing any
    from an earlier run (pass `overwrite = FALSE` to be asked first).
    Add `result = c("xlsx", "csv", "rds")` to also write a results CSV
    and the fitted model. The `imurun` shell command instead refuses to
    replace existing results unless `--overwrite` is supplied.

### From R

Every step is also available as an exported function, so you can drive
the same pipeline from a script:

``` r

library(imuRUN)

# Copy the bundled example next to your work and inspect it
example <- imurun_copy_example(tempdir())

# Read and validate without fitting
inputs <- read_inputs(example)
validate_inputs(inputs)

# Or run the whole pipeline (adds a results sheet to the workbook)
run_fit(example)
```

See [`?run_fit`](https://accidda.github.io/imuRUN/reference/run_fit.md),
[`?read_inputs`](https://accidda.github.io/imuRUN/reference/read_inputs.md),
[`?validate_inputs`](https://accidda.github.io/imuRUN/reference/validate_inputs.md),
and
[`?IMURUN_SCHEMA`](https://accidda.github.io/imuRUN/reference/IMURUN_SCHEMA.md)
for details, and the [package
website](https://accidda.github.io/imuRUN/) for the full reference.

## Related

`imuRUN` is part of the `imu*` family and fronts
[`imuGAP`](https://github.com/ACCIDDA/imuGAP), the underlying
model-fitting package.
