# Stan-free core of the by-target prediction feature (issue #14): turn a compact
# `target` sheet into explicit per-target rows, validate it with friendly
# messages, and reduce imuGAP's posterior draws to a median + credible interval
# per target. The actual prediction (imuGAP::predict.imugap_fit -> rstan::gqs)
# and the workbook/CSV writer live elsewhere and require Stan; everything here is
# pure data manipulation and unit-testable without a Stan toolchain.

#' Split a location-list cell into individual location identifiers
#'
#' @description Parses one `loc_id` cell from the `target` sheet, which may name
#' a single location or a `;`- or `,`-separated list. Tokens are trimmed and
#' empty tokens dropped, so `"A; B ,C"` and `"A;;B"` yield `c("A", "B", "C")`
#' and `c("A", "B")` respectively.
#'
#' @param x a single cell value (coerced to character).
#'
#' @return character vector of location identifiers (possibly length zero).
#'
#' @keywords internal
parse_loc_list <- function(x) {
  toks <- trimws(strsplit(as.character(x), "[;,]")[[1]])
  toks <- toks[!is.na(toks)]
  toks[nzchar(toks)]
}

#' Carry non-location target columns forward into blank rows
#'
#' @description Fills the `target` sheet the way a spreadsheet user expects:
#' a row that names only a `loc_id` (leaving `year`, `age_low`, `age_high`,
#' and/or `dose` blank) inherits those values from the nearest row above that
#' supplied them. Each of those columns is carried forward independently, so a
#' run of location-only rows all share the preceding request's year/age/dose.
#' A blank cell with no value above it is left blank (the first row cannot
#' inherit, and a never-supplied `dose` still falls back to the default).
#'
#' @param targets data.frame of target-request rows.
#'
#' @return The `targets` data.frame with blank `year`/`age_low`/`age_high`/
#'   `dose` cells filled from the row above.
#'
#' @keywords internal
fill_target_locf <- function(targets) {
  targets <- as.data.frame(targets, stringsAsFactors = FALSE)
  is_blank <- function(v) is.na(v) | !nzchar(trimws(as.character(v)))
  fill_cols <- intersect(
    c("year", "age_low", "age_high", "dose"),
    names(targets)
  )
  for (col in fill_cols) {
    v <- targets[[col]]
    blank <- is_blank(v)
    for (i in seq_along(v)[-1L]) {
      if (blank[i] && !blank[i - 1L]) {
        v[i] <- v[i - 1L]
        blank[i] <- FALSE
      }
    }
    targets[[col]] <- v
  }
  targets
}

#' Expand a compact target-request sheet into explicit target rows
#'
#' @description Turns each row of the `target` sheet into the explicit
#' `(loc_id, cohort, age, dose)` rows that imuGAP's by-target prediction path
#' consumes. imurun is a thin adapter here: the actual expansion is delegated to
#' [imuGAP::create_target()] in `"snapshot"` mode, one call per target-request
#' row.
#'
#' @details Each row's `year` represents the timing of the target snapshot.
#' `create_target(mode = "snapshot")` fans the row out over its location list
#' (`loc_id`) and inclusive age span (`age_low`..`age_high`), deriving a cohort
#' for each age so that `age + cohort = year` is held constant (`cohort_i = year - age_i`).
#' A blank `dose` cell takes `default_dose` (typically the final dose).
#' Every expanded row is an independent target carrying `weight = 1`. Identical
#' target identities (across rows) are dropped as duplicates, and a unique integer
#' `obs_id` is assigned so the posterior draws can be grouped unambiguously by
#' target.
#'
#' @param targets data.frame of target-request rows (see [IMURUN_TARGET_SCHEMA]).
#' @param default_dose integer; the dose used when a row's `dose` cell is blank.
#'   Typically the model's final dose (`fit$data$n_doses`).
#'
#' @return A data.frame with columns `obs_id`, `target_id`, `loc_id`, `cohort`,
#'   `age`, `dose`, `weight` -- one row per distinct target identity.
#'
#' @seealso [validate_targets()], [summarize_targets()],
#'   [imuGAP::create_target()]
#'
#' @examples
#' tg <- data.frame(
#'   loc_id = "Bunting School; Cardinal Academy",
#'   year = 20, age_low = 1, age_high = 5
#' )
#' expand_targets(tg, default_dose = 2L)
#'
#' @export
expand_targets <- function(targets, default_dose) {
  targets <- fill_target_locf(as.data.frame(targets, stringsAsFactors = FALSE))
  has_dose <- "dose" %in% names(targets)
  has_id <- "target_id" %in% names(targets)

  is_blank <- function(v) is.na(v) || !nzchar(trimws(as.character(v)))

  cols <- c("target_id", "loc_id", "cohort", "age", "dose", "weight")
  rows <- vector("list", nrow(targets))
  for (i in seq_len(nrow(targets))) {
    locs <- parse_loc_list(targets$loc_id[i])
    if (length(locs) == 0) {
      next
    }
    ages <- seq.int(
      as.integer(targets$age_low[i]),
      as.integer(targets$age_high[i])
    )
    dose <- if (has_dose && !is_blank(targets$dose[i])) {
      as.integer(targets$dose[i])
    } else {
      as.integer(default_dose)
    }
    tid <- if (has_id && !is_blank(targets$target_id[i])) {
      as.character(targets$target_id[i])
    } else {
      as.character(i)
    }
    ref_cohort <- as.integer(targets$year[i]) - as.integer(targets$age_high[i])
    grid <- as.data.frame(
      imuGAP::create_target(
        location = locs,
        age = ages,
        cohort = ref_cohort,
        dose = dose,
        mode = "snapshot"
      ),
      stringsAsFactors = FALSE
    )
    grid$target_id <- tid
    rows[[i]] <- grid[, cols]
  }

  empty <- data.frame(
    obs_id = integer(0),
    target_id = character(0),
    loc_id = character(0),
    cohort = integer(0),
    age = integer(0),
    dose = integer(0),
    weight = numeric(0),
    stringsAsFactors = FALSE
  )
  if (length(rows) == 0L) {
    return(empty)
  }

  all_rows <- do.call(rbind, rows)
  if (is.null(all_rows) || nrow(all_rows) == 0L) {
    return(empty)
  }

  # Dedup across target rows: if two requests ask for the same
  # (loc_id, cohort, age, dose), only fit/predict it once. The first target_id
  # seen is kept.
  key <- paste(
    all_rows$loc_id,
    all_rows$cohort,
    all_rows$age,
    all_rows$dose,
    sep = "\r"
  )
  dup <- duplicated(key)
  unique_rows <- all_rows[!dup, , drop = FALSE]

  unique_rows$obs_id <- seq_len(nrow(unique_rows))
  unique_rows <- unique_rows[,
    c("obs_id", "target_id", "loc_id", "cohort", "age", "dose", "weight")
  ]
  rownames(unique_rows) <- NULL
  unique_rows
}

#' Validate target-request rows against model extents and schema
#'
#' @description Checks that `targets` matches [IMURUN_TARGET_SCHEMA], that every
#' named location exists in `loc_ids`, that `age_low <= age_high`, and that the
#' requested ages and derived cohorts fall within `max_age` and `max_cohort`.
#'
#' @param targets data.frame of target requests.
#' @param loc_ids character vector of valid location identifiers.
#' @param max_cohort integer; upper bound on the derived cohort.
#' @param max_age integer; upper bound on the requested age.
#' @param max_dose integer; upper bound on the dose (default 2).
#'
#' @return Invisibly, `targets` on success; raises an error describing all
#'   problems found otherwise.
#'
#' @seealso [expand_targets()], [IMURUN_TARGET_SCHEMA]
#'
#' @examples
#' tg <- data.frame(loc_id = "A;B", year = 12, age_low = 5, age_high = 7)
#' validate_targets(tg, loc_ids = c("A", "B"), max_cohort = 15, max_age = 8)
#'
#' @export
validate_targets <- function(
  targets,
  loc_ids,
  max_cohort,
  max_age,
  max_dose = 2L
) {
  targets <- fill_target_locf(as.data.frame(targets, stringsAsFactors = FALSE))

  problems <- check_sheet_columns(targets, "target", IMURUN_TARGET_SCHEMA)
  for (col in c("year", "age_low", "age_high", "dose")) {
    problems <- c(problems, check_numeric_column(targets, "target", col))
  }
  # Stop on structural/type errors before value checks, which would otherwise
  # raise confusing follow-on problems on columns that are missing or unparsable.
  if (length(problems) > 0) {
    stop(format_validation_error(problems), call. = FALSE)
  }

  year <- suppressWarnings(as.integer(targets$year))
  age_low <- suppressWarnings(as.integer(targets$age_low))
  age_high <- suppressWarnings(as.integer(targets$age_high))
  dose <- if ("dose" %in% names(targets)) {
    suppressWarnings(as.integer(targets$dose))
  } else {
    rep(NA_integer_, nrow(targets))
  }

  for (i in seq_len(nrow(targets))) {
    locs <- parse_loc_list(targets$loc_id[i])
    if (length(locs) == 0) {
      problems <- c(
        problems,
        sprintf("[target] loc_id is blank at row(s): %d", i)
      )
      next
    }
    unknown <- setdiff(locs, loc_ids)
    if (length(unknown) > 0) {
      problems <- c(
        problems,
        sprintf(
          "[target] unknown loc_id(s): %s (row(s): %d)",
          paste(unknown, collapse = ", "),
          i
        )
      )
    }
  }

  bad_span <- which(age_low > age_high)
  if (length(bad_span) > 0) {
    problems <- c(
      problems,
      sprintf(
        "[target] age_low must be <= age_high at row(s): %s",
        paste(utils::head(bad_span, 20L), collapse = ", ")
      )
    )
  }

  ref_cohort <- year - age_high
  bad_cohort_low <- which(ref_cohort < 1L)
  if (length(bad_cohort_low) > 0) {
    problems <- c(
      problems,
      sprintf(
        "[target] year must be greater than age_high so cohort is positive (row(s): %s)",
        paste(utils::head(bad_cohort_low, 20L), collapse = ", ")
      )
    )
  }

  max_derived_cohort <- year - age_low
  bad_cohort_high <- which(max_derived_cohort > max_cohort)
  if (length(bad_cohort_high) > 0) {
    problems <- c(
      problems,
      sprintf(
        paste0(
          "[target] target year %d and youngest age %d expands to cohort %d, beyond ",
          "the model's %d cohorts; adjust target year or youngest age (row(s): %s)"
        ),
        year[bad_cohort_high[1L]],
        age_low[bad_cohort_high[1L]],
        max_derived_cohort[bad_cohort_high[1L]],
        max_cohort,
        paste(utils::head(bad_cohort_high, 20L), collapse = ", ")
      )
    )
  }

  bad_age <- which(age_low < 1L | age_high > max_age)
  if (length(bad_age) > 0) {
    problems <- c(
      problems,
      sprintf(
        "[target] age out of range [1, %d] at row(s): %s",
        max_age,
        paste(utils::head(bad_age, 20L), collapse = ", ")
      )
    )
  }
  bad_dose <- which(!is.na(dose) & (dose < 1L | dose > max_dose))
  if (length(bad_dose) > 0) {
    problems <- c(
      problems,
      sprintf(
        "[target] dose out of range [1, %d] at row(s): %s",
        max_dose,
        paste(utils::head(bad_dose, 20L), collapse = ", ")
      )
    )
  }

  if (length(problems) > 0) {
    stop(format_validation_error(problems), call. = FALSE)
  }
  invisible(targets)
}

#' Reduce posterior draws to a median and credible interval per target
#'
#' @description Collapses the long posterior draws returned by 'imuGAP''s
#' by-target prediction path into one wide row per target: the posterior median
#' and a symmetric credible interval of the predicted coverage probability
#' (`p_obs`). 'imuGAP' returns draws only; this is the small reduction imurun
#' layers on top.
#'
#' @param draws data.frame of posterior draws with (at least) an `obs_id` key
#'   and a `p_obs` column, one row per (draw x target). Any of the identity
#'   columns `target_id`, `loc_id`, `cohort`, `age`, `dose` present are carried
#'   through to the output.
#' @param ci_level numeric in `(0, 1)`; the credible-interval level (default
#'   `0.95`, i.e. the 2.5% and 97.5% quantiles).
#'
#' @return A data.frame with one row per target: the carried identity columns
#'   plus `n_draws`, `est_median`, `est_lower`, `est_upper`, and `ci_level`.
#'
#' @seealso [expand_targets()]
#'
#' @examples
#' draws <- data.frame(
#'   obs_id = 1L, loc_id = "A", cohort = 5L, age = 5L, dose = 2L,
#'   p_obs = seq(0, 1, length.out = 201)
#' )
#' summarize_targets(draws, ci_level = 0.95)
#'
#' @export
summarize_targets <- function(draws, ci_level = 0.95) {
  draws <- as.data.frame(draws, stringsAsFactors = FALSE)
  if (!all(c("obs_id", "p_obs") %in% names(draws))) {
    stop("'draws' must have 'obs_id' and 'p_obs' columns.", call. = FALSE)
  }
  if (
    length(ci_level) != 1L || is.na(ci_level) || ci_level <= 0 || ci_level >= 1
  ) {
    stop("'ci_level' must be a single number in (0, 1).", call. = FALSE)
  }

  alpha <- (1 - ci_level) / 2
  identity_cols <- intersect(
    c("target_id", "loc_id", "cohort", "age", "dose"),
    names(draws)
  )
  ids <- unique(draws$obs_id)

  parts <- lapply(ids, function(id) {
    d <- draws[draws$obs_id == id, , drop = FALSE]
    p <- d$p_obs
    data.frame(
      d[1L, identity_cols, drop = FALSE],
      n_draws = length(p),
      est_median = stats::median(p),
      est_lower = unname(stats::quantile(p, alpha)),
      est_upper = unname(stats::quantile(p, 1 - alpha)),
      ci_level = ci_level,
      row.names = NULL,
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, parts)
  rownames(out) <- NULL
  out
}
