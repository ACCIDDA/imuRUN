# imurun 0.0.0.9000

* Initial development version.
* Exported the core CLI engine as ordinary R functions: `run_fit()`,
  `read_inputs()`, `load_by_ext()`, `find_input_file()`, and
  `check_all_inputs()`.
* Added `install_cli()` to put the bundled `imurun` command on the PATH.
* Set up the development infrastructure: R CMD check, lint, test coverage,
  pkgdown, and spelling continuous-integration workflows.
