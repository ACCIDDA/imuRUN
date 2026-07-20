# Getting started with imurun

imurun is a beginner-friendly, command-line front-end to the
[imuGAP](https://github.com/ACCIDDA/imuGAP) vaccine-coverage model. You
describe your data in a spreadsheet; imurun validates it, fits the
model, and writes back coverage estimates. No R knowledge is required.

This guide walks the whole happy path: install, try the shipped example,
prepare your own workbook, validate, fit, and read the results.

## Install

``` sh
Rscript -e 'remotes::install_github("ACCIDDA/imurun")'
```

Once imurun is on CRAN you will be able to `install.packages("imurun")`.

To call `imurun` as a bare command on your `PATH` (instead of typing
`Rscript -e ...` every time), follow the one-time CLI setup in [issue
\#16](https://github.com/ACCIDDA/imurun/issues/16). The commands below
are written as if `imurun` is on your `PATH`.

## 1. Run the shipped example first

imurun ships a complete, ready-to-run example so you can see a fit
before preparing your own data. Write a copy into the current folder:

``` sh
imurun example .        # writes imurun_example.xlsx
```

The example is a real, fittable dataset carved from imuGAP’s simulated
data. From R, its installed location is:

``` r

imurun::imurun_example()
#> [1] "/tmp/RtmpaQDzck/temp_libpath18b66c20dba4/imurun/extdata/imurun_example.xlsx"
```

Open it in your spreadsheet program. The first tab is **instructions**;
then come **observations**, **locations**, and an optional **target**
tab.

## 2. Prepare your own workbook

Start from a blank, correctly-headed template:

``` sh
imurun init .           # writes imurun_template.xlsx
```

Fill the tabs (the instructions tab explains every column). imurun uses
plain, human-readable headers:

- **observations** – one row per sampled count: *Location*, *Birth
  cohort*, *Age*, *Dose*, *Vaccinated*, *Sampled* (and an optional
  *Censored*).
- **locations** – the location hierarchy: *Location* and *Parent
  location* (leave *Parent location* blank for the single top-level
  location).
- **target** (optional) – the populations you want coverage predicted
  for: *Location*, *Birth cohort*, *Youngest age*, *Oldest age* (and
  optional *Dose* and *Label*).

Two things imurun handles for you, so you never fill them in:

- there is **no observation id** to invent – imurun assigns one; and
- there is **no populations tab** – imurun builds populations from your
  observations.

If you prefer imuGAP’s own column names (`loc_id`, `cohort`, …), those
work too; and you may delete the instructions tab – imurun only reads
the data sheets.

## 3. Validate before you fit

Check a workbook without fitting anything:

``` sh
imurun -h imurun_example.xlsx
```

From R, that is
[`read_inputs()`](https://accidda.github.io/imurun/reference/read_inputs.md)
followed by
[`validate_inputs()`](https://accidda.github.io/imurun/reference/validate_inputs.md):

``` r

inputs <- imurun::read_inputs(imurun::imurun_example())
imurun::validate_inputs(inputs)
cat("Looks good -- ready to fit.\n")
#> Looks good -- ready to fit.
```

When something is wrong, imurun reports it in plain, spreadsheet terms
rather than an R error. For instance, if a *Sampled* cell holds text
instead of a number:

``` r

broken <- inputs
broken$obs$sample_n[1] <- "not a number"
imurun::validate_inputs(broken)
#> Error:
#> ! Input validation failed with 1 problem(s):
#>   - [observations] column 'sample_n' must be numeric; non-numeric value(s) at row(s): 1
```

Fix the flagged cell(s) in your spreadsheet and validate again.

## 4. Fit the model

``` sh
imurun imurun_example.xlsx
```

This fits the imuGAP model and writes `fit.rds` next to your input. When
the workbook has a **target** tab, imurun also writes a human-readable
results file with a coverage estimate and interval for each requested
population.

Fitting compiles and runs a Stan model, so it can take several minutes.
It is not run in this guide; on success the command exits with status
`0`.

## 5. Read the results

`fit.rds` is the raw fitted model, for anyone who wants to post-process
it in R:

``` r

fit <- readRDS("fit.rds")
```

If you supplied a target tab, the accompanying results file is the part
most users want: one row per requested population, each with its
estimated coverage and an uncertainty interval – no R needed.

## Where next

- **Run `imurun` as a command** (PATH setup, or the `Rscript -e`
  fallback): [issue \#16](https://github.com/ACCIDDA/imurun/issues/16).
- **The model itself**: see the
  [imuGAP](https://github.com/ACCIDDA/imuGAP) documentation.
