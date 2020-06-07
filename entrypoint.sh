#!/usr/bin/env bash

set -e -o pipefail

folder="/syntax_tests"
packages="$folder/Data/Packages"

rm -rf "$folder"
mkdir -vp "$packages"

get_url() {
    latest_url="https://download.sublimetext.com/latest/dev/linux/x64/syntax_tests"
    template_3000="https://download.sublimetext.com/st3_syntax_tests_build_%s_x64.tar.bz2"
    template_4000="https://download.sublimetext.com/st_syntax_tests_build_%s_x64.tar.bz2"

    case $INPUT_BUILD in
        latest) echo "$latest_url";;
        3*)     echo $(printf "$template_3000" "$INPUT_BUILD");;
        4*)     echo $(printf "$template_4000" "$INPUT_BUILD");;
        *)      echo >&2 "Invalid build reference"; exit 1;;
    esac
}

fetch_binary() {
    read -r url
    cd "$(mktemp -d)"
    wget --content-disposition "$url"
    tar xf st*_syntax_tests_build_*_x64.tar.bz2
    mv st*_syntax_tests/syntax_tests "$folder"
}

fetch_default_packages() {
    wget --content-disposition "https://github.com/sublimehq/Packages/archive/$INPUT_DEFAULT_PACKAGES.tar.gz"
    ls -al
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
}

link_package() {
    ln -vs "$(realpath "$INPUT_PACKAGE_ROOT")" "$packages/$INPUT_PACKAGE_NAME"
}

echo "::group::Fetching binary (build $INPUT_BUILD)"
get_url | fetch_binary
echo '::endgroup::'

if [[ $INPUT_DEFAULT_PACKAGES != false ]]; then
    echo "::group::Fetching default packages (ref: $INPUT_DEFAULT_PACKAGES, tests: $INPUT_DEFAULT_TESTS)"
    fetch_default_packages
    echo '::endgroup::'
else
    echo '::debug::Skipping default packages'
fi

# TODO cache $folder based on $INPUT_BUILD != latest && $INPUT_DEFAULT_PACKAGES

echo 'Linking package'
link_package

echo 'Running binary'
"$folder/syntax_tests" | \
    while read -r line; do
        echo "$line"
        # /syntax_tests/Data/Packages/syntax-test-action/test/defpkg/syntax_test_test:7:1: [source.python constant.language] does not match scope [text.test]
        if [[ "$line" == "$packages/$INPUT_PACKAGE_NAME/"* ]]; then
            IFS=$':' read -r path row col message <<< "$line"
            file="${path/$packages\/$INPUT_PACKAGE_NAME/$INPUT_PACKAGE_ROOT}"
            # https://help.github.com/en/actions/reference/workflow-commands-for-github-actions#setting-an-error-message
            echo "::error file=$file,line=$row,col=$col::$message"
        fi
    done
