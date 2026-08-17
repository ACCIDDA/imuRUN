# Getting started with imurun

imurun is a spreadsheet-first front-end to the
[imuGAP](https://github.com/ACCIDDA/imuGAP) vaccine-coverage model. It
is aimed at people who are comfortable running a command at the R prompt
but are not power R users: describe the analysis in a workbook, run one
function, and read the coverage estimates back in that workbook.

This guide walks the whole happy path: install, try the shipped example,
prepare your own workbook, validate, fit, and read the results.

## Install

``` r

remotes::install_github("ACCIDDA/imurun")
```

Once imurun is on CRAN you will be able to `install.packages("imurun")`.

An optional command wrapper is also available via
[`install_cli()`](https://accidda.github.io/imurun/reference/install_cli.md),
but it is not required for this guide.

## 1. Run the shipped example first

imurun ships a complete, ready-to-run example so you can see a fit
before preparing your own data. Write a copy into the current folder:

``` r

imurun::imurun_copy_example(".") # writes imurun_example.xlsx
```

The example is a real, fittable dataset carved from imuGAP’s simulated
data. From R, its installed location is:

``` r

imurun::imurun_example()
#> [1] "/tmp/RtmpL9R3LT/temp_libpath191d10805594/imurun/extdata/imurun_example.xlsx"
```

Open it in your spreadsheet program. The first tabs are **instructions**
and **configuration**; then come **observations**, **locations**, and
**target**.

## 2. Prepare your own workbook

Start from a blank, correctly-headed template:

``` r

imurun::imurun_init(".") # writes imurun_template.xlsx
```

Fill the tabs (the instructions tab explains every column). imurun uses
plain, human-readable headers:

- **observations** – one row per sampled count: *Location*, *Reference
  cohort*, *Youngest age*, *Oldest age*, *Dose*, *Vaccinated*, *Sampled*
  (and an optional *Censored*).
- **locations** – the location hierarchy: *Location* and *Parent
  location* (leave *Parent location* blank for the single top-level
  location).
- **target** – the populations you want coverage predicted for:
  *Location*, *Reference cohort*, *Youngest age*, *Oldest age* (and
  optional *Dose* and *Label*).

Two things imurun handles for you, so you never fill them in:

- there is **no observation id** to invent – imurun assigns one; and
- there is **no populations tab** – imurun builds populations from your
  observations.

If you prefer imuGAP’s own column names (`loc_id`, `cohort`, …), those
work too; and you may delete the instructions tab – imurun only reads
the data sheets.

### Configure the fit

The **configuration** sheet keeps the common sampler settings next to
the data:

| Setting  | Default | Meaning                                  |
|:---------|:--------|:-----------------------------------------|
| `iter`   | 2000    | total iterations per chain               |
| `chains` | 4       | number of chains                         |
| `seed`   | blank   | optional random seed for reproducibility |
| `warmup` | blank   | optional warmup iterations per chain     |

Edit the Value column as needed. Command-line flags remain available for
automation and override the workbook when supplied, but most workbook
users do not need them.

### Counts that cover a range of ages

A count is often drawn from a band of ages rather than a single one, so
an observation names an age range. For a single-age count put the same
age in *Youngest age* and *Oldest age*, or simply use one *Age* column
instead – imurun reads that as a one-age range.

When a count does span several ages, imurun splits it evenly across
them: each age contributes an equal share of that observation’s modeled
coverage. The sheet carries no per-age denominators, so an even split is
the only division the input can express; weighting by age-specific
population sizes would need a further column and is not available yet.

*Reference cohort* is the cohort of the **oldest** age in the row.
Younger ages in the same row belong to correspondingly later cohorts, so
a row describes one moment in time rather than one cohort followed
through life. The *target* sheet reads its age span exactly the same
way, which is what lets you write a target over the same span as an
observation and get back an estimate of the same thing.

## 3. Validate before you fit

Check a workbook without fitting anything:

``` r

imurun::run_fit(c("-h", "imurun_example.xlsx"))
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

``` r

imurun::run_fit("imurun_example.xlsx")
```

This fits the imuGAP model and produces two artifacts:

- **your input workbook** gains a `results` sheet. This is the artifact
  most people want; the existing sheets and formatting are preserved.
- **`fit.rds`** – the raw fitted model, for post-processing in R.

Fitting compiles and runs a Stan model, so it can take several minutes.
It is not run in this guide; on success the command exits with status
`0`.

imurun will not replace an existing `results` sheet or `fit.rds`
silently. Pass `--overwrite` when you do want to replace them. You can
also request an amended copy at another path, and optionally write a
results-only CSV:

``` r

imurun::run_fit(c(
  "imurun_example.xlsx",
  "--results", "estimates.xlsx",
  "--csv", "estimates.csv"
))
```

Your target sheet is checked before fitting starts, so a typo in a
target row fails immediately instead of after a long fit.

## 5. Read the results

Open your input workbook and go to the new **results** sheet. It has one
row per requested population (each location, at each age in the span you
asked for):

| Column | Meaning |
|:---|:---|
| `target_id` | your label from the target sheet, if you gave one |
| `loc_id`, `cohort`, `age`, `dose` | which population the row estimates |
| `est_median` | the estimated coverage |
| `est_lower`, `est_upper` | the credible interval around it |
| `ci_level` | the interval’s level (0.95) |
| `n_draws` | posterior draws behind the estimate |

Your `instructions`, `configuration`, `observations`, `locations`, and
`target` sheets remain intact, so the request and settings travel with
the answer.

`fit.rds` is the raw fitted model, for anyone who wants to post-process
it in R:

``` r

fit <- readRDS("fit.rds")
```

## Where next

- **Optional `imurun` command wrapper** (PATH setup): [issue
  \#16](https://github.com/ACCIDDA/imurun/issues/16).
- **The model itself**: see the
  [imuGAP](https://github.com/ACCIDDA/imuGAP) documentation.
