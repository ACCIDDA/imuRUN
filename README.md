# imurun

> ⚠️ **Under construction.** Scaffolding is in progress — see the [issues](https://github.com/ACCIDDA/imurun/issues).

A beginner-friendly command-line front-end to
[`imuGAP`](https://github.com/ACCIDDA/imuGAP). Hand it your data and it
validates the inputs and runs a fit — no R scripting required.

Part of the `imu*` family: **imuGAP** (the model), **imumap** (geospatial /
dashboard export), and **imurun** (this — the data-file CLI).

## What it does

- Reads imuGAP model inputs from data files — either a directory of
  `observations` / `populations` / `locations` as **CSV or RDS**, or a single
  **Excel workbook** with one sheet per input.
- Validates them against imuGAP's canonical schema, with friendly,
  location-referenced error messages rather than raw R errors.
- Runs `imuGAP::sampling()` and writes the fit out.

The Excel workbook is **one** supported input mode — convenient for people who
don't work in R — not the whole package. The same CLI takes plain CSV/RDS too,
so it fits both spreadsheet users and scripted pipelines.

## Planned usage

```sh
imurun fit data/        # observations/populations/locations as csv or rds
imurun fit study.xlsx   # a filled Excel template
imurun init             # drop a blank template into the current directory
imurun -h data/         # validate inputs only, no fitting
```

## Status

Early scaffolding. The CLI engine is being ported from `imugap-map`
([#7](https://github.com/ACCIDDA/imurun/issues/7)); the Excel input mode, the
template, and the friendly validation layer build on top of it.

## Installation

Once it exists:

```r
# install.packages("remotes")
remotes::install_github("ACCIDDA/imurun")
```

Depends on imuGAP.
