# Getting started with imuRUN

**Routine-Use Notebooks** (`imuRUN`) is a spreadsheet-first front-end to
the [imuGAP](https://CRAN.R-project.org/package=imuGAP) vaccine-coverage
model. It is designed for users who want to fit models and generate
coverage estimates with a single R command: describe your data in a
spreadsheet, run one function, and read the coverage estimates directly
back in your workbook.

This guide walks through the full workflow: getting the example
workbook, setting up your own data, checking for errors, fitting the
model, and interpreting results.

## Install

``` r

remotes::install_github("ACCIDDA/imuRUN")
```

Once `imuRUN` is on CRAN, you will be able to run
`install.packages("imuRUN")`.

## 1. Explore the example data

`imuRUN` includes a complete, ready-to-run example so you can see how
the spreadsheet is structured before preparing your own data. Copy it to
your current folder:

``` r

my_example <- imuRUN::imurun_copy_example()
```

> **Tip:** By default,
> [`imurun_copy_example()`](https://accidda.github.io/imuRUN/reference/imurun_copy_example.md)
> writes `imurun_example.xlsx` into your working directory and returns
> its path. You can customize the location or filename by passing `path`
> or `name` (e.g.,
> `imurun_copy_example(path = "data", name = "my_example")`).

Open `imurun_example.xlsx` in Excel or your preferred spreadsheet
program. The file contains five sheets:

1.  **instructions**: A built-in reference guide describing every
    column.
2.  **observations**: Sampled counts and surveyed populations.
3.  **locations**: The hierarchy of geographic or administrative
    locations.
4.  **target**: The populations and time points you want coverage
    predicted for.
5.  **configuration**: Calculation settings (iterations, chains, etc.).

## 2. Prepare your own workbook

When you are ready to use your own data, generate a blank template:

``` r

imuRUN::imurun_init(name = "my_coverage_study")
```

Fill in the sheets with your data:

- **observations**: One row per survey or count:
  - *Location*: Name of the location (must match a location in the
    *locations* sheet).
  - *Observation Year*: Calendar year when the survey/count was recorded
    (e.g., `2024`).
  - *Youngest age* and *Oldest age*: The age span surveyed (put the same
    age in both for a single age, or just use *Youngest age*).
  - *Dose*: Which dose this count represents (e.g., `1` or `2`).
  - *Vaccinated*: Number of individuals found to be vaccinated.
  - *Sampled*: Total number of individuals sampled (*Vaccinated* must be
    \<= *Sampled*).
  - *Censored* (optional): Leave blank, or enter `1` if right-censored.
- **locations**: Your location tree:
  - *Location*: A unique name for each location.
  - *Parent location*: The name of its parent location. Leave *Parent
    location* blank for your single top-level root (e.g., the country or
    state).
- **target**: The specific predictions you want:
  - *Location*: The location(s) to predict (use semicolons for multiple,
    e.g., `District A; District B`).
  - *Target Year*: The calendar year for the prediction snapshot.
  - *Youngest age* and *Oldest age*: The age range you want coverage
    estimated for.
  - *Dose* (optional): Leave blank to predict for the final dose, or
    specify a dose number.
  - *Label* (optional): A descriptive tag echoed into your results
    (e.g., `Schools 2025`).
- **configuration**: Settings for the model fit. The default values
  (2000 iterations, 4 chains) work well for most analyses, so you can
  safely leave this sheet as-is.

### Surveys covering a range of ages

If a survey sampled children across an age band (such as 5-to-10 year
olds), enter `5` for *Youngest age* and `10` for *Oldest age*. `imuRUN`
automatically models equal contributions across the age span behind the
scenes.

### Settings in the configuration sheet

The **configuration** sheet keeps settings alongside your data:

| Setting  | Default | Description                                    |
|:---------|:--------|:-----------------------------------------------|
| `iter`   | 2000    | Total iterations per MCMC chain                |
| `chains` | 4       | Number of parallel chains                      |
| `seed`   | blank   | Optional random seed for exact reproducibility |
| `warmup` | blank   | Optional warmup/burn-in iterations per chain   |

Advanced sampler options from
[`flexstanr::stan_options()`](https://CRAN.R-project.org/package=flexstanr)
(e.g., `cores`, `thin`, `adapt_delta`, `max_treedepth`) and model
options from
[`imuGAP::imugap_options()`](https://CRAN.R-project.org/package=imuGAP)
(e.g., `df`) can also be added as rows here.

## 3. Validate before you fit

Before running a fit, check your workbook to ensure all columns,
locations, and age ranges are valid:

``` r

imuRUN::run_fit(my_example, dryrun = TRUE)
```

Setting `dryrun = TRUE` validates everything without fitting the model.

If you are scripting your analysis in R, you can also validate the
loaded data object directly:

``` r

inputs <- imuRUN::read_inputs(my_example)

if (imuRUN::validate_inputs(inputs)) {
  cat("Looks good -- ready to fit!\n")
}
#> Looks good -- ready to fit!
```

When there is a mistake in the spreadsheet, `imuRUN` reports the exact
sheet, column, and row so you can quickly fix it. For example, if text
is entered in the *Sampled* column:

``` r

broken <- inputs
broken$obs$sample_n[1] <- "not a number"
imuRUN::validate_inputs(broken)
#> Error:
#> ! Input validation failed with 1 problem(s):
#>   - [observations] column 'sample_n' must be numeric; non-numeric value(s) at row(s): 1
```

## 4. Fit the model

When validation passes, fit the model:

``` r

imuRUN::run_fit(my_example)
```

`imuRUN` will fit the coverage model and write a new **results** sheet
into your Excel workbook.

> **Note:** Model fitting runs Markov chain Monte Carlo (MCMC) sampling
> with Stan, which typically takes a few minutes.

### Saving additional output formats

By default,
[`run_fit()`](https://accidda.github.io/imuRUN/reference/run_fit.md)
updates your Excel workbook. You can also export a CSV file or save the
raw model object using the `result` argument:

``` r

# Update the Excel workbook and save a CSV of results
imuRUN::run_fit("imurun_example.xlsx", result = c("xlsx", "csv"))

# Save the raw R fit object for post-processing in R
imuRUN::run_fit("imurun_example.xlsx", result = c("xlsx", "rds"))
```

- `"xlsx"` (default): Adds or updates the **results** sheet in your
  Excel file.
- `"csv"`: Creates a standalone CSV file containing the summarized
  target predictions.
- `"rds"`: Saves the fitted model object (`.rds`) for advanced R
  analysis.

By default,
[`run_fit()`](https://accidda.github.io/imuRUN/reference/run_fit.md)
overwrites existing results when re-run. Set `overwrite = FALSE` if you
prefer to be prompted before any files or sheets are overwritten.

## 5. Read the results

Open your workbook and switch to the **results** sheet. Each row gives
the coverage estimate for a requested population and age:

| Column | Meaning |
|:---|:---|
| `target_id` | Your optional label from the *target* sheet |
| `loc_id`, `cohort`, `age`, `dose` | The specific location, cohort, age, and dose modeled |
| `est_median` | **Estimated coverage** as a proportion (e.g., `0.85` = 85% coverage) |
| `est_lower`, `est_upper` | Lower and upper bounds of the **95% credible interval** |
| `ci_level` | The credible interval level (`0.95`) |

Your original sheets (*instructions*, *observations*, *locations*,
*target*, and *configuration*) remain untouched, keeping your input
data, analysis settings, and results together in a single self-contained
workbook.
