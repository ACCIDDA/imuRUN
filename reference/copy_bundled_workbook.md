# Copy a bundled workbook into a target directory

Copy a bundled workbook into a target directory

## Usage

``` r
copy_bundled_workbook(src, path, overwrite, label)
```

## Arguments

- src:

  character; path to the bundled workbook.

- path:

  character; destination directory.

- overwrite:

  logical; overwrite an existing file?

- label:

  character; human label used in messages ("template"/"example").

## Value

Invisibly, the path to the copied file.
