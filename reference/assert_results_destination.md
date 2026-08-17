# Check whether an amended workbook destination is safe to write

A source workbook may also be the destination: that is the normal
workbook workflow, where imurun adds a `results` sheet to the file the
user supplied. In that case the input file's existence is expected, and
the clobber check applies to an existing `results` sheet instead. For a
distinct destination, the ordinary file-level clobber rule still
applies.

## Usage

``` r
assert_results_destination(source, path, overwrite = FALSE)
```

## Arguments

- source:

  optional path to the workbook being amended.

- path:

  destination workbook path.

- overwrite:

  logical; whether an existing destination/results sheet may be
  replaced.

## Value

Invisibly, `path`.
