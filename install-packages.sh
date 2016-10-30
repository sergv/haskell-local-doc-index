#! /usr/bin/env bash
#
# File: install-packages.sh
#
# Created: Saturday, 29 October 2016
#

# treat undefined variable substitutions as errors
set -u
# propagate errors from all parts of pipes
set -o pipefail

# Inputs

root=$(cd "$(dirname "$0")" && pwd)
pkg_db="$root/local/pkg-db.d"

package_list="$root/package-list-unversioned"
package_download_dir="$root/all-packages"

action="${1:-all}"

if ! [[ "$action" = "all" || "$action" = "download" || "$action" = "install" ]]; then
    echo "Invalid action: $action." >&2
    echo "Valid actions: install, download, all" >&2
fi

# Utils

function execVerbose {
   echo "${@}"
   "${@}"
}

# Actions

if [[ ! -d "$root/local" ]]; then
    echo "Creating directory $root/local"
    mkdir -p "$root/local"
fi

if [[ ! -d "$pkg_db" ]]; then
    echo "Updating package db at $pkg_db"
    ghc-pkg init "$pkg_db"
fi

if [[ "$action" = "install" || "$action" = "all" ]]; then
    global_packages_re=""
    for pkg in $(ghc-pkg list --global --simple-output); do
        unversioned="${pkg%-*}"
        if [[ -n "$global_packages_re" ]]; then
            global_packages_re="$global_packages_re|$unversioned"
        else
            global_packages_re="$unversioned"
        fi
    done

    packages_to_install=$(grep -v -E "$global_packages_re" "$package_list" | xargs echo)

    if [[ ! -f cabal.config ]]; then
        echo "Updating cabal.config"
        wget https://www.stackage.org/lts/cabal.config
    fi

    echo "Installing packages"
    for pkg in ${packages_to_install}; do
        echo "- $pkg"
    done

    execVerbose cabal install \
                --prefix "$root/local" \
                --package-db="$pkg_db" \
                --disable-split-objs \
                --enable-optimization=2 \
                --enable-shared \
                --disable-library-profiling \
                --disable-profiling \
                --disable-tests \
                --disable-benchmarks \
                --enable-documentation \
                --haddock-hoogle \
                --haddock-html \
                --haddock-hyperlink-source \
                --allow-newer=process \
                --allow-newer=template-haskell \
                -j1 \
                --build-log=build.log \
                $packages_to_install

fi

if [[ "$action" = "download" || "$action" = "all" ]]; then

    echo "Downloading package sources for indexing into $package_download_dir"

    mkdir -p "$package_download_dir"

    for pkg in $(ghc-pkg --global --package-db "$pkg_db" list --simple-output); do
        declare -a fs
        fs=( $(find "$package_download_dir" -maxdepth 1 -type d -name "${pkg}*") )

        if [[ "${#fs[@]}" = 0 && ! -d "$pkg" ]]; then
            echo "Downloading $pkg"
            pushd "$package_download_dir" >/dev/null
            cabal get "$pkg"
            popd >/dev/null
        else
            echo "Skipping $pkg"
        fi
    done

fi

exit 0

