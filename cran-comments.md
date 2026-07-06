## Test environments

Continuous integration (GitHub Actions, `R-CMD-check.yaml`), each run with
`R CMD check --as-cran`:

- ubuntu-latest, R release / oldrel / devel
- windows-latest, R release

Local development:

- aarch64-apple-darwin (macOS), R 4.5.3

## R CMD check results

0 errors | 0 warnings | 1 note

This is a new submission.

* **New submission.** First release of imurun to CRAN.

imurun is a pure-R command-line front-end to the 'imuGAP' model-fitting
package. It has no compiled code, no Stan toolchain, and bundles only small
example spreadsheets, so the installed size is modest.

## Downstream dependencies

None on CRAN currently.

## Notes for reviewer

First submission. Points that may be useful to the reviewer:

- imurun imports 'imuGAP' (>= 0.1.0), which is itself a CRAN package; no
  non-CRAN dependencies or Remotes are used.
- Bundled example/template workbooks (`inst/templates/imurun_template.xlsx`,
  `inst/extdata/imurun_example.xlsx`) are small and derived from imuGAP's
  simulated `*_sim` data.
- Citation guidance: see `CITATION.cff` at the repo root for how to cite imurun.
