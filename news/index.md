# Changelog

## imuRUN 0.1.0

- Initial release.
- Exported the core CLI engine as ordinary R functions:
  [`run_fit()`](https://accidda.github.io/imuRUN/reference/run_fit.md),
  [`read_inputs()`](https://accidda.github.io/imuRUN/reference/read_inputs.md),
  [`load_by_ext()`](https://accidda.github.io/imuRUN/reference/load_by_ext.md),
  [`find_input_file()`](https://accidda.github.io/imuRUN/reference/find_input_file.md),
  and
  [`check_all_inputs()`](https://accidda.github.io/imuRUN/reference/check_all_inputs.md).
- Added
  [`install_cli()`](https://accidda.github.io/imuRUN/reference/install_cli.md)
  to put the bundled `imurun` command on the PATH.
- Added an `.xlsx` workbook input mode:
  [`read_inputs()`](https://accidda.github.io/imuRUN/reference/read_inputs.md)
  now accepts either a directory of CSV/RDS files or a single workbook
  with one sheet per input, via the new
  [`read_workbook()`](https://accidda.github.io/imuRUN/reference/read_workbook.md).
  Missing sheets are reported all at once.
- Pinned the canonical input schema as `IMURUN_SCHEMA` and shipped a
  blank template workbook (`inst/templates/imurun_template.xlsx`) plus a
  small filled example (`inst/extdata/imurun_example.xlsx`) derived from
  imuGAP’s `*_sim` data; resolve them with
  [`imurun_template()`](https://accidda.github.io/imuRUN/reference/imurun_template.md)
  /
  [`imurun_example()`](https://accidda.github.io/imuRUN/reference/imurun_example.md).
- Added
  [`imurun_init()`](https://accidda.github.io/imuRUN/reference/imurun_init.md)
  and
  [`imurun_copy_example()`](https://accidda.github.io/imuRUN/reference/imurun_copy_example.md)
  (and `imurun init` / `imurun example` subcommands) to scaffold
  workbooks into a directory.
- Added
  [`validate_inputs()`](https://accidda.github.io/imuRUN/reference/validate_inputs.md),
  a friendly validation layer over the imuGAP canonicalizers that
  reports every problem at once in spreadsheet terms.
- Observations now describe an inclusive age range (`age_min`/`age_max`,
  labeled *Youngest age* / *Oldest age*) rather than a single `age`. A
  count covering several ages expands to one imuGAP population row per
  age, weighted equally, so those ages form that observation’s coverage
  mixture. A sheet carrying a single `age` column is still read, as a
  one-age range.
- Renamed the observations and target cohort column from *Birth cohort*
  to *Reference cohort*, and documented it as the cohort of the row’s
  oldest age: the cohorts of younger ages are derived so that age plus
  cohort stays constant, matching how the target sheet is already
  expanded. The former *Birth cohort* header is still accepted.
- [`run_fit()`](https://accidda.github.io/imuRUN/reference/run_fit.md)
  now writes a human-readable result, not just `fit.rds`. The target
  sheet is expanded, predicted, and summarized into a `results` sheet in
  the workbook the user supplied, preserving its existing sheets and
  formatting. `--results` writes an amended copy instead, and `--csv`
  writes a results-only CSV. Existing results are not replaced unless
  `--overwrite` is passed. The target and configuration sheets are
  validated before fitting, so a bad row or sampler setting fails
  immediately rather than after the model runs.
- Generated workbooks now include a `configuration` sheet for `iter`,
  `chains`, `seed`, and `warmup`. Command-line flags remain available as
  explicit automation/compatibility overrides.
- Set up the development infrastructure: R CMD check, lint, test
  coverage, pkgdown, and spelling continuous-integration workflows.
