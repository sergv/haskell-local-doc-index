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

if [[ -z "${IN_NIX_SHELL-}" ]]; then
    echo "Re-run under ‘nix develop -c’" >&2
    exit 1
fi

ghc=ghc-9.14

ghc_commit=$($ghc --info | awk '/"Project Git commit id"/' | sed -re 's/^ ,\("Project Git commit id","|"\)$//g')

root=$(cd "$(dirname "$0")" && pwd)
ghc_version="$("$ghc" --numeric-version)"

ghc_repo="$root/ghc"

cabal="cabal"
# cabal="./cabal-3.7-no-asserts"
# cabal="/tmp/dist/build/x86_64-linux/ghc-8.10.7/cabal-install-3.7.0.0/x/cabal/build/cabal/cabal"

haddock="haddock-${ghc_version}"
ghc_pkg="ghc-pkg-${ghc_version}"

haddock_theme_dir="$(pwd)/themes/Solarized.theme"

# haddock_theme_dir="$(dirname "$haddock_theme")"

# pkg_db_dir="$root/local/pkg-db.d"

unit_id=$($ghc --info | awk '/"Project Unit Id"/' | sed -re 's/^ ,\("Project Unit Id","|"\)$//g')

store_pkg_db_dir="${root}/local-store/${unit_id}/package.db/"
docs_final_dir="${root}/docs"

# docs_dir="${root}/docs"
docs_dir="/tmp/tmp-haskell-packages-workdir/docs"

# Dir with with children like ‘base-4.9.0.0/Data-Functor.html’.
docs_html_dir="$docs_dir/html"

# Dir with package db, libraries, shared files
local="$root/local"

if [[ "${GHC_DOCS_ROOT:-x}" == x && -z "${IN_NIX_SHELL-}" ]]; then
    echo "Must specify GHC_DOCS_ROOT under nix" >&2
    exit 1
fi

# Present in binary installations but on NixOs is part of another package
ghc_docs_root_default="$(dirname "$(which $ghc)")/../share/doc/ghc-${ghc_version}/html/libraries/"

ghc_docs_root="${GHC_DOCS_ROOT:-$ghc_docs_root_default}"

package_list="$root/package-list-unversioned"
package_download_dir="$root/all-packages"

# Packages for which no source on Hackage exists
special_global_packages="rts|ghc"

if [[ ! -d "$ghc_docs_root" ]]; then
    echo "The ghc documentation directory does not exist: $ghc_docs_root" >&2
    echo "Did you forget to run this scipt under ‘nix develop -c’?" >&2
    exit 1
fi
if [[ ! -f "$package_list" ]]; then
    echo "The package list file does not exist: $package_list" >&2
    exit 1
fi

# User input

action="${1:-all}"

case "$action" in
    "all" | "install" | "download" | "generate-haddock-docs" | "update-css" | "fix-mathjax" | "remove-synopsis" | "fix-dark-mode" | "copy-final-docs")
        :
        ;;

    * )
        echo "Invalid action: $action." >&2
        echo "Valid actions: install, download, generate-haddock-docs, update-css, all" >&2
        echo "  install - create local package db and install packages from ‘$package_list’ into it, using the latest LTS stackage snapshot" >&2
        echo "  download - get sources of all packages installed into local package db"
        echo "  generate-haddock-docs - create offline documentation for installed packages"
        echo "  update-css - update CSS theme file everywhere"
        echo "  fix-mathjax - link all HTMLs to the static mathjax on my hard drive"
        echo "  remove-synopsis - remove synopsis nodes so they don't confuse search in firefox"
        echo "  fix-dark-mode - add meta stanza to all htmls stating that they use dark mode do make DarkReader plugin not apply its darkening"
        echo "  copy-final-docs - popuplate folder on permanent storage"
        ;;
esac

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
    mkdir -p "$docs_html_dir"
    for pkg in $(cd "$ghc_docs_root" && find . -maxdepth 1 -type d | sed -re "/^\.\/(rts)-[0-9.]*$/d"); do
        if [[ "$pkg" != "." ]]; then
            if [[ -d "$docs_html_dir/$pkg" ]]; then
                echo "Skipping $pkg - documentation already present"
            else
                echo "Copying documentation for $pkg"
                cp -r "$ghc_docs_root/$pkg" "$docs_html_dir"
                chmod 0755 "$docs_html_dir/$pkg"
                [[ -d "$docs_html_dir/$pkg/src" ]] && chmod 0755 "$docs_html_dir/$pkg/src"
                find "$docs_html_dir/$pkg" -type f -exec chmod 0644 {} \;
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
        "$cabal" build -w $ghc \
        --builddir /tmp/dist \
        -j16 \
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
    "$ghc_pkg" "${@}" list --simple-output | sed -e "s/ /\n/g" | sed -re "/^(${special_global_packages})-[0-9.]*$/d"
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
        if [[ "$pkg" == "ghc-boot-9.4.3" ]]; then
            pkg="ghc-boot-9.4.1"
        fi
        if [[ "$pkg" == "ghc-boot-th-9.4.3" ]]; then
            pkg="ghc-boot-th-9.4.1"
        fi
        if [[ "$pkg" == "ghc-boot-th-8.10.7" ]]; then
            pkg="ghc-boot-th-8.10.2"
        fi
        if [[ "$pkg" == "hpc-0.6.1.0" ]]; then
            pkg="hpc-0.6.0.3"
        fi

        if [[ "$pkg" == "ghc-boot-9.6.2" ]]; then
            pkg="ghc-boot-9.6.1"
        fi
        if [[ "$pkg" == "ghc-boot-th-9.6.2" ]]; then
            pkg="ghc-boot-th-9.6.1"
        fi

        # Should be removed going forwards...
        if [[ "$pkg" == "ghc-boot-th-9.12.1" ]]; then
            pkg="ghc-boot-th-9.10.3"
        fi
        if [[ "$pkg" == "haddock-api-2.30.0" ]]; then
            pkg="haddock-api-2.29.1"
        fi
        if [[ "$pkg" == "directory-1.3.10.0" ]]; then
            pkg="directory-1.3.9.0"
        fi

        case "$pkg" in
            # Internal packages that shouldn’t be indexed
            z-* | ghc-heap-* | libiserv-* | ghci* | integer-gmp* | system-cxx-std-lib* | utility-ht* | ghc-platform* | ghc-toolchain* )
                echo "Skipping $pkg" >&2
                continue
                ;;
            # Packages bundled with GHC which we can get from the GHC
            base-* | ghc-bignum-* | ghc-boot-* | ghc-boot-th-* | ghc-experimental-* | ghc-internal-* | ghc-prim-* | haddock-api-* | template-haskell-* )
                echo "Skipping $pkg" >&2
                continue
                ;;

        esac

        fs=( $(find "$package_download_dir" -maxdepth 1 -type d -name "${pkg}*") )

        if [[ "${#fs[@]}" = 0 && ! -d "$pkg" ]]; then
            echo "Downloading $pkg" >&2
            echo "$pkg"
        else
            echo "Skipping $pkg" >&2
        fi
    done | awk '!/^Win32-[0-9.]+$/' | (cd "$package_download_dir"; xargs cabal get)
    # # Can’t build it
    # (cd "$package_download_dir"; rm -r Win32-*; cabal get Win32)

    pushd "$root/ghc" >/dev/null
    if ! git checkout "$ghc_commit"; then
        if ! git remote update && git checkout "$ghc_commit"; then
            echo "Failed to find GHC commit $ghc_commit in repository $(pwd). Maybe try ‘git remote update’ there?." >&2
            exit 1
        fi
    fi
    git submodule update --init
    popd >/dev/null

    for x in libraries/base libraries/ghc-bignum libraries/ghc-boot libraries/ghc-boot-th libraries/ghc-experimental libraries/ghc-internal libraries/ghc-prim libraries/template-haskell libraries/Win32 utils/haddock/haddock-api; do
        echo "Copying package $x from GHC sources"
        pkg_src="${root}/ghc/${x}"
        if [[ ! -d "$pkg_src" ]]; then
            echo "Cannot find sources for package $(basename "${x}") within GHC repository at ${pkg_src}" >&2
            exit 1
        fi
        cp -r "$pkg_src" "$package_download_dir"
    done
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

        if [[ ! -f "$docs_dir/index.html" ]]; then
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
        fi
    popd >/dev/null
fi

if [[ "$action" = "update-css" || "$action" = "all" ]]; then

    local_haddock_theme_dir="$docs_dir/$(basename "$haddock_theme_dir")"
    echo cp -r "$haddock_theme_dir" "$docs_dir"
    cp -rv "$haddock_theme_dir" "$docs_dir"

    for dedup_resource in "haddock-bundle.min.js" "quick-jump.css" "highlight.js"; do
      src="$(find /tmp/tmp-haskell-packages-workdir/docs/ -name "$dedup_resource" | awk 'NR < 2')"

      if [[ -f "$src" && ! -h "$src" ]]; then
          cp "$src" "$local_haddock_theme_dir"
      fi
    done


    # Fix linuwial that comes with haddocs for precompiled packages (e.g. base).
    while IFS= read -d $'\0' -r css ; do

        if [[ "$(dirname $css)" = "$local_haddock_theme_dir" ]]; then
            # Don’t overwrite the source for everything
            continue
        fi

        css_dir=$(dirname "$css")
        source_css_dir="$css_dir/src"

        haddock_theme_css_rel=$(realpath -m --relative-to "$css_dir" "$local_haddock_theme_dir/solarized.css")

        echo "$css"

        rm "$css"
        ln -s "$haddock_theme_css_rel" "$css"

        source_css="${source_css_dir}/style.css"

        if [[ -d "$source_css_dir" ]]; then
            source_theme_rel=$(realpath -m --relative-to "$source_css_dir" "$local_haddock_theme_dir/solarized-source.css")
            rm "$source_css"
            ln -s "$source_theme_rel" "$source_css"
        fi

        for haddock_resource in hslogo-16.png minus.gif plus.gif synopsis.png haddock-bundle.min.js quick-jump.css src/highlight.js; do
            dest="$(dirname "$css")/$haddock_resource"
            if [[ -e "$dest" ]]; then
                src_rel=$(realpath -m --relative-to "$css_dir/$(dirname "$haddock_resource")" "$local_haddock_theme_dir/$(basename "$haddock_resource")")
                rm "$dest"
                ln -s "$src_rel" "$dest"
            fi
        done

    done < <(find "$docs_dir" -name 'linuwial.css' -print0)
fi

if [[ "$action" = "fix-mathjax" || "$action" = "all" ]]; then

    new_mathjax_version="2.7.9"

    if [[ ! -e "$root/MathJax-${new_mathjax_version}" ]]; then
        echo "Failed to find MathJax at: '$root/MathJax-${new_mathjax_version}', check the intended MathJax version" >&2
        exit 1
    fi

    mathjax_path="$docs_dir/MathJax-${new_mathjax_version}"

    if [[ ! -e "$mathjax_path" ]]; then
       cp -r "$root/MathJax-${new_mathjax_version}" "$mathjax_path"
       rm -rv "$mathjax_path/test/"
    fi

    echo "Mathjax is at $mathjax_path"
    # mathjax_abs_path="file://$mathjax_path"

    while IFS= read -d $'\0' -r x ; do

        echo "Fixing mathjax in file $x"

        mathjax_rel_path=$(realpath -m --relative-to "$(dirname "$x")" "$mathjax_path/MathJax.js")

        cmds=$(cat <<EOF
s#https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.5/MathJax.js?config=TeX-AMS-MML_HTMLorMML#$mathjax_rel_path?config=TeX-AMS_SVG.js#
s#/><link rel="stylesheet" type="text/css" href="https://fonts.googleapis.com/css?family=PT+Sans:400,400i,700"##
EOF
)
        sed -i -e "$cmds" "$x"

    done < <(grep -l -F 'https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.5/MathJax.js' -r "$docs_dir" --null)
fi

if [[ "$action" = "remove-synopsis" || "$action" = "all" ]]; then
    while IFS= read -d $'\0' -r x ; do

        echo "Removing synopsis from $x"

        xmlstarlet --huge ed --inplace --delete "//*[@id = 'synopsis']" "$x" 2>/dev/null ||
            xmlstarlet --huge ed --inplace --delete "//*[@id = 'synopsis']" "$x"

    done < <(find "$docs_dir" -name '*.html' -print0)
fi


# Not strictly needed since I can just disable DarkReader on all local files and that’s enough.
# if [[ "$action" = "fix-dark-mode" || "$action" = "all" ]]; then
#     while IFS= read -d $'\0' -r x ; do
#
#         echo "Fixing dark mode in file $x"
#
#         cmds=$(cat <<EOF
# s#></head#><meta name="color-scheme" content="dark" /></head#
# EOF
# )
#         sed -i -e "$cmds" "$x"
#
#     done < <(find "$docs_dir" -name '*.html' -print0)
# fi

if [[ "$action" = "copy-final-docs" || "$action" = "all" ]]; then

    echo "Copying final docs to $docs_final_dir"

    cp -r "$docs_dir" "$docs_final_dir"

fi


