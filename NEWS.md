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
* Set up the development infrastructure: R CMD check, lint, test coverage,
  pkgdown, and spelling continuous-integration workflows.
