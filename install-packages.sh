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

set -e

# Inputs

root=$(cd "$(dirname "$0")" && pwd)
ghc_version="8.0.2"

pkg_db_dir="$root/local/pkg-db.d"
docs_dir="$root/docs"

html_dir="html"
# Dir with with children like ‘base-4.9.0.0/Data-Functor.html’.
docs_html_dir="$docs_dir/$html_dir"
mkdir -p "$docs_html_dir"

# Dir with package db, libraries, shared files
local="$root/local"

ghc_docs_root="$(dirname "$(which ghc)")/../share/doc/ghc-${ghc_version}/html/libraries/"

package_list="$root/package-list-unversioned"
package_download_dir="$root/all-packages"

# Packages for which no source on Hackage exists
special_global_packages="rts|ghc"

if [[ ! -d "$ghc_docs_root" ]]; then
    echo "The ghc documentation directory does not exist: $ghc_docs_root" >&2
    exit 1
fi
if [[ ! -f "$package_list" ]]; then
    echo "The package list file does not exist: $package_list" >&2
    exit 1
fi

# User input

action="${1:-all}"

if ! [[ "$action" = "all" || "$action" = "install" || "$action" = "download" || "$action" = "update-tags" || "$action" = "generate-haddock-docs" ]]; then
    echo "Invalid action: $action." >&2
    echo "Valid actions: install, download, update-tags, generate-haddock-docs, all" >&2
    echo "  install - create local package db and install packages from ‘$package_list’ into it, using the latest LTS stackage snapshot" >&2
    echo "  download - get sources of all packages installed into local package db"
    echo "  update-tags - regenerate tags file"
    echo "  generate-haddock-docs - create offline documentation for installed packages"
fi

# Utils

function execVerbose {
   echo "${@}"
   "${@}"
}

# Actions

if [[ ! -d "$local" ]]; then
    echo "Creating directory $local"
    mkdir -p "$local"
fi

# Create package db
if [[ ! -d "$pkg_db_dir" ]]; then
    echo "Creating package db at $pkg_db_dir"
    ghc-pkg init "$pkg_db_dir"
fi


# Copy builtin docs
if [[ "$action" = "install" || "$action" = "generate-haddock-docs" || "$action" = "all" ]]; then
    echo "Populating '$docs_html_dir' with builtin documentatios"
    for pkg in $(cd "$ghc_docs_root" && find . -maxdepth 1 -type d | sed -re "/^\.\/(rts)-[0-9.]*$/d"); do
        if [[ "$pkg" != "." ]]; then
            if [[ -d "$docs_html_dir/$pkg" ]]; then
                echo "Skipping $pkg - documentation already present"
            else
                echo "Copying documentation for $pkg"
                cp -r "$ghc_docs_root/$pkg" "$docs_html_dir"
            fi
        fi
    done
fi

# Install packages
if [[ "$action" = "install" || "$action" = "all" ]]; then
    echo "Installing packages"
    global_packages_re=""
    for pkg in $(ghc-pkg list --global --simple-output); do
        unversioned="${pkg%-*}"
        if [[ -n "$global_packages_re" ]]; then
            global_packages_re="$global_packages_re|$unversioned"
        else
            global_packages_re="$unversioned"
        fi
    done

    echo "global_packages_re = ${global_packages_re}"
    packages_to_install=$(cat "$package_list" | awk '!/^ *--.*$/' | grep -v -E "^($global_packages_re)$" | xargs echo)

    if [[ ! -f cabal.config ]]; then
        echo "Updating cabal.config"
        wget https://www.stackage.org/lts/cabal.config
    fi

    echo "Installing following packages"
    for pkg in ${packages_to_install}; do
        echo "- $pkg"
    done

    for prog in alex happy c2hs; do
      if ! which "$prog"; then
          echo "Cannot find program '$prog' within PATH" >&2
          exit 1
      fi
    done

        # --haddock-hoogle \
    execVerbose \
        cabal --no-require-sandbox install \
        --prefix "$local" \
        --docdir="$docs_html_dir/\$pkgid" \
        --htmldir="$docs_html_dir/\$pkgid" \
        --package-db="$pkg_db_dir" \
        --disable-split-objs \
        --enable-optimization=0 \
        --enable-shared \
        --disable-library-profiling \
        --disable-profiling \
        --disable-tests \
        --disable-benchmarks \
        --enable-documentation \
        --haddock-hoogle \
        --haddock-html \
        --haddock-hyperlink-source \
        "--haddock-html-location=../\$pkgid" \
        --haddock-internal \
        --haddock-hyperlink-source \
        -f new-base \
        --allow-newer=base \
        --allow-newer=diagrams-cairo \
        --allow-newer=diagrams-lib \
        --allow-newer=pipes \
        --allow-newer=process \
        --allow-newer=template-haskell \
        --allow-newer=time \
        --allow-newer=Cabal \
        --allow-newer=HUnit \
        --allow-newer=syb \
        --allow-newer=QuickCheck \
        --constraint="compdata == 0.11" \
        -j5 \
        $packages_to_install
        # --allow-newer=haskell-src-exts \
        # --build-log=build.log \
fi

        # --allow-newer=process \
        # --allow-newer=diagrams-cairo \
        # --allow-newer=diagrams-lib \
        # --allow-newer=distributed-process-extras \
        # --allow-newer=distributed-process \
        # --allow-newer=distributed-process-client-server \
        # --allow-newer=binary \
        # --allow-newer=HUnit \
        # --allow-newer=time \
        # --allow-newer=pipes \

function get_packages {
    ghc-pkg "${@}" list --simple-output | sed -e "s/ /\n/g" | sed -re "/^(${special_global_packages})-[0-9.]*$/d"
}

if [[ "$action" = "download" || "$action" = "all" ]]; then
    echo "Downloading package sources for indexing into $package_download_dir"

    mkdir -p "$package_download_dir"

    for pkg in $(get_packages --global --package-db "$pkg_db_dir"); do
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

if [[ "$action" = "update-tags" || "$action" = "all" ]]; then
    echo "Updating tags"
    time fast-tags -o "$root/tags" -v -R "$package_download_dir" --nomerge
fi

if [[ "$action" = "generate-haddock-docs" || "$action" = "all" ]]; then
    mkdir -p "$docs_dir"

    pushd "$docs_dir" >/dev/null
        haddock_args=""
        for interface_file in $(find "$docs_dir" -type f -name '*.haddock'); do
            interface_file_rel="$(realpath --relative-to "$docs_dir" "$interface_file")"
            echo "interface_file = ${interface_file_rel}"
            html="$(dirname "$interface_file_rel")"
            flag="--read-interface=${html},${interface_file_rel}"
            #flag="--read-interface=file://${html},${interface_file_rel}"
            # flag="--read-interface=${interface_file_rel}"
            if [[ -z "$haddock_args" ]]; then
                haddock_args="$flag"
            else
                haddock_args="$haddock_args $flag"
            fi
        done

        echo "Running haddock"

        # haddock=haddock
        haddock=/home/sergey/projects/haskell/projects/thirdparty/haddock/dist/build/haddock/haddock
        $haddock \
            --verbosity=3 \
            --pretty-html \
            --gen-contents \
            --gen-index \
            --odir="$docs_dir" \
            --title="Standalone Haskell Documentation" \
            --hyperlinked-source \
            $haddock_args
    popd >/dev/null
fi

