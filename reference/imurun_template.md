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
#> [1] "/tmp/RtmpAzY3zO/temp_libpath1a855e55e2a0/imuRUN/templates/imurun_template.xlsx"
```
