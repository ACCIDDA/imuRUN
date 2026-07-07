# Changelog

## imurun 0.1.0

- Initial release.
- Exported the core CLI engine as ordinary R functions:
  [`run_fit()`](https://accidda.github.io/imurun/reference/run_fit.md),
  [`read_inputs()`](https://accidda.github.io/imurun/reference/read_inputs.md),
  [`load_by_ext()`](https://accidda.github.io/imurun/reference/load_by_ext.md),
  [`find_input_file()`](https://accidda.github.io/imurun/reference/find_input_file.md),
  and
  [`check_all_inputs()`](https://accidda.github.io/imurun/reference/check_all_inputs.md).
- Added
  [`install_cli()`](https://accidda.github.io/imurun/reference/install_cli.md)
  to put the bundled `imurun` command on the PATH.
- Added an `.xlsx` workbook input mode:
  [`read_inputs()`](https://accidda.github.io/imurun/reference/read_inputs.md)
  now accepts either a directory of CSV/RDS files or a single workbook
  with one sheet per input, via the new
  [`read_workbook()`](https://accidda.github.io/imurun/reference/read_workbook.md).
  Missing sheets are reported all at once.
- Pinned the canonical input schema as `IMURUN_SCHEMA` and shipped a
  blank template workbook (`inst/templates/imurun_template.xlsx`) plus a
  small filled example (`inst/extdata/imurun_example.xlsx`) derived from
  imuGAP’s `*_sim` data; resolve them with
  [`imurun_template()`](https://accidda.github.io/imurun/reference/imurun_template.md)
  /
  [`imurun_example()`](https://accidda.github.io/imurun/reference/imurun_example.md).
- Added
  [`imurun_init()`](https://accidda.github.io/imurun/reference/imurun_init.md)
  and
  [`imurun_copy_example()`](https://accidda.github.io/imurun/reference/imurun_copy_example.md)
  (and `imurun init` / `imurun example` subcommands) to scaffold
  workbooks into a directory.
- Added
  [`validate_inputs()`](https://accidda.github.io/imurun/reference/validate_inputs.md),
  a friendly validation layer over the imuGAP canonicalizers that
  reports every problem at once in spreadsheet terms.
- Set up the development infrastructure: R CMD check, lint, test
  coverage, pkgdown, and spelling continuous-integration workflows.
