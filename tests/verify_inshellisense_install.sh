#!/usr/bin/env bash
set -e

if command -v inshellisense >/dev/null 2>&1; then
    echo "SUCCESS: inshellisense is installed and in the PATH."
    exit 0
else
    echo "FAILURE: inshellisense is NOT installed or NOT in the PATH."
    exit 1
fi
