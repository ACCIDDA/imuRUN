# Copy the bundled example workbook into a target directory

Copies the small filled example workbook (derived from 'imuGAP”s `*_sim`
data) into a target directory, so users have a complete, runnable input
to learn from.

## Usage

``` r
imurun_copy_example(path = ".", overwrite = FALSE)
```

## Arguments

- path:

  character; destination directory (created if needed). Defaults to the
  current working directory.

- overwrite:

  logical; if `FALSE` (the default) an existing `imurun_example.xlsx` is
  not clobbered.

## Value

Invisibly, the path to the copied workbook.

## Examples

``` r
dir <- tempfile("imurun_example_")
if (nzchar(imurun_example())) {
  imurun_copy_example(dir)
}
#> Created: /tmp/RtmpL9R3LT/imurun_example_191d2e0e2d4d/imurun_example.xlsx
#> Validate it with:  imurun -h /tmp/RtmpL9R3LT/imurun_example_191d2e0e2d4d/imurun_example.xlsx
```
