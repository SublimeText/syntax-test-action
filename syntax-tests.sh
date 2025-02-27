#!/usr/bin/env bash

set -e -o pipefail

# folder=".syntax-test-action"
folder="$RUNNER_WORKSPACE/syntax_tests"
packages="$folder/Data/Packages"
mkdir -p "$folder"

resolve_build() {
    local stable_check_url="https://www.sublimetext.com/updates/4/stable_update_check"
    local dev_check_url="https://www.sublimetext.com/updates/4/dev_update_check"
    local build="$INPUT_BUILD"

    if [[ $INPUT_BUILD == stable ]]; then
        build="$(curl -s "$stable_check_url" | jq '.latest_version')"
        echo >&2 "Latest stable build: $build"
    elif [[ $INPUT_BUILD == latest ]]; then
        build="$(curl -s "$dev_check_url" | jq '.latest_version')"
        echo >&2 "Latest dev build: $build"
    fi
    echo "$build"
}

get_url() {
    # Note: The syntax_tests binary for the latest build may not necessarily exist.
    # Fetching from https://download.sublimetext.com/latest/dev/linux/x64/syntax_tests
    # would be more reliable
    # but makes using the same build for the default Packages tag harder.
    local build="$1"
    local template_3000="https://download.sublimetext.com/st3_syntax_tests_build_%s_x64.tar.bz2"
    local template_4000="https://download.sublimetext.com/st_syntax_tests_build_%s_x64.tar.bz2"
    local template_4079="https://download.sublimetext.com/st_syntax_tests_build_%s_x64.tar.xz"

    case $build in
        3*)     printf "$template_3000\n" "$build";;
        4*)     if (( build < 4079 )); then
                    printf "$template_4000\n" "$build";
                else
                    printf "$template_4079\n" "$build";
                fi;;
        *)      echo >&2 "Invalid build reference: $build"; exit 100;;
    esac
}

fetch_binary() {
    read -r url
    local tmpdir
    tmpdir="$(mktemp -d)"
    pushd "$tmpdir"
    wget --content-disposition "$url"
    tar xf st*_syntax_tests_build_*_x64.tar.*
    mv st*_syntax_tests/* "$folder"
    mkdir -vp "$packages"
    popd
    rm -rf "$tmpdir"
}

fetch_default_packages() {
    local binary_build="$1"
    local ref="$INPUT_DEFAULT_PACKAGES"
    if [[ $INPUT_DEFAULT_PACKAGES == false ]]; then
        echo '::debug::Skipping default packages'
        return
    fi
    if [[ $INPUT_DEFAULT_PACKAGES == binary ]]; then
        tag_build="$(get_closest_tag "$binary_build")"
        ref="v$tag_build"
        echo "Using closest tag to binary version: $ref"
    fi

    echo "::group::Fetching default packages (ref: $ref, tests: $INPUT_DEFAULT_TESTS)"
    pushd "$(mktemp -d)"
    wget --content-disposition "https://github.com/sublimehq/Packages/archive/$ref.tar.gz"
    tar xf Packages-*.tar.gz
    if [[ $INPUT_DEFAULT_TESTS != true ]]; then
        find Packages-*/ -type f -name 'syntax_test*' -exec rm -v '{}' \;
    fi
    find Packages-*/ \
        -type d \
        -maxdepth 1 \
        -mindepth 1 \
        -not -name '.github' \
        -exec mv -vt "$packages/" '{}' +
    popd
    echo '::endgroup::'
}

get_closest_tag() {
    local base="$1"
    git ls-remote --tags https://github.com/sublimehq/Packages.git "refs/tags/v????" \
        | cut -f2 \
        | cut -d'v' -f2 \
        | awk "{ if (\$1 <= $base) { print \$1 } }" \
        | sort -r \
        | head -n1
}

link_package() {
    echo 'Linking package'
    ln -vs "$(realpath "$INPUT_PACKAGE_ROOT")" "$packages/$INPUT_PACKAGE_NAME"
}

link_additional_packages() {
    if [[ -z $INPUT_ADDITIONAL_PACKAGES ]]; then
        return
    fi
    IFS=","
    for pkg in $INPUT_ADDITIONAL_PACKAGES; do
        # link additional package into testing dir's Package folder
        echo "Linking third-party package from '$pkg'"
        ln -vs "$(realpath "$pkg")" "$packages/$(basename "$pkg")"
        # drop additional syntax tests
        if [[ $INPUT_ADDITIONAL_TESTS != true ]]; then
            find "$(realpath "$pkg")" -type f -name 'syntax_test*' -exec rm -v '{}' \;
        fi
    done
}

create_dummy_syntaxes() {
    if [[ -z $INPUT_DUMMY_SYNTAXES ]]; then
        return
    fi
    IFS=","
    mkdir "$packages/_Dummy"
    for scope in $INPUT_DUMMY_SYNTAXES; do
        # link additional package into testing dir's Package folder
        echo "Creating dummy syntax for scope '$scope'"
        cat << SYNTAX > "$packages/_Dummy/$scope.sublime-syntax"
%YAML 1.2
---
scope: $scope

contexts:
  main: []
SYNTAX
    done
}

# TODO cache $folder/syntax_test if not latest or stable
build="$(resolve_build)"
echo "::group::Fetching binary (build $build)"
get_url "$build" | fetch_binary
echo '::endgroup::'

# TODO cache $packages based on $INPUT_DEFAULT_PACKAGES not in (master, st3, binary) (or resolve ref to hash)
fetch_default_packages "$build"

link_package

link_additional_packages

create_dummy_syntaxes

echo "::group::Checking syntax test filenames"
for path in $(find . -iname syntax_test*); do
    file="${path/$packages\/$INPUT_PACKAGE_NAME/$INPUT_PACKAGE_ROOT}"
    if echo "$file" | grep -v '/syntax_test_'; then
        echo "::warning file=$file::Syntax test filenames must begin with 'syntax_test_'"
    fi
    if head -n 1 "$path" | grep -vEq '.+\bSYNTAX TEST\b.+".+\.(sublime-syntax|tmLanguage)"'; then
        echo "::warning file=$file::Syntax test file format at https://www.sublimetext.com/docs/syntax.html#testing"
    fi
done
echo '::endgroup::'

# TODO There seems to be some add-matcher workflow command.
#   We could generate/adjust that to only catch files
#   in the installed package,
#   but we may not be able to rewrite the original root path.
#   https://github.com/rbialon/flake8-annotations/blob/master/index.js
echo 'Running binary'
"$folder/syntax_tests" \
    | while read -r line; do
        echo "$line"
        # /syntax_tests/Data/Packages/syntax-test-action/test/defpkg/syntax_test_test:7:1: [source.python constant.language] does not match scope [text.test]
        if [[ "$line" == "$packages/$INPUT_PACKAGE_NAME/"* ]]; then
            IFS=$':' read -r path row col message <<< "$line"
            file="${path/$packages\/$INPUT_PACKAGE_NAME/$INPUT_PACKAGE_ROOT}"
            # https://help.github.com/en/actions/reference/workflow-commands-for-github-actions#setting-an-error-message
            echo "::error file=$file,line=$row,col=$col::${message# }"
        fi
    done
