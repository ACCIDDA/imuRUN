# Generates the two shipped .xlsx workbooks + test fixtures:
#   * inst/templates/imurun_template.xlsx -- blank, headers only + instructions
#   * inst/extdata/imurun_example.xlsx    -- a small filled example carved from
#                                            imuGAP's *_sim datasets
#   * tests/testthat/fixtures/example*.xlsx
#
# Input model (#26): imurun has no populations sheet. Each observation carries
# its own loc_id/cohort/age/dose, and imurun derives the imuGAP populations from
# the observations (one weight-1 row each).
#
# Run from the package root with:  Rscript data-raw/make_workbooks.R
# Requires the 'writexl' package.

if (!requireNamespace("writexl", quietly = TRUE)) {
  stop("data-raw/make_workbooks.R needs the 'writexl' package.")
}
suppressMessages({
  library(imuGAP)
  library(data.table)
})

# The schema (kept in lock-step with R/schema.R).
schema <- list(
  observations = c(
    "obs_id", "loc_id", "cohort", "age", "dose", "positive", "sample_n"
  ),
  locations = c("loc_id", "parent_id")
)

out_template <- file.path("inst", "templates", "imurun_template.xlsx")
out_example <- file.path("inst", "extdata", "imurun_example.xlsx")
dir.create(dirname(out_template), recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(out_example), recursive = TRUE, showWarnings = FALSE)

# --- Blank template ----------------------------------------------------------

empty_sheet <- function(cols) {
  as.data.frame(
    matrix(character(0), ncol = length(cols), dimnames = list(NULL, cols)),
    stringsAsFactors = FALSE
  )
}

instructions <- data.frame(
  field = c(
    "imurun input workbook",
    "",
    "observations sheet",
    "  obs_id",
    "  loc_id",
    "  cohort",
    "  age",
    "  dose",
    "  positive",
    "  sample_n",
    "  censored (optional)",
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
    "One row per observation (a sampled count) and the group it covers.",
    "Unique, non-missing identifier for the observation.",
    "Must match a loc_id in the locations sheet.",
    "Positive integer birth cohort.",
    "Positive integer age.",
    "Integer dose (1 or 2).",
    "Non-negative integer count of positive results.",
    "Positive integer sample size; positive must be <= sample_n.",
    "Leave blank, or 1 to mark a right-censored observation.",
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
# schools beneath it, plus the observations that reference them.
keep_locs <- c("State", "Scruggs", "Chickadee Elementary", "Nuthatch Academy")
ex_loc <- loc_sim[loc_id %in% keep_locs]

# Observations whose populations reference only the kept locations.
ok_obs_ids <- pop_sim[, .(ok = all(loc_id %in% keep_locs)), by = obs_id][
  ok == TRUE, obs_id
]
# Keep it small and deterministic.
ex_obs_ids <- head(sort(ok_obs_ids), 12L)

# imurun's limited model is one population row per observation: take the first
# population row per obs_id and merge its loc/cohort/age/dose onto the counts.
pop_one <- pop_sim[obs_id %in% ex_obs_ids][, .SD[1L], by = obs_id]
ex_obs <- merge(
  obs_sim[obs_id %in% ex_obs_ids, .(obs_id, positive, sample_n)],
  pop_one[, .(obs_id, loc_id, cohort, age, dose)],
  by = "obs_id"
)
setcolorder(ex_obs, schema$observations)
ex_obs <- as.data.frame(ex_obs, stringsAsFactors = FALSE)
loc_cols <- schema$locations
ex_loc <- as.data.frame(ex_loc[, ..loc_cols], stringsAsFactors = FALSE)

# Sanity check: the example must pass canonicalization the way imurun runs it.
loc_c <- imuGAP::canonicalize_locations(ex_loc)
obs_c <- imuGAP::canonicalize_observations(ex_obs)
pops_raw <- data.frame(
  ex_obs[, c("obs_id", "loc_id", "cohort", "age", "dose")],
  weight = 1,
  stringsAsFactors = FALSE
)
imuGAP::canonicalize_populations(
  pops_raw, obs_c, loc_c,
  max_cohort = max(ex_obs$cohort),
  max_age = max(ex_obs$age)
)

writexl::write_xlsx(
  list(observations = ex_obs, locations = ex_loc),
  path = out_example
)
message("Wrote ", out_example,
        " (", nrow(ex_obs), " obs, ", nrow(ex_loc), " loc)")

# --- Test fixtures -----------------------------------------------------------
# Mirror the example into tests/testthat as the golden fixture, plus a corrupted
# copy that should fail validation.
fixture_dir <- file.path("tests", "testthat", "fixtures")
dir.create(fixture_dir, recursive = TRUE, showWarnings = FALSE)
file.copy(out_example, file.path(fixture_dir, "example.xlsx"), overwrite = TRUE)

# Corrupted copy: rename a required column and blank out a numeric with a string
# -- exercises the structural and numeric validation branches at once.
bad_obs <- ex_obs
names(bad_obs)[names(bad_obs) == "sample_n"] <- "sampleN"  # renamed column
bad_obs$cohort[1] <- "abc"                                 # non-numeric
writexl::write_xlsx(
  list(observations = bad_obs, locations = ex_loc),
  path = file.path(fixture_dir, "example_corrupt.xlsx")
)
message("Wrote test fixtures to ", fixture_dir)
