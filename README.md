# Sublime Text Syntax Test Action

![Tests](https://github.com/SublimeText/syntax-test-action/workflows/Tests/badge.svg)

Run syntax tests on your Sublime Text syntax definitions
using the ST syntax test binary.

## Usage

### Minimal Example

```yaml
name: Syntax Tests

on:
  push:
    paths:
      - '**.sublime-syntax'
      - '**/syntax_test*'
      - '**.tmPreferences'
  pull_request:
    paths:
      - '**.sublime-syntax'
      - '**/syntax_test*'
      - '**.tmPreferences'

jobs:
  syntax_tests:
    name: Syntax Tests (${{ matrix.build }})
    runs-on: ubuntu-latest
    timeout-minutes: 15 # default is 6 hours!
    strategy:
      matrix:
        include:
          - build: latest  # This is the default
            # packages: master  # If you depend on a default syntax definition
          - build: 3210  # Latest known ST3 build with a test binary
            # packages: v3189   # Latest ST3 tag on the Packages repo
    steps:
      - uses: actions/checkout@v3
      - uses: SublimeText/syntax-test-action@v2
        with:
          build: ${{ matrix.build }}
          # default_packages: ${{ matrix.packages }}
```

### Multiple Syntax Package Tests Example

```yaml
name: Multi Package Syntax Tests

on:
  push:
    paths:
      - '**.sublime-syntax'
      - '**/syntax_test*'
      - '**.tmPreferences'
  pull_request:
    paths:
      - '**.sublime-syntax'
      - '**/syntax_test*'
      - '**.tmPreferences'

jobs:
  syntax_tests:
    name: Syntax Tests (${{ matrix.build }})
    runs-on: ubuntu-latest
    timeout-minutes: 15         # default is 6 hours!
    env:
      package_name: My Package  # install name as specified at packagecontrol.io
    strategy:
      matrix:
        include:
          - build: latest       # This is the default
            packages: master    # default packages revision to use
            less_ref: master    # LESS package revision to use
            sass_ref: master    # SASS package revision to use
          - build: 3210         # Latest known ST3 build with a test binary
            packages: v3189     # default packages revision to use
            less_ref: master    # LESS package revision to use
            sass_ref: master    # SASS package revision to use
    steps:
      # Checkout primary package of this repository
      # and all additionally required packages next to each other
      # by specifying `path` for all.
      # `path` should match the package's name from packagecontrol.io
      # as this may be relevant for a package to work porperly.
      - name: Checkout ${{ env.package_name }} (primary package)
        uses: actions/checkout@v3
        with:
          path: ${{ env.package_name }}
      - name: Checkout LESS (dependency)
        uses: actions/checkout@v3
        with:
          repository: danro/LESS-sublime
          ref: ${{ matrix.less_ref }}
          path: LESS
      - name: Checkout Sass/Scss (dependency)
        uses: actions/checkout@v3
        with:
          repository: braver/SublimeSass
          ref: ${{ matrix.sass_ref }}
          path: Sass
      # Run syntax test for primary package
      # after installing default and additional packages
      - name: Run Syntax Tests for Sublime Text ${{ matrix.build }}
        uses: SublimeText/syntax-test-action@v2
        with:
          build: ${{ matrix.build }}
          package_name: ${{ env.package_name }}
          package_root: ${{ env.package_name }}
          default_packages: ${{ matrix.packages }}
          default_tests: false  # default
          additional_packages: LESS,Sass
          additional_tests: false  # default
```

> **Note**
> You must use a separate job
> if you want to test multiple ST build
> or default packages versions.

> **Warning**
> It is important that you checkout your dependencies
> to a folder that is separate from your `package_root`,
> otherwise the dependency packages placed in a subfolder
> would be treated (and tested) as a part of your package.


## Inputs

| Name                    | Default         | Description                                                                                |
| :---------------------- | :-------------- | :----------------------------------------------------------------------------------------- |
| **build**               | `"latest"`      | ST build that should be installed as an integer. Not all builds are available.             |
| **default_packages**    | `false`         | Install the [default packages][] and which version (accepts any git ref, e.g. `"master"`). |
| **default_tests**       | `false`         | Whether to keep the tests of the default packages.                                         |
| **additional_packages** | `""`            | Comma-separated list of paths to additionally checked out packages to install (e.g.: `LESS,third-party/Sass`). Uses the folders' base names as the package names to install as. |
| **additional_tests**    | `false`         | Whether to keep the tests of the additional packages.                                      |
| **package_root**        | `"."`           | Path to the package root that is linked to the testing Packages folder.                    |
| **package_name**        | Repository name | Name to install the package as.                                                            |

[default packages]: https://github.com/sublimehq/Packages/


## Changelog

### v2

### v2.2 (2023-01-08)

- Support linking of multiple additional third-party packages
  via `additional_packages` and `additional_tests`.
  (@deathaxe, #12, #16)

### v2.1 (2021-06-07)

- Treat `'latest'` as an ST4 build now that the upstream URL has been updated.
- Group dependency installation, if necessary.

### v2.0 (2020-08-28)

- Updated to new upstream download paths.
- Does not fetch dependencies anymore for 4077+.
- Changed from docker to composite action.

### v1 (2020-06-07)

Initial working version
supporting ST3 and ST4 builds
as well as fetching the default packages.
