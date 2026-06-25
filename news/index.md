# Changelog

## imurun 0.0.0.9000

- Initial development version.
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
- Set up the development infrastructure: R CMD check, lint, test
  coverage, pkgdown, and spelling continuous-integration workflows.
