#! /usr/bin/env bash

find all-packages \( -path "all-packages/ghc-exactprint-*/tests/*" -o -path "all-packages/semigroups-*/src-ghc7/*" -o -path "all-packages/transformers-*/legacy/*" \) -prune -o \( -name '*.hs' -o -name '*.lhs' -o -name '*.chs' -o -name '*.hsc' -o -name '*.sig' -o -name '*.lsig' \) -print0 | fast-tags -0 -o tags -v --nomerge -
