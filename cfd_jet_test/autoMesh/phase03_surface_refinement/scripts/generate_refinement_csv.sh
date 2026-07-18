#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Phase 03 — Generate default surface refinement configuration
#
# Input:
#   phase01_scan/generated/geometry.csv
#
# Output:
#   phase03_surface_refinement/config/refinement.csv
#
# Important:
#   - Creates the file only when it does not exist.
#   - Existing manual refinement settings are preserved.
#   - Use --force only when intentionally rebuilding defaults.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AUTOMESH_DIR="$(cd "$PHASE_DIR/.." && pwd)"

GEOMETRY_CSV="${1:-$AUTOMESH_DIR/phase01_scan/generated/geometry.csv}"
OUTPUT_FILE="${2:-$PHASE_DIR/config/refinement.csv}"
MODE="${3:-}"

# Default refinement levels by boundary type
PATCH_MIN=2
PATCH_MAX=3

WALL_MIN=2
WALL_MAX=3

EMPTY_MIN=0
EMPTY_MAX=0

SYMMETRY_MIN=0
SYMMETRY_MAX=0

WEDGE_MIN=0
WEDGE_MAX=0

CYCLIC_MIN=1
CYCLIC_MAX=1

echo "========================================"
echo "Phase 03 — Generate Refinement CSV"
echo "========================================"
echo
echo "Input:"
echo "  $GEOMETRY_CSV"
echo
echo "Output:"
echo "  $OUTPUT_FILE"
echo

if [[ ! -f "$GEOMETRY_CSV" ]]; then
    echo "ERROR: geometry.csv was not found:"
    echo "  $GEOMETRY_CSV"
    exit 1
fi

if [[ -f "$OUTPUT_FILE" && "$MODE" != "--force" ]]; then
    echo "Refinement configuration already exists."
    echo "It was not overwritten:"
    echo "  $OUTPUT_FILE"
    echo
    echo "Use --force only to rebuild the default file:"
    echo "  $0 \"$GEOMETRY_CSV\" \"$OUTPUT_FILE\" --force"
    exit 0
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

TEMP_FILE="$(mktemp)"
trap 'rm -f "$TEMP_FILE"' EXIT

echo "filename,name,patchType,minLevel,maxLevel,enabled" > "$TEMP_FILE"

surface_count=0

while IFS=',' read -r filename surface_name patch_type; do

    filename="${filename//$'\r'/}"
    surface_name="${surface_name//$'\r'/}"
    patch_type="${patch_type//$'\r'/}"

    [[ -z "$filename" ]] && continue

    case "$patch_type" in
        patch)
            min_level="$PATCH_MIN"
            max_level="$PATCH_MAX"
            ;;

        wall)
            min_level="$WALL_MIN"
            max_level="$WALL_MAX"
            ;;

        empty)
            min_level="$EMPTY_MIN"
            max_level="$EMPTY_MAX"
            ;;

        symmetry|symmetryPlane)
            min_level="$SYMMETRY_MIN"
            max_level="$SYMMETRY_MAX"
            ;;

        wedge)
            min_level="$WEDGE_MIN"
            max_level="$WEDGE_MAX"
            ;;

        cyclic)
            min_level="$CYCLIC_MIN"
            max_level="$CYCLIC_MAX"
            ;;

        *)
            echo "ERROR: Unsupported patch type '$patch_type' for $filename"
            exit 1
            ;;
    esac

    printf '%s,%s,%s,%s,%s,true\n' \
        "$filename" \
        "$surface_name" \
        "$patch_type" \
        "$min_level" \
        "$max_level" >> "$TEMP_FILE"

    printf 'Added: %-30s type=%-14s level=(%s %s)\n' \
        "$surface_name" \
        "$patch_type" \
        "$min_level" \
        "$max_level"

    ((surface_count += 1))

done < <(tail -n +2 "$GEOMETRY_CSV")

if [[ $surface_count -eq 0 ]]; then
    echo "ERROR: No surfaces found in geometry.csv"
    exit 1
fi

mv "$TEMP_FILE" "$OUTPUT_FILE"
trap - EXIT

echo
echo "Created default refinement configuration:"
echo "  $OUTPUT_FILE"
echo
echo "Surface count: $surface_count"
echo
echo "Edit minLevel and maxLevel manually before generating"
echo "refinementSurfaces.block."
echo

column -s, -t "$OUTPUT_FILE" 2>/dev/null || cat "$OUTPUT_FILE"
