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
  observations.csv (or .rds)      -- columns: obs_id, loc_id, cohort, age_min, age_max, dose,
                                     positive, sample_n. cohort is the reference cohort, that of
                                     age_max; a single 'age' column works for a one-age count.
  locations.csv (or .rds)         -- columns: loc_id, parent_id (hierarchical; see package docs)

A workbook must have one sheet per input with the same column names
(run 'imurun init' to get a correctly-headed template).

Sampler options belong in the workbook's 'configuration' sheet. The generated
template supplies iter=2000 and chains=4; seed and warmup may be left blank.
For automation and older workflows, these flags override the sheet:
  --iter N        total iterations per chain (default 2000)
  --chains N      number of chains (default 4)
  --seed N        random seed for reproducibility
  --warmup N      warmup iterations per chain
Flags may appear anywhere and may be written --iter N or --iter=N.

Output options:
  --results PATH  write an amended copy instead of updating the input workbook
  --csv PATH      also write a results-only CSV
  --overwrite     replace existing output files (otherwise imurun refuses)

Output: for workbook input, a 'results' sheet of per-target medians and credible
intervals is added to that workbook; directory input writes results.xlsx.
fit.rds is also written for post-processing. output_dir defaults to input_dir.
Exit codes: 0=success, 1=validation, 2=model, 3=I/O.
"

# Credible-interval level for the reported target estimates. imuGAP returns
# draws; the median and this interval are the reduction imurun reports.
IMURUN_CI_LEVEL <- 0.95

# The imuGAP model options imurun fits with. Hoisted out of run_fit() so the
# dose schedule has one definition: its length is the model's dose count, which
# is both the default dose for a blank `target` cell and the upper bound
# validate_targets() checks against.
IMURUN_IMUGAP_ARGS <- list(df = 5L, dose_schedule = c(1L, 4L))

# imurun's sampler defaults. The generated workbook repeats these values in its
# configuration sheet, and CLI flags remain a compatibility/automation override.
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
#' @description Lets a user set 'Stan' sampler settings from a command wrapper:
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

#' Read sampler settings from a workbook configuration sheet
#'
#' @description Parses the `Setting`/`Value` rows supplied in generated imurun
#' workbooks. Recognized settings are `iter`, `chains`, `seed`, and `warmup`;
#' blank values use the package/default value. The same whole-number rules as
#' the compatibility CLI flags apply. Unknown or repeated populated settings
#' are reported rather than silently ignored.
#'
#' @param config optional data.frame read from the `configuration` sheet.
#'
#' @return A named list of sampler-option overrides.
#'
#' @keywords internal
parse_sampler_config <- function(config) {
  if (is.null(config) || nrow(config) == 0L) {
    return(list())
  }
  names_lower <- tolower(trimws(names(config)))
  setting_col <- match("setting", names_lower)
  value_col <- match("value", names_lower)
  if (is.na(setting_col) || is.na(value_col)) {
    stop(
      "[configuration] expected columns 'Setting' and 'Value'.",
      call. = FALSE
    )
  }

  settings <- tolower(trimws(as.character(config[[setting_col]])))
  raw_values <- config[[value_col]]
  values <- trimws(as.character(raw_values))
  populated <- !is.na(raw_values) & nzchar(values)
  missing_name <- which(populated & (is.na(settings) | !nzchar(settings)))
  if (length(missing_name) > 0L) {
    stop(
      sprintf(
        "[configuration] missing Setting at row(s): %s",
        paste(utils::head(missing_name, 20L), collapse = ", ")
      ),
      call. = FALSE
    )
  }

  allowed <- c("iter", "chains", "seed", "warmup")
  unknown <- which(populated & !settings %in% allowed)
  if (length(unknown) > 0L) {
    stop(
      sprintf(
        "[configuration] unknown setting(s): %s",
        paste(unique(settings[unknown]), collapse = ", ")
      ),
      call. = FALSE
    )
  }
  duplicate <- unique(settings[populated & duplicated(settings)])
  if (length(duplicate) > 0L) {
    stop(
      sprintf(
        "[configuration] setting(s) repeated: %s",
        paste(duplicate, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  mins <- c(iter = 1L, chains = 1L, seed = 0L, warmup = 1L)
  overrides <- list()
  for (i in which(populated)) {
    setting <- settings[[i]]
    overrides[[setting]] <- assert_flag_int(
      values[[i]], sprintf("[configuration] %s", setting), mins[[setting]]
    )
  }
  overrides
}

#' Run the imurun fitting pipeline
#'
#' @description The spreadsheet-first fitting entry point, also used by the
#' optional `imurun` command wrapper. Given a workbook or directory of inputs,
#' it validates the observations, locations, target requests, and workbook
#' configuration; fits with `imuGAP::sampling()`; writes `fit.rds`; and adds a
#' human-readable `results` sheet to the supplied workbook (or creates
#' `results.xlsx` for directory input).
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
#' @param args character vector whose first non-flag value is the input workbook
#'   or directory and whose optional second value is the output directory. A
#'   leading `-h`/`--help` either prints usage (when alone) or requests
#'   validation-only mode. Workbook sampler settings come from its
#'   `configuration` sheet; `--iter`, `--chains`, `--seed`, and `--warmup` may
#'   override them for automation. See [parse_sampler_options()].
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
#' # Fit, amend the workbook, and write fit.rds (requires a Stan toolchain):
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

  # Same treatment for the output flags, so they are stripped before the
  # positional input/output parsing and a missing value fails early.
  out_parsed <- tryCatch(parse_output_options(args), error = identity)
  if (inherits(out_parsed, "error")) {
    message("ERROR: ", conditionMessage(out_parsed))
    return(invisible(1L))
  }
  output_opts <- out_parsed$options
  overwrite <- isTRUE(output_opts$overwrite)
  args <- out_parsed$rest

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

  # Workbook configuration is the primary sampler-option surface. Keep the
  # already-supported flags as explicit overrides for scripts and existing
  # callers: defaults < workbook < command line.
  config_overrides <- tryCatch(
    parse_sampler_config(inputs$config),
    error = identity
  )
  if (inherits(config_overrides, "error")) {
    message("ERROR: ", conditionMessage(config_overrides))
    return(invisible(1L))
  }
  sampler_settings <- utils::modifyList(config_overrides, sampler_overrides)

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
      max_cohort <- max(as.integer(pops_raw$cohort))
      max_age <- max(as.integer(pops_raw$age))
      pops <- imuGAP::canonicalize_populations(
        pops_raw, obs, locs,
        max_cohort = max_cohort,
        max_age = max_age
      )
      # Carry the bounds out: the target sheet is validated against the same
      # cohort/age extent the model was actually fit over.
      list(
        locs = locs, obs = obs, pops = pops,
        max_cohort = max_cohort, max_age = max_age
      )
    },
    error = identity
  )
  if (inherits(canonical, "error")) {
    message("ERROR: ", conditionMessage(canonical))
    return(invisible(1L))
  }

  stan_opts <- do.call(
    imuGAP::stan_options,
    utils::modifyList(IMURUN_SAMPLER_DEFAULTS, sampler_settings)
  )

  # The model's dose count: the default for a blank `target` dose cell and the
  # upper bound the target sheet is checked against.
  n_doses <- length(IMURUN_IMUGAP_ARGS$dose_schedule)

  # Validate the target sheet BEFORE fitting. A typo in a target row is a
  # spreadsheet mistake, and finding it after a half-hour fit would be a poor
  # trade when the check costs nothing.
  target_err <- tryCatch(
    {
      validate_targets(
        inputs$target,
        loc_ids = as.character(inputs$locs$loc_id),
        max_cohort = canonical$max_cohort,
        max_age = canonical$max_age,
        max_dose = n_doses
      )
      NULL
    },
    error = identity
  )
  if (!is.null(target_err)) {
    message("ERROR: ", conditionMessage(target_err))
    return(invisible(1L))
  }

  if (!dir.exists(output_dir)) {
    ok <- dir.create(output_dir, recursive = TRUE)
    if (!ok) {
      message("ERROR: Could not create output directory: ", output_dir)
      return(invisible(3L))
    }
  }

  # Workbook inputs are amended in place by default, per the spreadsheet-first
  # workflow. --results requests an amended copy instead; directory inputs have
  # no source workbook and continue to produce results.xlsx.
  results_source <- if (is_workbook) input else NULL
  results_path <- if (!is.null(output_opts$results)) {
    output_opts$results
  } else if (is_workbook) {
    input
  } else {
    file.path(output_dir, "results.xlsx")
  }
  csv_path <- output_opts$csv
  fit_path <- file.path(output_dir, "fit.rds")
  clobber_err <- tryCatch(
    {
      for (p in c(fit_path, csv_path)) {
        assert_no_clobber(p, overwrite)
      }
      assert_results_destination(results_source, results_path, overwrite)
      NULL
    },
    error = identity
  )
  if (!is.null(clobber_err)) {
    message("ERROR: ", conditionMessage(clobber_err))
    return(invisible(3L))
  }

  message("[->] Launching imuGAP...")
  fit <- tryCatch(
    imuGAP::sampling(
      observations = canonical$obs,
      populations = canonical$pops,
      locations = canonical$locs,
      imugap_opts = do.call(imuGAP::imugap_options, IMURUN_IMUGAP_ARGS),
      stan_opts = stan_opts
    ),
    error = identity
  )
  if (inherits(fit, "error")) {
    message("ERROR: ", conditionMessage(fit))
    return(invisible(2L))
  }
  message("[OK] Model complete.")

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

  # By-target predictions. fit.rds is the raw fit object; the amended workbook
  # is the practical deliverable for a user who does not want to post-process
  # the fit in R.
  message("[->] Predicting targets...")
  results <- tryCatch(
    {
      targets <- expand_targets(inputs$target, default_dose = n_doses)
      if (nrow(targets) == 0L) {
        stop("the target sheet expanded to no targets.", call. = FALSE)
      }
      draws <- as_target_draws(stats::predict(fit, target = targets))
      # predict() echoes imuGAP's own identity columns (loc_id/cohort/age/dose)
      # but not `target_id`, which is imurun's label from the target sheet.
      # Carry it across on obs_id so each result row names the request it came
      # from; summarize_targets() then keeps it as an identity column.
      draws$target_id <- targets$target_id[match(draws$obs_id, targets$obs_id)]
      summarize_targets(draws, ci_level = IMURUN_CI_LEVEL)
    },
    error = identity
  )
  if (inherits(results, "error")) {
    message("ERROR: ", conditionMessage(results))
    return(invisible(2L))
  }
  message("[OK] Summarized ", nrow(results), " target(s).")

  # Outputs. The clobber checks already ran before the fit, so pass
  # overwrite = TRUE here: refusing now would discard a completed fit.
  write_err <- tryCatch(
    {
      write_results_workbook(
        inputs, results, results_path,
        overwrite = TRUE, source = results_source
      )
      if (!is.null(csv_path)) {
        write_results_csv(results, csv_path, overwrite = TRUE)
      }
      NULL
    },
    error = identity
  )
  if (!is.null(write_err)) {
    message("ERROR: ", conditionMessage(write_err))
    return(invisible(3L))
  }
  message("[OK] Wrote ", results_path)
  if (!is.null(csv_path)) {
    message("[OK] Wrote ", csv_path)
  }

  invisible(0L)
}
