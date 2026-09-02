#' Usage text for the imurun command-line interface
#'
#' @description The help/usage string printed by the bundled `imurun` CLI and
#' by [cli_run_fit()] when invoked with no arguments or a help flag.
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
  observations.csv (or .rds)      -- columns: obs_id, loc_id, year, age_min, age_max, dose,
                                     positive, sample_n.
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
#' @param args character vector of command-line style arguments.
#'
#' @return A list with `overrides` (a named list of the supplied sampler
#'   options, coerced to integers) and `rest` (the arguments with the recognized
#'   sampler flags and their values removed).
#'
#' @keywords internal
parse_sampler_options <- function(args) {
  spec <- c(
    iter = "--iter",
    chains = "--chains",
    seed = "--seed",
    warmup = "--warmup"
  )
  mins <- c(iter = 1L, chains = 1L, seed = 0L, warmup = 1L)
  overrides <- list()
  keep <- rep(TRUE, length(args))
  i <- 1L
  n <- length(args)
  while (i <= n) {
    a <- args[[i]]
    if (is.na(a)) {
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

#' Read calculation settings from a workbook configuration sheet or list
#'
#' @description Parses the `Setting`/`Value` rows supplied in generated imurun
#' workbooks or a configuration list, categorizing them into `stan_opts`
#' (for `flexstanr::stan_options` / `imuGAP::stan_options`) and `imugap_opts`
#' (for `imuGAP::imugap_options`).
#'
#' @param config optional data.frame or list with configuration settings.
#'
#' @return A named list with `stan_opts` and `imugap_opts` sub-lists.
#'
#' @keywords internal
parse_sampler_config <- function(config) {
  if (is.null(config)) {
    return(list(stan_opts = list(), imugap_opts = list()))
  }
  if (is.list(config) && !is.data.frame(config)) {
    stan_opts <- if ("stan_opts" %in% names(config)) {
      config$stan_opts
    } else if ("stan_options" %in% names(config)) {
      config$stan_options
    } else {
      list()
    }
    imugap_opts <- if ("imugap_opts" %in% names(config)) {
      config$imugap_opts
    } else if ("imugap_options" %in% names(config)) {
      config$imugap_options
    } else {
      list()
    }
    return(list(stan_opts = stan_opts, imugap_opts = imugap_opts))
  }
  if (is.data.frame(config)) {
    if (nrow(config) == 0L) {
      return(list(stan_opts = list(), imugap_opts = list()))
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

    stan_arg_names <- c(
      "iter",
      "warmup",
      "thin",
      "chains",
      "cores",
      "seed",
      "init",
      "refresh"
    )
    control_arg_names <- c("adapt_delta", "max_treedepth", "stepsize", "metric")
    imugap_arg_names <- c("df", "dose_schedule", "age_order")
    allowed <- c(stan_arg_names, control_arg_names, imugap_arg_names)

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

    stan_opts <- list()
    control_opts <- list()
    imugap_opts <- list()

    for (i in which(populated)) {
      s <- settings[[i]]
      v <- values[[i]]
      if (s %in% stan_arg_names) {
        if (s %in% c("iter", "warmup", "thin", "chains", "cores", "refresh")) {
          stan_opts[[s]] <- assert_flag_int(
            v,
            sprintf("[configuration] %s", s),
            min = 1L
          )
        } else if (s == "seed") {
          stan_opts[[s]] <- assert_flag_int(
            v,
            sprintf("[configuration] %s", s),
            min = 0L
          )
        } else {
          stan_opts[[s]] <- v
        }
      } else if (s %in% control_arg_names) {
        if (s %in% c("adapt_delta", "stepsize")) {
          num_v <- suppressWarnings(as.numeric(v))
          if (is.na(num_v)) {
            stop(
              sprintf("[configuration] %s must be numeric (got '%s').", s, v),
              call. = FALSE
            )
          }
          control_opts[[s]] <- num_v
        } else if (s == "max_treedepth") {
          control_opts[[s]] <- assert_flag_int(
            v,
            sprintf("[configuration] %s", s),
            min = 1L
          )
        } else {
          control_opts[[s]] <- v
        }
      } else if (s %in% imugap_arg_names) {
        if (s == "df") {
          imugap_opts[[s]] <- assert_flag_int(
            v,
            sprintf("[configuration] %s", s),
            min = 1L
          )
        } else {
          imugap_opts[[s]] <- v
        }
      }
    }
    if (length(control_opts) > 0L) {
      stan_opts$control <- control_opts
    }
    return(list(stan_opts = stan_opts, imugap_opts = imugap_opts))
  }
  list(stan_opts = list(), imugap_opts = list())
}

#' Run the imurun fitting pipeline
#'
#' @description The spreadsheet-first fitting entry point. Given a workbook or
#' directory of inputs, it validates the observations, locations, target
#' requests, and configuration; fits with `imuGAP::sampling()`; and outputs
#' requested deliverables (`results` sheet in workbook, results CSV, and/or `fit.rds`).
#'
#' @param input character path to a `.xlsx` workbook or input directory, or a
#'   pre-loaded `inputs` list (from [read_inputs()]).
#' @param output_dir character path to output directory. Defaults to the directory
#'   of `input` (for workbooks) or `input` itself (for directory inputs).
#' @param dryrun logical; if `TRUE`, validates inputs without fitting the model
#'   and returns `invisible(0L)` on success. Default is `FALSE`.
#' @param result character vector of requested outputs, e.g. `c("xlsx")` (default),
#'   `c("rds")`, `c("csv")`, or combinations/custom paths.
#' @param overwrite logical; if `TRUE` (default), overwrites existing output files.
#'   If `FALSE` and a destination exists, prompts in interactive sessions or stops.
#' @param ... optional arguments passed to override configuration settings.
#'
#' @return Invisibly, an integer exit code (`0L` for success).
#'
#' @examples
#' \dontrun{
#' # Validate inputs only:
#' run_fit("imurun_example.xlsx", dryrun = TRUE)
#'
#' # Fit and update spreadsheet with results:
#' run_fit("imurun_example.xlsx")
#'
#' # Fit and save raw RDS object:
#' run_fit("imurun_example.xlsx", result = c("rds"))
#' }
#'
#' @export
run_fit <- function(
  input,
  output_dir = NULL,
  dryrun = FALSE,
  result = c("xlsx"),
  overwrite = TRUE,
  ...
) {
  # If a character vector of CLI-style arguments was passed as `input`
  if (
    is.character(input) && (length(input) > 1L || any(startsWith(input, "-")))
  ) {
    return(cli_run_fit(input))
  }

  is_workbook <- FALSE
  input_path <- NULL
  input_stem <- "imurun_fit"

  if (is.character(input)) {
    if (length(input) != 1L || !nzchar(trimws(input))) {
      stop("Invalid input path.", call. = FALSE)
    }
    input_path <- normalizePath(input, mustWork = FALSE)
    is_workbook <- tolower(tools::file_ext(input_path)) == "xlsx"
    input_stem <- tools::file_path_sans_ext(basename(input_path))

    if (is_workbook) {
      if (!file.exists(input_path)) {
        stop("Input workbook not found: ", input, call. = FALSE)
      }
      if (is.null(output_dir)) {
        output_dir <- dirname(input_path)
      }
    } else {
      if (!dir.exists(input_path)) {
        stop("Input directory not found: ", input, call. = FALSE)
      }
      check_all_inputs(input_path)
      if (is.null(output_dir)) {
        output_dir <- input_path
      }
    }
    message("[->] Loading inputs...")
    inputs <- read_inputs(input_path)
    message("[OK] Inputs loaded.")
  } else if (is.list(input)) {
    inputs <- input
    if (is.null(output_dir)) {
      output_dir <- "."
    }
  } else {
    stop(
      "'input' must be a workbook path, directory path, or inputs list.",
      call. = FALSE
    )
  }

  # Parse configuration
  parsed_config <- parse_sampler_config(inputs$config)
  extra_args <- list(...)
  if (length(extra_args) > 0L) {
    parsed_config$stan_opts <- utils::modifyList(
      parsed_config$stan_opts,
      extra_args
    )
  }

  message("[->] Validating schema...")
  validate_inputs(inputs)
  message("[OK] Schema validated.")

  # Re-canonicalize for the fit
  locs <- imuGAP::canonicalize_locations(inputs$locs)
  obs <- imuGAP::canonicalize_observations(inputs$obs)
  pops_raw <- build_populations(as.data.frame(
    inputs$obs,
    stringsAsFactors = FALSE
  ))
  max_cohort <- max(as.integer(pops_raw$cohort))
  max_age <- max(as.integer(pops_raw$age))
  pops <- imuGAP::canonicalize_populations(
    pops_raw,
    obs,
    locs,
    max_cohort = max_cohort,
    max_age = max_age
  )

  imugap_args <- utils::modifyList(
    IMURUN_IMUGAP_ARGS,
    parsed_config$imugap_opts
  )
  n_doses <- length(imugap_args$dose_schedule)

  # Validate targets
  validate_targets(
    inputs$target,
    loc_ids = as.character(inputs$locs$loc_id),
    max_cohort = max_cohort,
    max_age = max_age,
    max_dose = n_doses
  )

  if (isTRUE(dryrun)) {
    message("[OK] Validation passed (dryrun mode).")
    return(invisible(0L))
  }

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # Parse output destinations from `result`
  write_xlsx <- FALSE
  write_csv <- FALSE
  write_rds <- FALSE
  xlsx_dest <- NULL
  csv_dest <- NULL
  rds_dest <- NULL

  for (r in result) {
    r_lower <- tolower(trimws(r))
    if (r_lower == "xlsx") {
      write_xlsx <- TRUE
      xlsx_dest <- if (is_workbook) {
        input_path
      } else {
        file.path(output_dir, paste0(input_stem, ".xlsx"))
      }
    } else if (r_lower == "csv") {
      write_csv <- TRUE
      csv_dest <- file.path(output_dir, paste0(input_stem, ".csv"))
    } else if (r_lower == "rds") {
      write_rds <- TRUE
      rds_dest <- file.path(output_dir, paste0(input_stem, ".rds"))
    } else if (grepl("\\.xlsx$", r_lower)) {
      write_xlsx <- TRUE
      xlsx_dest <- r
    } else if (grepl("\\.csv$", r_lower)) {
      write_csv <- TRUE
      csv_dest <- r
    } else if (grepl("\\.rds$", r_lower)) {
      write_rds <- TRUE
      rds_dest <- r
    } else {
      stop("Unrecognized result specification: ", r, call. = FALSE)
    }
  }

  # Overwrite checks
  check_destination <- function(dest, is_wb_self = FALSE) {
    if (is.null(dest)) {
      return()
    }
    if (!file.exists(dest)) {
      return()
    }
    if (is_wb_self) {
      sheets <- openxlsx2::wb_load(dest)$get_sheet_names()
      if (!any(tolower(sheets) == "results")) return()
    }
    if (!isTRUE(overwrite)) {
      if (interactive()) {
        ans <- readline(paste0(
          "Destination '",
          dest,
          "' already exists. Overwrite? [y/N] "
        ))
        if (!tolower(trimws(ans)) %in% c("y", "yes")) {
          stop("Aborted by user.", call. = FALSE)
        }
      } else {
        stop(
          sprintf(
            "Destination '%s' already exists; set overwrite = TRUE to replace.",
            dest
          ),
          call. = FALSE
        )
      }
    }
  }

  if (write_rds) {
    check_destination(rds_dest)
  }
  if (write_csv) {
    check_destination(csv_dest)
  }
  if (write_xlsx) {
    check_destination(
      xlsx_dest,
      is_wb_self = (is_workbook &&
        identical(
          normalizePath(xlsx_dest, mustWork = FALSE),
          normalizePath(input_path, mustWork = FALSE)
        ))
    )
  }

  # Stan options
  stan_settings <- utils::modifyList(
    IMURUN_SAMPLER_DEFAULTS,
    parsed_config$stan_opts
  )
  stan_opts <- do.call(imuGAP::stan_options, stan_settings)

  message("[->] Launching imuGAP...")
  fit <- imuGAP::sampling(
    observations = obs,
    populations = pops,
    locations = locs,
    imugap_opts = do.call(imuGAP::imugap_options, imugap_args),
    stan_opts = stan_opts
  )
  message("[OK] Model complete.")

  if (write_rds && !is.null(rds_dest)) {
    saveRDS(fit, rds_dest)
    message("[OK] Wrote ", rds_dest)
  }

  # Predict targets
  message("[->] Predicting targets...")
  targets <- expand_targets(inputs$target, default_dose = n_doses)
  if (nrow(targets) == 0L) {
    stop("The target sheet expanded to no targets.", call. = FALSE)
  }
  draws <- as_target_draws(stats::predict(fit, target = targets))
  draws$target_id <- targets$target_id[match(draws$obs_id, targets$obs_id)]
  results <- summarize_targets(draws, ci_level = IMURUN_CI_LEVEL)
  message("[OK] Summarized ", nrow(results), " target(s).")

  if (write_xlsx && !is.null(xlsx_dest)) {
    write_results_workbook(
      inputs,
      results,
      xlsx_dest,
      overwrite = TRUE,
      source = if (
        is_workbook &&
          identical(
            normalizePath(xlsx_dest, mustWork = FALSE),
            normalizePath(input_path, mustWork = FALSE)
          )
      ) {
        input_path
      } else {
        NULL
      }
    )
    message("[OK] Wrote ", xlsx_dest)
  }
  if (write_csv && !is.null(csv_dest)) {
    write_results_csv(results, csv_dest, overwrite = TRUE)
    message("[OK] Wrote ", csv_dest)
  }

  invisible(0L)
}

#' Command-line interface dispatcher for imurun
#'
#' @description Parses command-line arguments and dispatches to [run_fit()],
#' [imurun_init()], or [imurun_copy_example()]. Returns an integer exit code.
#'
#' @param args character vector of command-line arguments.
#'
#' @return Invisibly, an integer exit code (`0L` = success, `1L` = validation,
#'   `2L` = model error, `3L` = I/O error).
#'
#' @export
cli_run_fit <- function(args = commandArgs(trailingOnly = TRUE)) {
  parsed <- tryCatch(parse_sampler_options(args), error = identity)
  if (inherits(parsed, "error")) {
    message("ERROR: ", conditionMessage(parsed))
    return(invisible(1L))
  }
  sampler_overrides <- parsed$overrides
  args <- parsed$rest

  out_parsed <- tryCatch(parse_output_options(args), error = identity)
  if (inherits(out_parsed, "error")) {
    message("ERROR: ", conditionMessage(out_parsed))
    return(invisible(1L))
  }
  output_opts <- out_parsed$options
  overwrite <- isTRUE(output_opts$overwrite)
  args <- out_parsed$rest

  looks_flag <- !is.na(args) & startsWith(args, "-")
  unknown <- setdiff(args[looks_flag], c("-h", "--help"))
  if (length(unknown) > 0) {
    message(
      "ERROR: unknown option(s): ",
      paste(unknown, collapse = ", "),
      ". See 'imurun --help'."
    )
    return(invisible(1L))
  }

  help_flag <- length(args) > 0 && args[1] %in% c("-h", "--help")

  if (length(args) == 0 || (help_flag && length(args) == 1)) {
    cat(USAGE)
    return(invisible(0L))
  }

  # Subcommands
  if (args[1] %in% c("init", "example")) {
    target <- if (length(args) >= 2) args[2] else "."
    copier <- if (args[1] == "init") imurun_init else imurun_copy_example
    res <- tryCatch(copier(target, overwrite = overwrite), error = identity)
    if (inherits(res, "error")) {
      message("ERROR: ", conditionMessage(res))
      return(invisible(3L))
    }
    return(invisible(0L))
  }

  input <- if (help_flag) args[2] else args[1]
  output_dir <- if (!help_flag && length(args) >= 2) args[2] else NULL

  result_spec <- "xlsx"
  if (!is.null(output_opts$results)) {
    result_spec <- c(result_spec, output_opts$results)
  }
  if (!is.null(output_opts$csv)) {
    result_spec <- c(result_spec, output_opts$csv)
  }

  res <- tryCatch(
    do.call(
      run_fit,
      c(
        list(
          input = input,
          output_dir = output_dir,
          dryrun = help_flag,
          result = result_spec,
          overwrite = overwrite
        ),
        sampler_overrides
      )
    ),
    error = identity
  )

  if (inherits(res, "error")) {
    msg <- conditionMessage(res)
    message("ERROR: ", msg)
    if (grepl("validation|schema|setting|column", msg, ignore.case = TRUE)) {
      return(invisible(1L))
    } else if (grepl("Stan|model|sampling|predict", msg, ignore.case = TRUE)) {
      return(invisible(2L))
    } else {
      return(invisible(3L))
    }
  }
  invisible(0L)
}
