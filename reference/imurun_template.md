# Locate the bundled blank template workbook

Resolves the path to the blank `.xlsx` template shipped with imurun (one
sheet per input plus an instructions sheet), via
[`base::system.file()`](https://rdrr.io/r/base/system.file.html).

## Usage

``` r
imurun_template()
```

## Value

character; absolute path to `imurun_template.xlsx`, or `""` if the
package is not installed.

## Examples

``` r
imurun_template()
#> [1] "/tmp/Rtmp4eG4gN/temp_libpath19df28d1175c/imuRUN/templates/imurun_template.xlsx"
```
