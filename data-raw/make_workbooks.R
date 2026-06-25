# Generates the two shipped .xlsx workbooks:
#   * inst/templates/imurun_template.xlsx -- blank, headers only + instructions
#   * inst/extdata/imurun_example.xlsx    -- a small filled example carved from
#                                            imuGAP's *_sim datasets
#
# Run from the package root with:  Rscript data-raw/make_workbooks.R
# Requires the 'writexl' package (Suggests).

if (!requireNamespace("writexl", quietly = TRUE)) {
  stop("data-raw/make_workbooks.R needs the 'writexl' package.")
}
suppressMessages({
  library(imuGAP)
  library(data.table)
})

# The schema (kept in lock-step with R/schema.R).
schema <- list(
  observations = c("obs_id", "positive", "sample_n"),
  populations = c("obs_id", "loc_id", "cohort", "age", "dose", "weight"),
  locations = c("loc_id", "parent_id")
)

out_template <- file.path("inst", "templates", "imurun_template.xlsx")
out_example <- file.path("inst", "extdata", "imurun_example.xlsx")
dir.create(dirname(out_template), recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(out_example), recursive = TRUE, showWarnings = FALSE)

# --- Blank template ----------------------------------------------------------

empty_sheet <- function(cols) {
  df <- as.data.frame(
    matrix(character(0), ncol = length(cols), dimnames = list(NULL, cols)),
    stringsAsFactors = FALSE
  )
  df
}

instructions <- data.frame(
  field = c(
    "imurun input workbook",
    "",
    "observations sheet",
    "  obs_id",
    "  positive",
    "  sample_n",
    "  censored (optional)",
    "",
    "populations sheet",
    "  obs_id",
    "  loc_id",
    "  cohort",
    "  age",
    "  dose",
    "  weight (optional)",
    "",
    "locations sheet",
    "  loc_id",
    "  parent_id",
    "",
    "Validate with:  imurun -h yourfile.xlsx",
    "Fit with:       imurun yourfile.xlsx"
  ),
  description = c(
    "Fill one row per record on each sheet. Do not rename the headers.",
    "",
    "One row per observation (a sampled count).",
    "Unique, non-missing identifier for the observation.",
    "Non-negative integer count of positive results.",
    "Positive integer sample size; positive must be <= sample_n.",
    "Leave blank, or 1 to mark a right-censored observation.",
    "",
    "Cohort/age/dose breakdown each observation covers (one or more rows).",
    "Must match an obs_id in the observations sheet.",
    "Must match a loc_id in the locations sheet.",
    "Positive integer birth cohort.",
    "Positive integer age.",
    "Integer dose (1 or 2).",
    "Positive numeric; weights must sum to 1 within each obs_id (default 1).",
    "",
    "The location hierarchy.",
    "Unique location identifier.",
    "The parent location's loc_id; leave blank for the single root.",
    "",
    "",
    ""
  ),
  stringsAsFactors = FALSE
)

writexl::write_xlsx(
  list(
    observations = empty_sheet(schema$observations),
    populations = empty_sheet(schema$populations),
    locations = empty_sheet(schema$locations),
    instructions = instructions
  ),
  path = out_template
)
message("Wrote ", out_template)

# --- Filled example ----------------------------------------------------------

data(observations_sim, package = "imuGAP")
data(populations_sim, package = "imuGAP")
data(locations_sim, package = "imuGAP")

obs_sim <- as.data.table(observations_sim)
pop_sim <- as.data.table(populations_sim)
loc_sim <- as.data.table(locations_sim)

# Carve a small but valid subset: the root, one mid-level parent, and two
# schools beneath it, plus the observations/populations that reference them.
keep_locs <- c("State", "Scruggs", "Chickadee Elementary", "Nuthatch Academy")
ex_loc <- loc_sim[loc_id %in% keep_locs]

# Observations whose populations reference only the kept locations.
ok_obs_ids <- pop_sim[, .(ok = all(loc_id %in% keep_locs)), by = obs_id][
  ok == TRUE, obs_id
]
# Keep it small and deterministic.
ex_obs_ids <- head(sort(ok_obs_ids), 12L)

pop_cols <- schema$populations
obs_cols <- schema$observations
loc_cols <- schema$locations
ex_pop <- pop_sim[obs_id %in% ex_obs_ids, ..pop_cols]
ex_obs <- obs_sim[obs_id %in% ex_obs_ids, ..obs_cols]

ex_obs <- as.data.frame(ex_obs, stringsAsFactors = FALSE)
ex_pop <- as.data.frame(ex_pop, stringsAsFactors = FALSE)
ex_loc <- as.data.frame(ex_loc[, ..loc_cols], stringsAsFactors = FALSE)

# Sanity check: the example must pass canonicalization.
loc_c <- imuGAP::canonicalize_locations(ex_loc)
obs_c <- imuGAP::canonicalize_observations(ex_obs)
imuGAP::canonicalize_populations(
  ex_pop, obs_c, loc_c,
  max_cohort = max(ex_pop$cohort),
  max_age = max(ex_pop$age)
)

writexl::write_xlsx(
  list(
    observations = ex_obs,
    populations = ex_pop,
    locations = ex_loc
  ),
  path = out_example
)
message("Wrote ", out_example,
        " (", nrow(ex_obs), " obs, ", nrow(ex_pop), " pop, ",
        nrow(ex_loc), " loc)")

# --- Test fixtures -----------------------------------------------------------
# Mirror the example into tests/testthat as the golden fixture, plus a corrupted
# copy that should fail validation.
fixture_dir <- file.path("tests", "testthat", "fixtures")
dir.create(fixture_dir, recursive = TRUE, showWarnings = FALSE)
file.copy(out_example, file.path(fixture_dir, "example.xlsx"), overwrite = TRUE)

# Corrupted copy: rename a required column, blank out a numeric, and reference a
# nonexistent location -- exercises several validation branches at once.
bad_obs <- ex_obs
names(bad_obs)[names(bad_obs) == "sample_n"] <- "sampleN"  # renamed column
bad_pop <- ex_pop
bad_pop$cohort[1] <- "abc"                                  # non-numeric
bad_pop$loc_id[2] <- "Nowhere School"                       # missing loc_id
writexl::write_xlsx(
  list(
    observations = bad_obs,
    populations = bad_pop,
    locations = ex_loc
  ),
  path = file.path(fixture_dir, "example_corrupt.xlsx")
)
message("Wrote test fixtures to ", fixture_dir)
