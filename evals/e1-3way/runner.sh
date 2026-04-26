#!/bin/bash
# E1 3-way runner wrapper. Real logic in runner.py for proper parallelism.
exec python3 "$(dirname "$0")/runner.py" "$@"
