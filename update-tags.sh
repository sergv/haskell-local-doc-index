#! /usr/bin/env bash

find all-packages \( -path "all-packages/ghc-exactprint-*/tests/*" -o -path "all-packages/semigroups-*/src-ghc7/*" -o -path "all-packages/transformers-*/legacy/*" \) -prune -o \( -name '*.hs' -o -name '*.lhs' -o -name '*.chs' -o -name '*.hsc' -o -name '*.sig' -o -name '*.lsig' \) -print0 | fast-tags -0 -o tags -v --nomerge -

find all-packages \( -name '*.hs' -o -name '*.lhs' -o -name '*.x' -o -name '*.y' -o -name '*.lx' -o -name '*.ly' -o -name '*.chs' -o -name '*.hsc' -o -name '*.h' -o -name '*.c' -o -name '*.hpp' -o -name '*.cpp' -o -name '*.hxx' -o -name '*.cxx' -o -name '*.hh' -o -name '*.cc' -o -name '*.sig' -o -name '*.lsig' \) -print >files.txt
