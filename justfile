PKG := "imuRUN"
VERSION := `Rscript -e "cat(read.dcf('DESCRIPTION')[,'Version'])"`
TARBALL := PKG + "_" + VERSION + ".tar.gz"

default: clean format lint docs test

[unix]
[doc('Clean up auxiliary files and directories')]
clean:
	rm -f  *.tar.gz
	rm -rf *.Rcheck/ ..Rcheck/
	rm -rf .Rproj.user/

[doc('Regenerate roxygen output: man/*.Rd')]
docs:
	Rscript -e 'roxygen2::roxygenize()'

[doc('Format R code using air')]
format:
	air format .

[doc('Check R code using air and lintr')]
lint: lintair lintr

[doc('Check R code using air')]
lintair:
	air format . --check

[doc('Check R code using lintr')]
lintr:
	#!/usr/bin/env Rscript
	if (require(devtools)) devtools::load_all() else stop("missing 'devtools'")
	if (require(lintr))	lintr::lint_package() else stop("missing 'lintr'")

[doc('Run unit tests using devtools')]
test:
	#!/usr/bin/env Rscript
	library(devtools)
	devtools::test()

[doc('Run unit tests using devtools, stopping on first failure')]
test-fast:
	#!/usr/bin/env Rscript
	library(devtools)
	devtools::test(stop_on_failure=TRUE)

[doc('Check test coverage using covr')]
coverage:
	#!/usr/bin/env Rscript
	if (require(covr)) print(covr::package_coverage()) else stop("missing 'covr'")

[doc('Check spelling across documentation and vignettes using spelling')]
spell:
	#!/usr/bin/env Rscript
	if (require(spelling)) spelling::spell_check_package() else stop("missing 'spelling'")

[group('renv')]
[doc('Install package dependencies using renv')]
renv-install:
	#!/usr/bin/env Rscript
	library(renv)
	renv::install(dependencies='most')

[group('renv')]
[doc('Install and update dependencies using renv')]
renv-update:
	#!/usr/bin/env Rscript
	library(renv)
	renv::install(dependencies='most')
	renv::update()

[group('renv')]
[doc('Install, update, and snapshot new updates using renv')]
renv-snapshot:
	#!/usr/bin/env Rscript
	library(renv)
	renv::install(dependencies='most')
	renv::update()
	renv::snapshot()

[doc('Install development version of imuRUN')]
install:
	R CMD INSTALL .

[doc('Remove development version of imuRUN')]
remove:
	R CMD REMOVE {{ PKG }}

[group('data')]
[doc('Regenerate bundled template, example workbooks, and test fixtures from data-raw/make_workbooks.R')]
data:
	Rscript data-raw/make_workbooks.R

[doc('Build a tar.gz artifact')]
build:
	R CMD build .

[doc('Check the built tar.gz artifact')]
check: build
	R CMD check {{ TARBALL }} --no-manual --no-tests

[doc('Check the built tar.gz artifact using CRAN settings')]
check-cran: build
	R CMD check {{ TARBALL }} --as-cran

[doc('Render vignettes to PDF and HTML locally')]
render:
	#!/usr/bin/env Rscript
	if (!require(rmarkdown)) stop("missing 'rmarkdown'")
	if (require(devtools)) devtools::load_all(quiet = TRUE)
	files <- list.files("vignettes", pattern = "\\.Rmd$", full.names = TRUE)
	for (f in files) {
	  message("Rendering ", f, " to HTML...")
	  rmarkdown::render(f, output_format = "html_document", quiet = TRUE)
	  message("Rendering ", f, " to PDF...")
	  rmarkdown::render(f, output_format = "pdf_document", quiet = TRUE)
	}

[group('site')]
[doc('Fast build of pkgdown documentation site into docs/ (no package reinstallation)')]
site: docs
	#!/usr/bin/env Rscript
	if (!requireNamespace("pkgdown", quietly = TRUE)) stop("missing 'pkgdown'")
	pkgdown::build_site_github_pages(new_process = FALSE, install = FALSE)

[group('site')]
[doc('Alias for just site (fast documentation build)')]
site-quick: site

[group('site')]
[doc('Full build of pkgdown site with package reinstallation so vignettes see updated data/code')]
site-full: install docs
	#!/usr/bin/env Rscript
	if (!requireNamespace("pkgdown", quietly = TRUE)) stop("missing 'pkgdown'")
	pkgdown::build_site_github_pages(new_process = FALSE, install = FALSE)

[group('site')]
[doc('Preview the pkgdown documentation site on localhost using httpuv')]
site-preview port="8000": site
	#!/usr/bin/env Rscript
	if (!requireNamespace("httpuv", quietly = TRUE)) stop("missing 'httpuv'")
	port_num <- as.integer("{{ port }}")
	message(sprintf("Serving pkgdown site at http://127.0.0.1:%d/ (Ctrl+C to stop)", port_num))
	httpuv::runStaticServer(dir = "docs", host = "127.0.0.1", port = port_num, browse = TRUE)
