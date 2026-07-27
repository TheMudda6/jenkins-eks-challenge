#!/bin/bash

# --------------------------------------------------------------------
# Usage
#
# Source this file in any script that requires shared helper functions.
#
# Example:
# source "$(dirname "${BASH_SOURCE[0]}")/../scripts/common.sh"
# --------------------------------------------------------------------
print_banner() {
    echo
    echo "====================================="
    echo "$1"
    echo "====================================="
    echo
}

