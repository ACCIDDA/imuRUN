# Contributing to imuRUN

Thank you for your interest in contributing to imuRUN! This document
explains how to report issues, propose changes, and what to expect from
the CI pipeline when you open a pull request.

## Code of Conduct

All contributors are expected to be respectful and professional in all
interactions — issues, pull requests, code reviews, and discussions.
Constructive feedback is welcome; personal attacks and dismissive
language are not.

## Reporting Bugs

Use the [bug report template](https://github.com/ACCIDDA/imuRUN/issues/new?template=bug_report.yml)
when opening a new issue. It asks for a description, a minimal reprex,
your `sessionInfo()` output, and your operating system.

## Suggesting Features

Use the [feature request template](https://github.com/ACCIDDA/imuRUN/issues/new?template=feature_request.yml).
Describe the use case and, if possible, how the feature fits into the
existing CLI workflow (read inputs -> validate -> run an imuGAP fit).
You can also open a blank issue if neither template fits.

## Submitting Changes

1. **Fork & branch.** Create a feature branch off `main` (e.g.
   `fix/missing-input-message` or `feature/xlsx-input`).
2. **Make your changes.** Follow the style conventions below.
3. **Test locally.** Run `R CMD check` and the test suite before
   pushing (see the commands below).
4. **Open a pull request** against `main` with a clear description of
   what changed and why.

### Development Workflow & `just` Recipes

imuRUN is pure R — it has no compiled code and no Stan toolchain. It
imports [imuGAP](https://CRAN.R-project.org/package=imuGAP), which installs as an
ordinary CRAN dependency.

We use [`just`](https://github.com/casey/just) to automate development tasks:

| Recipe | Description | Equivalent Base Command |
|---|---|---|
| `just` | Run full validation pipeline: clean, format, lint, docs, test | *(compound command)* |
| `just format` | Format R code using `air` | `air format .` |
| `just lint` | Lint R code using `air` and `lintr` | `air format . --check && Rscript -e "lintr::lint_package()"` |
| `just docs` | Regenerate roxygen documentation (`man/*.Rd`) | `Rscript -e "roxygen2::roxygenize()"` |
| `just install` | Install package into local R library | `R CMD INSTALL .` |
| `just test` | Run complete unit test suite via `testthat` / `devtools` | `Rscript -e "devtools::test()"` |
| `just test-fast` | Run tests, stopping on first failure | `Rscript -e "devtools::test(stop_on_failure = TRUE)"` |
| `just coverage` | Measure test coverage via `covr` | `Rscript -e "covr::package_coverage()"` |
| `just spell` | Check spelling across docs and vignettes via `spelling` | `Rscript -e "spelling::spell_check_package()"` |
| `just render` | Render all vignettes to HTML and PDF | `Rscript -e "rmarkdown::render(...)"` |
| `just site` / `just site-quick` | Fast build of `pkgdown` documentation site (no package reinstall) | `Rscript -e "pkgdown::build_site_github_pages(new_process = FALSE, install = FALSE)"` |
| `just site-full` | Full build of `pkgdown` site with package reinstallation | *(compound: install + site)* |
| `just site-preview [port=8000]` | Build and preview pkgdown documentation site on localhost | `Rscript -e "httpuv::runStaticServer(dir = 'docs', port = 8000)"` |
| `just data` | Regenerate bundled template, example workbooks, and test fixtures | `Rscript data-raw/make_workbooks.R` |
| `just build` | Build package `.tar.gz` archive | `R CMD build .` |
| `just check` | Check package archive | `R CMD check imuRUN_*.tar.gz --no-manual --no-tests` |
| `just check-cran` | Check package archive using strict CRAN settings | `R CMD check imuRUN_*.tar.gz --as-cran` |
| `just clean` | Clean up build artifacts and temporary files | `rm -f *.tar.gz && rm -rf *.Rcheck/` |

### Style

- R code is linted with `lintr` (configuration in `.lintr`). Object
  names use `snake_case`; the bundled CLI script in `inst/scripts/` is
  excluded from linting because it is a standalone script.
- Formatting is handled by [air](https://posit-dev.github.io/air/)
  (configuration in `air.toml`). Run `air format .` before committing.
- Do not hand-edit generated files: documentation under `man/` is
  produced by `roxygen2` from the roxygen comments in `R/`.

## What Happens When You Open a PR

Every pull request triggers four GitHub Actions workflows:

| Workflow | What it does |
|----------|-------------|
| **R-CMD-check** | Runs `R CMD check --as-cran` on Ubuntu (release, oldrel, devel) and Windows (release) — 4 jobs. The matrix is intentionally leaner than imuGAP's because imuRUN is pure R (no compiled code). R-devel is allowed to fail without blocking the PR. |
| **lint** | Runs `lintr::lint_package()` and fails the build on any lint. |
| **test-coverage** | Runs the test suite under `covr` and uploads coverage to Codecov. |
| **pkgdown** | Builds the documentation site. On PRs this is a build-only check (no deployment); the site is deployed to GitHub Pages on pushes to `main`, published releases, and manual workflow dispatches. |

All workflows should pass before a PR is merged.

## Questions?

If something is unclear, open an issue or comment on an existing one —
we are happy to help.
