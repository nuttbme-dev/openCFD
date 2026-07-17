#!/usr/bin/env bash

set -euo pipefail

CASE_DIR="/home/nuttbme/Documents/git/openCFD/cfd_jet_test"
PYCODE_DIR="$CASE_DIR/Pycode"

pvpython "$PYCODE_DIR/build_state.py"

paraview --state="$CASE_DIR/jet_stl_state.pvsm"
