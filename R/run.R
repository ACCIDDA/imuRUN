#' Usage text for the imurun command-line interface
#'
#' @description The help/usage string printed by the bundled `imurun` CLI and
#' by [run_fit()] when invoked with no arguments or a help flag.
#'
#' @keywords internal
USAGE <- "imurun.R -- Minimal CLI for imuGAP model fitting

Usage: imurun <input_dir> [output_dir]
       imurun -h <input_dir>          (validate only, no model fitting)
       imurun -h | --help             (show this message)

input_dir must contain:
  observations.csv (or .rds)      -- columns: obs_id, positive, sample_n
  populations.csv (or .rds)       -- columns: obs_id, loc_id, cohort, age, dose, weight
  locations.csv (or .rds)         -- columns: loc_id, parent_id (hierarchical; see package docs)

Output: fit.rds (raw stanfit object for post-processing).
output_dir defaults to input_dir. Exit codes: 0=success, 1=validation, 2=model, 3=I/O.
"

#' Run the imurun fitting pipeline
#'
#' @description The core engine behind the `imurun` command-line interface,
#' exposed as an ordinary R function. Given a directory of inputs it loads the
#' `observations`, `populations`, and `locations` files (CSV or RDS), validates
#' them against the canonical 'imuGAP' schema, fits the model with
#' `imuGAP::sampling()`, and writes `fit.rds` to the output directory.
#'
#' The function never throws for expected failure modes; instead it prints a
#' human-readable message and returns an integer exit code, so it can drive a
#' shell command directly. The exit-code taxonomy is:
#' \describe{
#'   \item{0}{Success (or usage/validation-only request).}
#'   \item{1}{Schema validation failed.}
#'   \item{2}{Model fitting failed.}
#'   \item{3}{Input/output error (missing directory, unreadable or unwritable
#'     files).}
#' }
#'
#' @param args character vector of command-line style arguments. The first
#'   non-flag argument is the input directory; an optional second is the output
#'   directory (defaults to the input directory). A leading `-h`/`--help`
#'   either prints usage (when alone) or requests validation-only mode (when
#'   followed by an input directory).
#'
#' @return Invisibly, an integer exit code (see Description).
#'
#' @examples
#' # Usage text, no fitting:
#' run_fit(character(0))
#'
#' # Validate inputs only (no Stan toolchain required):
#' dir <- tempfile("imurun_validate_")
#' dir.create(dir)
#' \dontrun{
#' # Fit and write fit.rds (requires a working Stan toolchain):
#' run_fit("path/to/inputs")
#' }
#'
#' @export
run_fit <- function(args = commandArgs(trailingOnly = TRUE)) {
  help_flag <- length(args) > 0 && args[1] %in% c("-h", "--help")

  if (length(args) == 0 || (help_flag && length(args) == 1)) {
    cat(USAGE)
    return(invisible(0L))
  }

  if (help_flag) {
    input_dir <- args[2]
    output_dir <- input_dir
  } else {
    input_dir <- args[1]
    output_dir <- if (length(args) >= 2) args[2] else input_dir
  }

  if (!dir.exists(input_dir)) {
    message("ERROR: Input directory not found: ", input_dir)
    return(invisible(3L))
  }

  err <- tryCatch({ check_all_inputs(input_dir); NULL }, error = identity)
  if (!is.null(err)) {
    message("ERROR: ", conditionMessage(err))
    return(invisible(3L))
  }

  message("[->] Loading inputs...")
  inputs <- tryCatch(read_inputs(input_dir), error = identity)
  if (inherits(inputs, "error")) {
    message("ERROR: ", conditionMessage(inputs))
    return(invisible(3L))
  }
  message("[OK] Inputs loaded.")

  message("[->] Validating schema...")
  canonical <- tryCatch({
    locs <- imuGAP::canonicalize_locations(inputs$locs)
    obs  <- imuGAP::canonicalize_observations(inputs$obs)
    pops <- imuGAP::canonicalize_populations(inputs$pops, obs, locs)
    list(locs = locs, obs = obs, pops = pops)
  }, error = identity)
  if (inherits(canonical, "error")) {
    message("ERROR: ", conditionMessage(canonical))
    return(invisible(1L))
  }
  message("[OK] Schema validated.")

  if (help_flag) {
    message("[OK] Validation passed.")
    return(invisible(0L))
  }

  stan_opts <- imuGAP::stan_options(iter = 2000L, chains = 4L)

  if (!dir.exists(output_dir)) {
    ok <- dir.create(output_dir, recursive = TRUE)
    if (!ok) {
      message("ERROR: Could not create output directory: ", output_dir)
      return(invisible(3L))
    }
  }

  message("[->] Launching imuGAP...")
  fit <- tryCatch(
    imuGAP::sampling(
      observations = canonical$obs, populations = canonical$pops,
      locations = canonical$locs,
      imugap_opts = imuGAP::imugap_options(df = 5L, dose_schedule = c(1L, 4L)),
      stan_opts = stan_opts
    ),
    error = identity
  )
  if (inherits(fit, "error")) {
    message("ERROR: ", conditionMessage(fit))
    return(invisible(2L))
  }
  message("[OK] Model complete.")

  fit_path <- file.path(output_dir, "fit.rds")
  save_err <- tryCatch({ saveRDS(fit, fit_path); NULL }, error = identity)
  if (!is.null(save_err)) {
    message("ERROR: Failed to save output to ", fit_path, ": ",
            conditionMessage(save_err))
    return(invisible(3L))
  }
  message("[OK] Wrote ", fit_path)

  invisible(0L)
}
