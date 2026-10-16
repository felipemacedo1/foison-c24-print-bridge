#!/usr/bin/env sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PYTHONPATH="$root/src${PYTHONPATH:+:$PYTHONPATH}" \
    python3 -m unittest discover -s "$root/tests" -v
