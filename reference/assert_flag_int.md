# Coerce a command-line flag value to a whole number

Validates a sampler-option flag value the same friendly way the input
schema is checked: a clear, single-line message naming the flag and the
offending value, rather than a raw coercion warning. Values at or above
`min` are accepted; `--seed` uses `min = 0` (0 is a valid, conventional
seed), while the count flags use `min = 1`.

## Usage

``` r
assert_flag_int(val, flag, min = 1L)
```

## Arguments

- val:

  the raw string value supplied after the flag.

- flag:

  the flag name (e.g. `"--iter"`), used in the error message.

- min:

  the smallest allowed value.

## Value

`val` as an integer no smaller than `min`.
