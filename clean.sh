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

rm -vr all-packages/ local* docs.bak

exit 0

