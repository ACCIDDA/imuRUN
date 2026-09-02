# Copy a bundled workbook into a target directory

Copy a bundled workbook into a target directory

## Usage

``` r
copy_bundled_workbook(
  src,
  path = ".",
  name = NULL,
  overwrite = FALSE,
  label = "workbook"
)
```

## Arguments

- src:

  character; path to the bundled workbook.

- path:

  character; destination directory.

- name:

  character; optional file name. If missing or without `.xlsx`
  extension, `.xlsx` is appended.

- overwrite:

  logical; overwrite an existing file?

- label:

  character; human label used in messages ("template"/"example").

## Value

Invisibly, the resolved path to the copied file.
