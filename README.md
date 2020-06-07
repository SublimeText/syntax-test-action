# Sublime Text Syntax Test Action

![Tests](https://github.com/SublimeText/syntax-test-action/workflows/Tests/badge.svg)

Run syntax tests on your Sublime Text syntax definitions
using the ST syntax test binary.

## Usage

```yaml
name: Syntax Tests

on:
  push:
    branches:
      - master
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
    name: Run Syntax Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: SublimeText/syntax-test-action@v1
        with:
          build: 4073  # or 'latest' for the latest ST3 build
```


## Inputs

| Name                 | Default         | Description                                                                            |
| :------------------- | :-------------- | :------------------------------------------------------------------------------------- |
| **build**            | `"latest"`      | ST build that should be installed. Not all builds are available.                       |
| **default_packages** | `false`         | Install the default packages and which version (accepts any git ref, e.g. `"master"`). |
| **default_tests**    | `false`         | Whether to keep the tests of the default packages.                                     |
| **package_root**     | `"."`           | Path to the package root that is linked to the testing Packages folder.                |
| **package_name**     | Repository name | Name to install the package as.                                                        |

**Note that 'latest' currently resolves to the latest ST3 build.**
