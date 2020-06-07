#!/usr/bin/env bash

set -o pipefail

folder="/syntax_tests"
packages="$folder/Data/Packages"
mkdir -p "$packages"

get_url() {
    latest_url="https://download.sublimetext.com/latest/dev/linux/x64/syntax_tests"
    template_3000="https://download.sublimetext.com/latest/dev/linux/x64/st3_syntax_tests_build_%s_x64.tar.bz2"
    template_4000="https://download.sublimetext.com/st_syntax_tests_build_%s_x64.tar.bz2"

    case $INPUT_BUILD in
        latest) echo "$latest_url";;
        3*)     echo $(printf "$template_3000" "$INPUT_BUILD");;
        4*)     echo $(printf "$template_4000" "$INPUT_BUILD");;
        *)      echo >&2 "Invalid build reference"; exit 1;;
    esac
}

fetch_binary() {
    url="$1"
    cd "$(mktemp -d)"
    wget --content-disposition "$url"
    tar xf st*_syntax_tests_build_*_x64.tar.bz2
    mv st_syntax_tests/syntax_tests "$folder"
}

fetch_default_packages() {
    wget --content-disposition "https://github.com/sublimehq/Packages/archive/$INPUT_DEFAULT_PACKAGES.tar.gz"
    tar xf Packages-*.tar.gz
    find Packages-*/ \
        -type d \
        -maxdepth 1 \
        -mindepth 1 \
        -exec mv -v '{}' "$packages/" \;
}

link_package() {
    ln -s "$(realpath "$INPUT_PACKAGE_ROOT")" "Data/Packages/$INPUT_PACKAGE_NAME"
}

get_url | fetch_binary
[[ $INPUT_DEFAULT_PACKAGES != false ]] && fetch_default_packages
# TODO cache $folder based on $INPUT_BUILD != latest && $INPUT_DEFAULT_PACKAGES
link_package

exec "$folder/syntax_tests"
