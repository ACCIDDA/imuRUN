## Test environments

Continuous integration (GitHub Actions, `R-CMD-check.yaml`), each run with
`R CMD check --as-cran`:

- ubuntu-latest, R release / oldrel / devel
- windows-latest, R release

Local development:

- aarch64-apple-darwin (macOS), R 4.5.x

## R CMD check results

0 errors | 0 warnings | 1 note

This is a new submission.

* **New submission.** First release of imurun to CRAN.

## Dependency note

imurun is a lightweight command-line front-end to the imuGAP model-fitting
package (`Imports: imuGAP`). It therefore cannot be submitted until imuGAP is
itself on CRAN. During development imuGAP is resolved from GitHub via a
`Remotes:` field; that field is dev-only and is stripped from the submission
tarball, as CRAN does not accept `Remotes`.
