# Sublime Text Syntax Test Action

![Tests](https://github.com/SublimeText/syntax-test-action/workflows/Tests/badge.svg)

Run syntax tests on your Sublime Text syntax definitions
using the ST syntax test binary.

## Usage

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
    strategy:
      matrix:
        include:
          - build: latest  # This is the default
            # packages: master  # If you depend on a default syntax definition
          - build: 3210  # Latest known ST3 build with a test binary
            # packages: st3
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: SublimeText/syntax-test-action@v2
        with:
          build: ${{ matrix.build }}
          default_packages: ${{ matrix.packages }}
```

Note that you must use a separate job
if you want to test multiple ST build
or default packages versions.


## Inputs

| Name                 | Default         | Description                                                                                |
| :------------------- | :-------------- | :----------------------------------------------------------------------------------------- |
| **build**            | `"latest"`      | ST build that should be installed as an integer. Not all builds are available.             |
| **default_packages** | `false`         | Install the [default packages][] and which version (accepts any git ref, e.g. `"master"`). |
| **default_tests**    | `false`         | Whether to keep the tests of the default packages.                                         |
| **package_root**     | `"."`           | Path to the package root that is linked to the testing Packages folder.                    |
| **package_name**     | Repository name | Name to install the package as.                                                            |

**Note that 'latest' currently resolves to the latest ST3 build.**

[default packages]: https://github.com/sublimehq/Packages/


## Changelog

### v2
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
