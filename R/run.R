#' Usage text for the imurun command-line interface
#'
#' @description The help/usage string printed by the bundled `imurun` CLI and
#' by [run_fit()] when invoked with no arguments or a help flag.
#'
#' @keywords internal
USAGE <- "imurun.R -- Minimal CLI for imuGAP model fitting

Usage: imurun <input> [output_dir] [sampler options]
       imurun -h <input>              (validate only, no model fitting)
       imurun init [dir]              (write a blank input template workbook)
       imurun example [dir]           (write a filled example workbook)
       imurun -h | --help             (show this message)

<input> is either a directory of CSV/RDS files or a single .xlsx workbook.

A directory must contain:
  observations.csv (or .rds)      -- columns: obs_id, loc_id, cohort, age, dose, positive, sample_n
  locations.csv (or .rds)         -- columns: loc_id, parent_id (hierarchical; see package docs)

A workbook must have one sheet per input with the same column names
(run 'imurun init' to get a correctly-headed template).

Sampler options (each takes a positive whole number; an explicit flag overrides
the default, otherwise the imuGAP defaults are used):
  --iter N        total iterations per chain (default 2000)
  --chains N      number of chains (default 4)
  --seed N        random seed for reproducibility
  --warmup N      warmup iterations per chain
Flags may appear anywhere and may be written --iter N or --iter=N.

Output: fit.rds (raw stanfit object for post-processing).
output_dir defaults to input_dir. Exit codes: 0=success, 1=validation, 2=model, 3=I/O.
"

# imurun's sampler defaults. Overridable per-run via CLI flags (see
# parse_sampler_options()); chains matches imuGAP::stan_options()'s default and
# iter matches rstan's, so `imurun <input>` with no flags fits as before.
IMURUN_SAMPLER_DEFAULTS <- list(iter = 2000L, chains = 4L)

#' Coerce a command-line flag value to a whole number
#'
#' @description Validates a sampler-option flag value the same friendly way the
#' input schema is checked: a clear, single-line message naming the flag and the
#' offending value, rather than a raw coercion warning. Values at or above `min`
#' are accepted; `--seed` uses `min = 0` (0 is a valid, conventional seed), while
#' the count flags use `min = 1`.
#'
#' @param val the raw string value supplied after the flag.
#' @param flag the flag name (e.g. `"--iter"`), used in the error message.
#' @param min the smallest allowed value.
#'
#' @return `val` as an integer no smaller than `min`.
#'
#' @keywords internal
assert_flag_int <- function(val, flag, min = 1L) {
  v <- trimws(as.character(val))
  if (!grepl("^[0-9]+$", v)) {
    stop(
      sprintf("%s must be a whole number (got '%s').", flag, val),
      call. = FALSE
    )
  }
  n <- suppressWarnings(as.integer(v))
  if (is.na(n)) {
    stop(
      sprintf("%s is too large (maximum %d).", flag, .Machine$integer.max),
      call. = FALSE
    )
  }
  if (n < min) {
    stop(
      sprintf("%s must be at least %d (got '%s').", flag, min, val),
      call. = FALSE
    )
  }
  n
}

#' Pull sampler-option overrides out of the command-line arguments
#'
#' @description Lets a non-R user set 'Stan' sampler settings without editing R:
#' it scans `args` for the recognized sampler flags (`--iter`, `--chains`,
#' `--seed`, `--warmup`), each written `--iter N` or `--iter=N`, validates their
#' values, and returns them separated from the remaining (positional) arguments.
#' Precedence is simple: an explicit flag overrides the built-in default; unset
#' options fall back to [imuGAP::stan_options()]'s defaults. Unknown flags are
#' left untouched in `rest` so the caller can handle them.
#'
#' @param args character vector of command-line style arguments.
#'
#' @return A list with `overrides` (a named list of the supplied sampler
#'   options, coerced to integers) and `rest` (the arguments with the recognized
#'   sampler flags and their values removed).
#'
#' @examples
#' parse_sampler_options(c("data.xlsx", "--iter", "4000", "--chains=2"))
#'
#' @export
parse_sampler_options <- function(args) {
  spec <- c(
    iter = "--iter", chains = "--chains", seed = "--seed", warmup = "--warmup"
  )
  # --seed may be 0; the count flags must be at least 1.
  mins <- c(iter = 1L, chains = 1L, seed = 0L, warmup = 1L)
  overrides <- list()
  keep <- rep(TRUE, length(args))
  i <- 1L
  n <- length(args)
  while (i <= n) {
    a <- args[[i]]
    if (is.na(a)) {
      # Not a flag; leave it in `rest` for the caller to reject.
      i <- i + 1L
      next
    }
    matched <- FALSE
    for (nm in names(spec)) {
      flag <- spec[[nm]]
      if (identical(a, flag)) {
        if (i == n) {
          stop(sprintf("%s needs a value.", flag), call. = FALSE)
        }
        overrides[[nm]] <- assert_flag_int(args[[i + 1L]], flag, mins[[nm]])
        keep[i] <- FALSE
        keep[i + 1L] <- FALSE
        i <- i + 2L
        matched <- TRUE
        break
      }
      if (startsWith(a, paste0(flag, "="))) {
        val <- sub(paste0(flag, "="), "", a, fixed = TRUE)
        overrides[[nm]] <- assert_flag_int(val, flag, mins[[nm]])
        keep[i] <- FALSE
        i <- i + 1L
        matched <- TRUE
        break
      }
    }
    if (!matched) {
      i <- i + 1L
    }
  }
  list(overrides = overrides, rest = args[keep])
}

#' Run the imurun fitting pipeline
#'
#' @description The core engine behind the `imurun` command-line interface,
#' exposed as an ordinary R function. Given a directory of inputs it loads the
#' `observations` and `locations` files (CSV or RDS), validates
#' them against the canonical 'imuGAP' schema, fits the model with
#' `imuGAP::sampling()`, and writes `fit.rds` to the output directory.
#'
#' The function never throws for expected failure modes; instead it prints a
#' human-readable message and returns an integer exit code, so it can drive a
#' shell command directly. The exit-code taxonomy is:
#' \describe{
#'   \item{0}{Success (or usage/validation-only request).}
#'   \item{1}{Input validation failed: the schema, or an invalid or unknown
#'     command-line option.}
#'   \item{2}{Model fitting failed.}
#'   \item{3}{Input/output error (missing directory, unreadable or unwritable
#'     files).}
#' }
#'
#' @param args character vector of command-line style arguments. The first
#'   non-flag argument is the input directory; an optional second is the output
#'   directory (defaults to the input directory). A leading `-h`/`--help`
#'   either prints usage (when alone) or requests validation-only mode (when
#'   followed by an input directory). Sampler options (`--iter`, `--chains`,
#'   `--seed`, `--warmup`) may appear anywhere and override the defaults for the
#'   fit; see [parse_sampler_options()].
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
  # Pull sampler-option flags out first so the positional input/output parsing
  # below is not confused by them, and a malformed value fails early with a
  # clear message (exit code 1, alongside schema validation).
  parsed <- tryCatch(parse_sampler_options(args), error = identity)
  if (inherits(parsed, "error")) {
    message("ERROR: ", conditionMessage(parsed))
    return(invisible(1L))
  }
  sampler_overrides <- parsed$overrides
  args <- parsed$rest

  # Reject a mistyped or unknown option instead of silently treating it as a
  # path. The only options imurun accepts are the sampler flags (stripped
  # above) plus the help flag.
  looks_flag <- !is.na(args) & startsWith(args, "-")
  unknown <- setdiff(args[looks_flag], c("-h", "--help"))
  if (length(unknown) > 0) {
    message(
      "ERROR: unknown option(s): ", paste(unknown, collapse = ", "),
      ". See 'imurun --help'."
    )
    return(invisible(1L))
  }

  help_flag <- length(args) > 0 && args[1] %in% c("-h", "--help")

  if (length(args) == 0 || (help_flag && length(args) == 1)) {
    cat(USAGE)
    return(invisible(0L))
  }

  # Subcommands: scaffold a template or copy the example workbook.
  if (args[1] %in% c("init", "example")) {
    target <- if (length(args) >= 2) args[2] else "."
    copier <- if (args[1] == "init") imurun_init else imurun_copy_example
    res <- tryCatch(copier(target), error = identity)
    if (inherits(res, "error")) {
      message("ERROR: ", conditionMessage(res))
      return(invisible(3L))
    }
    return(invisible(0L))
  }

  if (help_flag) {
    input <- args[2]
    output_dir <- input
  } else {
    input <- args[1]
    output_dir <- if (length(args) >= 2) args[2] else input
  }

  is_workbook <- tolower(tools::file_ext(input)) == "xlsx"

  if (is_workbook) {
    if (!file.exists(input)) {
      message("ERROR: Input workbook not found: ", input)
      return(invisible(3L))
    }
    output_dir <- if (help_flag || length(args) < 2) dirname(input) else output_dir
  } else {
    if (!dir.exists(input)) {
      message("ERROR: Input directory not found: ", input)
      return(invisible(3L))
    }
    err <- tryCatch(
      {
        check_all_inputs(input)
        NULL
      },
      error = identity
    )
    if (!is.null(err)) {
      message("ERROR: ", conditionMessage(err))
      return(invisible(3L))
    }
  }

  message("[->] Loading inputs...")
  inputs <- tryCatch(read_inputs(input), error = identity)
  if (inherits(inputs, "error")) {
    message("ERROR: ", conditionMessage(inputs))
    return(invisible(3L))
  }
  message("[OK] Inputs loaded.")

  message("[->] Validating schema...")
  validated <- tryCatch(validate_inputs(inputs), error = identity)
  if (inherits(validated, "error")) {
    message("ERROR: ", conditionMessage(validated))
    return(invisible(1L))
  }
  message("[OK] Schema validated.")

  if (help_flag) {
    message("[OK] Validation passed.")
    return(invisible(0L))
  }

  # Re-canonicalize for the fit. imurun has no populations sheet: the imuGAP
  # populations are derived from the observations (one weight-1 row each).
  canonical <- tryCatch(
    {
      locs <- imuGAP::canonicalize_locations(inputs$locs)
      obs <- imuGAP::canonicalize_observations(inputs$obs)
      pops_raw <- build_populations(
        as.data.frame(inputs$obs, stringsAsFactors = FALSE)
      )
      pops <- imuGAP::canonicalize_populations(
        pops_raw, obs, locs,
        max_cohort = max(as.integer(pops_raw$cohort)),
        max_age = max(as.integer(pops_raw$age))
      )
      list(locs = locs, obs = obs, pops = pops)
    },
    error = identity
  )
  if (inherits(canonical, "error")) {
    message("ERROR: ", conditionMessage(canonical))
    return(invisible(1L))
  }

  stan_opts <- do.call(
    imuGAP::stan_options,
    utils::modifyList(IMURUN_SAMPLER_DEFAULTS, sampler_overrides)
  )

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
      observations = canonical$obs,
      populations = canonical$pops,
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
  save_err <- tryCatch(
    {
      saveRDS(fit, fit_path)
      NULL
    },
    error = identity
  )
  if (!is.null(save_err)) {
    message(
      "ERROR: Failed to save output to ",
      fit_path,
      ": ",
      conditionMessage(save_err)
    )
    return(invisible(3L))
  }
  message("[OK] Wrote ", fit_path)

  invisible(0L)
}
