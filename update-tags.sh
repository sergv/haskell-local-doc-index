#!/bin/bash

time fast-tags -o tags -v -R . --nomerge

find all-packages \( -name '*.hs' -o -name '*.lhs' -o -name '*.x' -o -name '*.y' -o -name '*.lx' -o -name '*.ly' -o -name '*.chs' -o -name '*.hsc' -o -name '*.h' -o -name '*.c' -o -name '*.hpp' -o -name '*.cpp' -o -name '*.hxx' -o -name '*.cxx' -o -name '*.hh' -o -name '*.cc' \) -print >files.txt
