# imurun 0.1.0

* Initial release.
* Exported the core CLI engine as ordinary R functions: `run_fit()`,
  `read_inputs()`, `load_by_ext()`, `find_input_file()`, and
  `check_all_inputs()`.
* Added `install_cli()` to put the bundled `imurun` command on the PATH.
* Added an `.xlsx` workbook input mode: `read_inputs()` now accepts either a
  directory of CSV/RDS files or a single workbook with one sheet per input,
  via the new `read_workbook()`. Missing sheets are reported all at once.
* Pinned the canonical input schema as `IMURUN_SCHEMA` and shipped a blank
  template workbook (`inst/templates/imurun_template.xlsx`) plus a small filled
  example (`inst/extdata/imurun_example.xlsx`) derived from imuGAP's `*_sim`
  data; resolve them with `imurun_template()` / `imurun_example()`.
* Added `imurun_init()` and `imurun_copy_example()` (and `imurun init` /
  `imurun example` subcommands) to scaffold workbooks into a directory.
* Added `validate_inputs()`, a friendly validation layer over the imuGAP
  canonicalizers that reports every problem at once in spreadsheet terms.
* Observations now describe an inclusive age range (`age_min`/`age_max`,
  labeled *Youngest age* / *Oldest age*) rather than a single `age`. A count
  covering several ages expands to one imuGAP population row per age, weighted
  equally, so those ages form that observation's coverage mixture. A sheet
  carrying a single `age` column is still read, as a one-age range.
* Renamed the observations and target cohort column from *Birth cohort* to
  *Reference cohort*, and documented it as the cohort of the row's oldest age:
  the cohorts of younger ages are derived so that age plus cohort stays
  constant, matching how the target sheet is already expanded. The former
  *Birth cohort* header is still accepted.
* `imurun fit` now writes a human-readable result, not just `fit.rds`. The
  target sheet is expanded, predicted, and summarized into a `results.xlsx`:
  a copy of the input workbook with a `results` sheet giving the posterior
  median and credible interval for each requested population. `--csv` also
  writes a results-only CSV, `--results` sets the workbook path, and imurun
  refuses to overwrite existing output unless `--overwrite` is passed. The
  target sheet is validated before fitting, so a bad target row fails
  immediately rather than after the model runs.
* Set up the development infrastructure: R CMD check, lint, test coverage,
  pkgdown, and spelling continuous-integration workflows.
