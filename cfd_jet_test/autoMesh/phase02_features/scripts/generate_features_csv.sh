#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Phase 02A — Generate features.csv
#
# Input:
#   phase01_scan/generated/geometry.csv
#
# Output:
#   phase02_features/config/features.csv
#
# Purpose:
#   Create a configurable feature-level table from geometry.csv.
#   Existing config is preserved unless --force is used.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AUTOMESH_DIR="$(cd "$PHASE_DIR/.." && pwd)"

GEOMETRY_CSV="${1:-$AUTOMESH_DIR/phase01_scan/generated/geometry.csv}"
OUTPUT_FILE="${2:-$PHASE_DIR/config/features.csv}"
MODE="${3:-}"

# Default feature levels by patch type
PATCH_LEVEL=3
WALL_LEVEL=3
EMPTY_LEVEL=0
SYMMETRY_LEVEL=0
WEDGE_LEVEL=0
CYCLIC_LEVEL=1

echo "========================================"
echo "Phase 02A — Generate features.csv"
echo "========================================"
echo
echo "Input:"
echo "  $GEOMETRY_CSV"
echo
echo "Output:"
echo "  $OUTPUT_FILE"
echo

if [[ ! -f "$GEOMETRY_CSV" ]]; then
    echo "ERROR: geometry.csv not found:"
    echo "  $GEOMETRY_CSV"
    exit 1
fi

if [[ -f "$OUTPUT_FILE" && "$MODE" != "--force" ]]; then
    echo "features.csv already exists."
    echo "Existing manual settings were preserved:"
    echo "  $OUTPUT_FILE"
    echo
    echo "Use --force only when rebuilding defaults."
    exit 0
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

TEMP_FILE="$(mktemp)"
trap 'rm -f "$TEMP_FILE"' EXIT

echo "filename,name,patchType,featureLevel,enabled" > "$TEMP_FILE"

surface_count=0

while IFS=',' read -r filename surface_name patch_type; do

    filename="${filename//$'\r'/}"
    surface_name="${surface_name//$'\r'/}"
    patch_type="${patch_type//$'\r'/}"

    [[ -z "$filename" ]] && continue

    case "$patch_type" in
        patch)
            feature_level="$PATCH_LEVEL"
            enabled="true"
            ;;

        wall)
            feature_level="$WALL_LEVEL"
            enabled="true"
            ;;

        empty)
            feature_level="$EMPTY_LEVEL"
            enabled="false"
            ;;

        symmetry|symmetryPlane)
            feature_level="$SYMMETRY_LEVEL"
            enabled="false"
            ;;

        wedge)
            feature_level="$WEDGE_LEVEL"
            enabled="false"
            ;;

        cyclic)
            feature_level="$CYCLIC_LEVEL"
            enabled="true"
            ;;

        *)
            echo "ERROR: Unsupported patch type '$patch_type'"
            echo "File: $filename"
            exit 1
            ;;
    esac

    printf '%s,%s,%s,%s,%s\n' \
        "$filename" \
        "$surface_name" \
        "$patch_type" \
        "$feature_level" \
        "$enabled" >> "$TEMP_FILE"

    printf 'Added: %-30s level=%-3s enabled=%s\n' \
        "$surface_name" \
        "$feature_level" \
        "$enabled"

    ((surface_count += 1))

done < <(tail -n +2 "$GEOMETRY_CSV")

if [[ $surface_count -eq 0 ]]; then
    echo "ERROR: No surfaces found in geometry.csv"
    exit 1
fi

mv "$TEMP_FILE" "$OUTPUT_FILE"
trap - EXIT

echo
echo "Created:"
echo "  $OUTPUT_FILE"
echo
echo "Surface count: $surface_count"
echo
column -s, -t "$OUTPUT_FILE" 2>/dev/null || cat "$OUTPUT_FILE"
