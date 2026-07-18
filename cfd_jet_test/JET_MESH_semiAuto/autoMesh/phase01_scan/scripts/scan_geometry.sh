#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Phase 01 — Scan Geometry
#
# Scan STL files from:
#   JET_MESH/constant/triSurface
#
# Expected filename format:
#   <surface_name>_<boundary_type>.stl
#
# Examples:
#   inlet_patch.stl
#   object_wall.stl
#   front_empty.stl
#   side_symmetryPlane.stl
#
# Output:
#   autoMesh/phase01_scan/generated/geometry.csv
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AUTOMESH_DIR="$(cd "$PHASE_DIR/.." && pwd)"
CASE_DIR="$(cd "$AUTOMESH_DIR/.." && pwd)"

TRISURFACE_DIR="$CASE_DIR/constant/triSurface"
OUTPUT_DIR="$PHASE_DIR/generated"
OUTPUT_FILE="$OUTPUT_DIR/geometry.csv"

# Boundary tags supported in STL filenames
VALID_TAGS=(
    patch
    wall
    empty
    symmetry
    symmetryPlane
    wedge
    cyclic
)

echo "========================================"
echo "Phase 01 — Scan Geometry"
echo "========================================"
echo
echo "Case directory:"
echo "  $CASE_DIR"
echo
echo "STL directory:"
echo "  $TRISURFACE_DIR"
echo
echo "Output file:"
echo "  $OUTPUT_FILE"
echo

if [[ ! -d "$TRISURFACE_DIR" ]]; then
    echo "ERROR: triSurface directory was not found:"
    echo "  $TRISURFACE_DIR"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Find STL files case-insensitively.
mapfile -d '' STL_FILES < <(
    find "$TRISURFACE_DIR" \
        -maxdepth 1 \
        -type f \
        \( -iname '*.stl' \) \
        -print0 |
    sort -z
)

if [[ ${#STL_FILES[@]} -eq 0 ]]; then
    echo "ERROR: No STL files were found in:"
    echo "  $TRISURFACE_DIR"
    exit 1
fi

is_valid_tag() {
    local candidate="$1"
    local valid_tag

    for valid_tag in "${VALID_TAGS[@]}"; do
        if [[ "$candidate" == "$valid_tag" ]]; then
            return 0
        fi
    done

    return 1
}

# Write to a temporary file first, so an error does not destroy
# a previously valid geometry.csv.
TEMP_FILE="$(mktemp)"
trap 'rm -f "$TEMP_FILE"' EXIT

echo "filename,name,patchType" > "$TEMP_FILE"

valid_count=0
invalid_count=0

for full_path in "${STL_FILES[@]}"; do
    filename="$(basename "$full_path")"

    # Remove .stl or .STL extension.
    stem="${filename%.*}"

    # Boundary type is the text after the final underscore.
    patch_type="${stem##*_}"

    # Surface name is everything before the final underscore.
    surface_name="${stem%_*}"

    if [[ "$stem" == "$surface_name" ]]; then
        echo "ERROR: Missing boundary tag: $filename"
        echo "       Expected format: <name>_<type>.stl"
        ((invalid_count += 1))
        continue
    fi

    if ! is_valid_tag "$patch_type"; then
        echo "ERROR: Unsupported boundary tag '$patch_type': $filename"
        echo "       Valid tags: ${VALID_TAGS[*]}"
        ((invalid_count += 1))
        continue
    fi

    if [[ -z "$surface_name" ]]; then
        echo "ERROR: Empty surface name: $filename"
        ((invalid_count += 1))
        continue
    fi

    printf '%s,%s,%s\n' \
        "$filename" \
        "$surface_name" \
        "$patch_type" >> "$TEMP_FILE"

    printf 'OK: %-35s -> name=%-20s type=%s\n' \
        "$filename" \
        "$surface_name" \
        "$patch_type"

    ((valid_count += 1))
done

echo

if [[ $invalid_count -gt 0 ]]; then
    echo "Scan failed."
    echo "Valid STL files:   $valid_count"
    echo "Invalid STL files: $invalid_count"
    echo
    echo "Rename invalid STL files, then run the script again."
    exit 1
fi

mv "$TEMP_FILE" "$OUTPUT_FILE"
trap - EXIT

echo "Geometry scan completed."
echo "STL files found: $valid_count"
echo
echo "Generated:"
echo "  $OUTPUT_FILE"
echo
column -s, -t "$OUTPUT_FILE" 2>/dev/null || cat "$OUTPUT_FILE"
