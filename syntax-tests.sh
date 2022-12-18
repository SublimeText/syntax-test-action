#!/usr/bin/env bash

set -e -o pipefail

# folder=".syntax-test-action"
folder="$RUNNER_WORKSPACE/syntax_tests"
packages="$folder/Data/Packages"
mkdir -p "$folder"

get_url() {
    latest_url="https://download.sublimetext.com/latest/dev/linux/x64/syntax_tests"
    template_3000="https://download.sublimetext.com/st3_syntax_tests_build_%s_x64.tar.bz2"
    template_4000="https://download.sublimetext.com/st_syntax_tests_build_%s_x64.tar.bz2"
    template_4079="https://download.sublimetext.com/st_syntax_tests_build_%s_x64.tar.xz"

    case $INPUT_BUILD in
        latest) echo "$latest_url";;
        3*)     printf "$template_3000\n" "$INPUT_BUILD";;
        4*)     if (( INPUT_BUILD < 4079 )); then
                    printf "$template_4000\n" "$INPUT_BUILD";
                else
                    printf "$template_4079\n" "$INPUT_BUILD";
                fi;;
        *)      echo >&2 "Invalid build reference"; exit 100;;
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
    pushd "$(mktemp -d)"
    wget --content-disposition "https://github.com/sublimehq/Packages/archive/$INPUT_DEFAULT_PACKAGES.tar.gz"
    tar xf Packages-*.tar.gz
    if [[ $INPUT_DEFAULT_TESTS != true ]]; then
        find Packages-*/ -type f -regextype posix-egrep -regex '$INPUT_TEST_FILE_REGEX' -exec rm -v '{}' \;
    fi
    find Packages-*/ \
        -type d \
        -maxdepth 1 \
        -mindepth 1 \
        -not -name '.github' \
        -exec mv -vt "$packages/" '{}' +
    popd
}

link_package() {
    ln -vs "$(realpath "$INPUT_PACKAGE_ROOT")" "$packages/$INPUT_PACKAGE_NAME"
}

# TODO cache $folder/syntax_test based on $INPUT_BUILD != latest
echo "::group::Fetching binary (build $INPUT_BUILD)"
get_url | fetch_binary
echo '::endgroup::'

# TODO cache $packages based on $INPUT_DEFAULT_PACKAGES not in (master, st3) (or resolve ref to hash)
if [[ $INPUT_DEFAULT_PACKAGES != false ]]; then
    echo "::group::Fetching default packages (ref: $INPUT_DEFAULT_PACKAGES, tests: $INPUT_DEFAULT_TESTS)"
    fetch_default_packages
    echo '::endgroup::'
else
    echo '::debug::Skipping default packages'
fi


echo 'Linking package'
link_package

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
            echo "::error file=$file,line=$row,col=$col::$message"
        fi
    done
