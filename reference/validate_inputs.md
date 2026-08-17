# Validate imurun inputs and report all problems at once

A friendly validation layer over the 'imuGAP' canonicalizers
(`canonicalize_observations()`, `canonicalize_populations()`, and
`canonicalize_locations()`). It reports problems in spreadsheet terms –
naming the offending sheet and, where 'imuGAP' provides it, the
offending column or row – and collects *all* problems it can find rather
than stopping at the first.

Problems detected include:

- missing or renamed required columns (per
  [IMURUN_SCHEMA](https://accidda.github.io/imurun/reference/IMURUN_SCHEMA.md));

- non-numeric count columns (`positive`, `sample_n`, `cohort`,
  `age_min`, `age_max`, `dose`);

- fractional age-span endpoints;

- an inverted age span (`age_min > age_max`);

- age spans outside an explicit `max_age` or too large to expand safely;

- `loc_id` values in `observations` but absent from `locations`;

- `dose`, `cohort`, and `age` values out of range;

- structural location problems (duplicate or missing root, cycles).

The imuGAP populations are constructed from the observations
([`build_populations()`](https://accidda.github.io/imurun/reference/build_populations.md));
there is no populations sheet.

On success the canonicalized frames are returned invisibly. On failure a
single error is raised whose message lists every problem found.

## Usage

``` r
validate_inputs(inputs, max_cohort = NULL, max_age = NULL, max_dose = 2L)
```

## Arguments

- inputs:

  a named list with `obs` and `locs` (as returned by
  [`read_inputs()`](https://accidda.github.io/imurun/reference/read_inputs.md)),
  or a path passed straight to
  [`read_inputs()`](https://accidda.github.io/imurun/reference/read_inputs.md).

- max_cohort, max_age:

  integer upper bounds for the derived `cohort` and `age` values.
  Default to the largest value present in the populations built from
  `observations` – which, for a multi-age observation, reaches past its
  own reference cohort – so that validation does not impose a model
  configuration; supply explicit bounds to enforce a particular
  schedule.

- max_dose:

  integer; the maximum allowed `dose` (default `2`).

## Value

Invisibly, a named list of the canonicalized `obs`, `pops`, and `locs`
frames (`pops` derived from `obs`).

## Examples

``` r
wb <- system.file("extdata", "imurun_example.xlsx", package = "imurun")
if (nzchar(wb) && requireNamespace("readxl", quietly = TRUE)) {
  validate_inputs(read_inputs(wb))
}
```
