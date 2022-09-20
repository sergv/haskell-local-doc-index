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
ghc_version="$(ghc --numeric-version)"

cabal="cabal"
# cabal="./cabal-3.7-no-asserts"
# cabal="/tmp/dist/build/x86_64-linux/ghc-8.10.7/cabal-install-3.7.0.0/x/cabal/build/cabal/cabal"

haddock=haddock

haddock_theme="$(pwd)/themes/Solarized.theme/solarized.css"
haddock_theme_dir="$(dirname "$haddock_theme")"

# pkg_db_dir="$root/local/pkg-db.d"
store_pkg_db_dir="$root/local-store/ghc-${ghc_version}/package.db/"
docs_dir="$root/docs"

html_dir="html"
# Dir with with children like ‘base-4.9.0.0/Data-Functor.html’.
docs_html_dir="$docs_dir/$html_dir"
mkdir -p "$docs_html_dir"

# Dir with package db, libraries, shared files
local="$root/local"

# Present in binary installations but on NixOs is part of another package
ghc_docs_root_default="$(dirname "$(which ghc)")/../share/doc/ghc-${ghc_version}/html/libraries/"

ghc_docs_root="${GHC_DOCS_ROOT:-ghc_docs_root_default}"

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

if ! [[ "$action" = "all" || "$action" = "install" || "$action" = "download" || "$action" = "update-tags" || "$action" = "generate-haddock-docs" || "$action" = "update-css" ]]; then
    echo "Invalid action: $action." >&2
    echo "Valid actions: install, download, update-tags, generate-haddock-docs, update-css, all" >&2
    echo "  install - create local package db and install packages from ‘$package_list’ into it, using the latest LTS stackage snapshot" >&2
    echo "  download - get sources of all packages installed into local package db"
    echo "  update-tags - regenerate tags file"
    echo "  generate-haddock-docs - create offline documentation for installed packages"
    echo "  update-css - update CSS theme file everywhere"
fi

# Utils

function execVerbose {
   echo "${@}"
   "${@}"
}

# Actions

# if [[ ! -d "$local" ]]; then
#     echo "Creating directory $local"
#     mkdir -p "$local"
# fi
#
# # Create package db
# if [[ ! -d "$pkg_db_dir" ]]; then
#     echo "Creating package db at $pkg_db_dir"
#     ghc-pkg init "$pkg_db_dir"
# fi


# Copy builtin docs
if [[ "$action" = "install" || "$action" = "generate-haddock-docs" || "$action" = "all" ]]; then
    echo "Populating '$docs_html_dir' with builtin documentations"
    for pkg in $(cd "$ghc_docs_root" && find . -maxdepth 1 -type d | sed -re "/^\.\/(rts)-[0-9.]*$/d"); do
        if [[ "$pkg" != "." ]]; then
            if [[ -d "$docs_html_dir/$pkg" ]]; then
                echo "Skipping $pkg - documentation already present"
            else
                echo "Copying documentation for $pkg"
                cp -r "$ghc_docs_root/$pkg" "$docs_html_dir"
                chmod +w "$docs_html_dir/$pkg"
                [[ -d "$docs_html_dir/$pkg/src" ]] && chmod +w "$docs_html_dir/$pkg/src"
                # sudo chown -R sergey: "$docs_html_dir/$pkg"
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

    packages_to_install=$(cat "$package_list" | awk '!/^ *--.*$/' | grep -v -E "^($global_packages_re)$" | xargs echo)

    echo "Installing following packages"
    for pkg in ${packages_to_install}; do
        echo "- $pkg"
    done

    mkdir -p generated

    # for prog in alex happy c2hs; do
    #   if ! which "$prog"; then
    #       echo "Cannot find program '$prog' within PATH" >&2
    #       exit 1
    #   fi
    # done
    cat <<EOF >generated/depends-on-all.cabal
cabal-version: 3.0

name: depends-on-all
version: 0.1
synopsis: TODO
description: TODO
license: Apache-2.0
author: Sergey Vinokurov
maintainer: Sergey Vinokurov <serg.foo@gmail.com>

build-type: Simple

library
  default-language: Haskell2010
  build-depends:
$(for pkg in ${packages_to_install}; do echo "    $pkg,"; done)
EOF

        # --prefix "$local" \
        # --package-db="$pkg_db_dir" \

        # --haddock-hoogle \
        # --haddock-html \
        # --haddock-hyperlink-source \
        # "--haddock-html-location=../\$pkgid" \
        # --haddock-internal \
        # --haddock-hyperlink-source \
        # "--haddock-css=$haddock_css" \

        # -f new-base \

    execVerbose \
        "$cabal" build \
        -j4 \
        --project-file "cabal.project" \
        --disable-split-objs \
        --enable-optimization=0 \
        --enable-shared \
        --disable-library-profiling \
        --disable-profiling \
        --disable-tests \
        --disable-benchmarks \
        --enable-documentation \
        --with-haddock="$haddock" \
        depends-on-all
        # $packages_to_install
        # --build-log=build.log \
        # --ghc-options=-v3 \

fi

function get_packages {
    ghc-pkg "${@}" list --simple-output | sed -e "s/ /\n/g" | sed -re "/^(${special_global_packages})-[0-9.]*$/d"
}

if [[ "$action" = "download" || "$action" = "all" ]]; then
    echo "Downloading package sources for indexing into $package_download_dir"

    mkdir -p "$package_download_dir"

    # for pkg in $(get_packages --global --package-db "$pkg_db_dir"); do
    for pkg in $(get_packages --global --package-db "$store_pkg_db_dir"); do
        declare -a fs
        if [[ "$pkg" == "ghc-boot-8.4.4" ]]; then
            pkg="ghc-boot-8.4.3"
        fi
        if [[ "$pkg" == "ghc-boot-th-8.4.4" ]]; then
            pkg="ghc-boot-th-8.4.3"
        fi
        if [[ "$pkg" == "ghci-8.4.4" ]]; then
            pkg="ghci-8.4.3"
        fi
        if [[ "$pkg" == "ghc-boot-8.8.2" ]]; then
            pkg="ghc-boot-8.8.1"
        fi
        if [[ "$pkg" == "ghc-boot-th-8.8.2" ]]; then
            pkg="ghc-boot-th-8.8.1"
        fi
        if [[ "$pkg" == "ghci-8.8.2" ]]; then
            pkg="ghci-8.6.5"
        fi

        if [[ "$pkg" == "base-4.13.0.0" ]]; then
            pkg="base-4.12.0.0"
        fi
        if [[ "$pkg" == "bytestring-0.10.9.0" ]]; then
            pkg="bytestring-0.10.10.0"
        fi
        if [[ "$pkg" == "Cabal-3.0.1.0" ]]; then
            pkg="Cabal-3.0.0.0"
        fi

        if [[ "$pkg" == "ghc-boot-8.10.7" ]]; then
            pkg="ghc-boot-9.2.1"
        fi
        if [[ "$pkg" == "ghc-boot-9.4.2" ]]; then
            pkg="ghc-boot-9.4.1"
        fi
        if [[ "$pkg" == "ghc-boot-th-9.4.2" ]]; then
            pkg="ghc-boot-th-9.4.1"
        fi
        if [[ "$pkg" == "ghc-boot-th-8.10.7" ]]; then
            pkg="ghc-boot-th-8.10.2"
        fi
        if [[ "$pkg" == "hpc-0.6.1.0" ]]; then
            pkg="hpc-0.6.0.3"
        fi


        fs=( $(find "$package_download_dir" -maxdepth 1 -type d -name "${pkg}*") )

        if [[ "${#fs[@]}" = 0 && ! -d "$pkg" && "$pkg" != z-* && "$pkg" != ghc-heap-* && "$pkg" != libiserv-* && "$pkg" != ghci* && "$pkg" != integer-gmp* && "$pkg" != system-cxx-std-lib* ]]; then
            echo "Downloading $pkg" >&2
            echo "$pkg"
        else
            echo "Skipping $pkg" >&2
        fi
    done | (cd "$package_download_dir"; xargs cabal get)
fi

if [[ "$action" = "update-tags" || "$action" = "all" ]]; then
    echo "Updating tags"
    time fast-tags -o "$root/tags" -v -R "$package_download_dir" --nomerge
fi

if [[ "$action" = "generate-haddock-docs" || "$action" = "all" ]]; then
    mkdir -p "$docs_dir"


    while IFS= read -d $'\0' -r haddock_file ; do
        echo "Found haddock file ${haddock_file}"
        doc_dir="$(dirname "$haddock_file")"
        dir="$(dirname "$doc_dir")"
        dir="$(dirname "$dir")"
        dir="$(dirname "$dir")"
        package_name="$(basename "$dir" | sed -re 's/-[a-z0-9]+$//')"

        dest="$docs_html_dir/$package_name"
        if [[ ! -d "$dest" ]]; then
            cp -r "$doc_dir" "$dest"
        fi
    done < <(find "local-store/" -type f -name '*.haddock' -print0)

    pushd "$docs_dir" >/dev/null
        haddock_args=""

        while IFS= read -d $'\0' -r haddock_file ; do
            haddock_file_rel="$(realpath --relative-to "$docs_dir" "$haddock_file")"
            html="$(dirname "$haddock_file_rel")"
            flag="--read-interface=${html},${haddock_file_rel}"
            #flag="--read-interface=file://${html},${haddock_file_rel}"
            # flag="--read-interface=${haddock_file_rel}"

            if [[ -z "$haddock_args" ]]; then
                haddock_args="$flag"
            else
                haddock_args="$haddock_args $flag"
            fi
        done < <(find "${docs_html_dir}" -type f -name '*.haddock' | sort | tr '\n' '\0')

        echo "Running haddock"

        global_pkg_db="$(ghc-pkg list --global | head -n1)"

        # Passing explicit package dbs makes even unpatched haddock generate
        # package names.
        # cf https://github.com/commercialhaskell/stack/pull/3226
        "$haddock" \
            --verbosity=3 \
            --pretty-html \
            --gen-contents \
            --gen-index \
            --odir="$docs_dir" \
            --optghc=-package-db="$global_pkg_db" \
            --optghc=-package-db="$store_pkg_db_dir" \
            --title="Standalone Haskell Documentation" \
            --hyperlinked-source \
            $haddock_args
    popd >/dev/null
fi

if [[ "$action" = "update-css" || "$action" = "all" ]]; then
    # Fix linuwial that comes with haddocs for precompiled packages (e.g. base).
    while IFS= read -d $'\0' -r css ; do

        echo "$css"
        # if [[ ! -h "$css" ]]; then
        rm -f "$css"
        ln -s "$haddock_theme" "$css"
        # fi

        source_css="$(dirname "$css")/src/style.css"

        if [[ -f "$source_css" ]]; then
            rm -f "$source_css"
            ln -s "$haddock_theme_dir/../solarized.css" "$source_css"
        fi

        for haddock_resource in hslogo-16.png minus.gif plus.gif synopsis.png; do
            dest="$(dirname "$css")/$haddock_resource"
            if [[ ! -h "$dest" ]]; then
                rm -f "$dest"
                ln -s "$haddock_theme_dir/$haddock_resource" "$dest"
            fi
        done

    done < <(find "$docs_dir" -name 'linuwial.css' -print0)
fi
