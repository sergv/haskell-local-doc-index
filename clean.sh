#! /usr/bin/env bash
#
# File: clean.sh
#
# Created: Thursday, 17 November 2016
#

# treat undefined variable substitutions as errors
set -u
# propagate errors from all parts of pipes
set -o pipefail

rm -rf all-packages/ generated/ local* docs.bak docs dist-newstyle build.log

exit 0

