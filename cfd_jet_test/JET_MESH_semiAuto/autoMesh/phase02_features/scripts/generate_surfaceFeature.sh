#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Phase 02 — Generate surfaceFeatureExtractDict
#
# Input:
#   phase01_scan/generated/geometry.csv
#
# CSV format:
#   filename,name,patchType
#
# Output:
#   phase02_features/generated/surfaceFeatureExtractDict
#
# Usage:
#   ./phase02_features/scripts/generate_surfaceFeature.sh
#
# Optional:
#   ./phase02_features/scripts/generate_surfaceFeature.sh \
#       path/to/geometry.csv \
#       path/to/outputDict \
#       150
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AUTOMESH_DIR="$(cd "$PHASE_DIR/.." && pwd)"

DEFAULT_CSV="$AUTOMESH_DIR/phase01_scan/generated/geometry.csv"
DEFAULT_OUTPUT="$PHASE_DIR/generated/surfaceFeatureExtractDict"

GEOMETRY_CSV="${1:-$DEFAULT_CSV}"
OUTPUT_FILE="${2:-$DEFAULT_OUTPUT}"
INCLUDED_ANGLE="${3:-150}"

echo "========================================"
echo "Phase 02 — Surface Feature Dictionary"
echo "========================================"
echo
echo "Input CSV:"
echo "  $GEOMETRY_CSV"
echo
echo "Output dictionary:"
echo "  $OUTPUT_FILE"
echo
echo "Included angle:"
echo "  $INCLUDED_ANGLE"
echo

if [[ ! -f "$GEOMETRY_CSV" ]]; then
    echo "ERROR: geometry.csv was not found:"
    echo "  $GEOMETRY_CSV"
    echo
    echo "Run Phase 01 first:"
    echo "  $AUTOMESH_DIR/phase01_scan/scripts/scan_geometry.sh"
    exit 1
fi

if ! [[ "$INCLUDED_ANGLE" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "ERROR: includedAngle must be numeric."
    echo "Received: $INCLUDED_ANGLE"
    exit 1
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

TEMP_FILE="$(mktemp)"
trap 'rm -f "$TEMP_FILE"' EXIT

cat > "$TEMP_FILE" <<EOF
/*--------------------------------*- C++ -*----------------------------------*\\
| =========                 |                                                 |
| \\\\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox           |
|  \\\\    /   O peration     |                                                 |
|   \\\\  /    A nd           |                                                 |
|    \\\\/     M anipulation  |                                                 |
\\*---------------------------------------------------------------------------*/

FoamFile
{
    format      ascii;
    class       dictionary;
    object      surfaceFeatureExtractDict;
}

// Generated automatically from:
// $GEOMETRY_CSV

EOF

surface_count=0

while IFS=',' read -r filename surface_name patch_type; do

    filename="${filename//$'\r'/}"
    surface_name="${surface_name//$'\r'/}"
    patch_type="${patch_type//$'\r'/}"

    filename="$(printf '%s' "$filename" |
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    surface_name="$(printf '%s' "$surface_name" |
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    patch_type="$(printf '%s' "$patch_type" |
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    [[ -z "$filename" ]] && continue

    cat >> "$TEMP_FILE" <<EOF
// name: $surface_name
// type: $patch_type
"$filename"
{
    extractionMethod  extractFromSurface;

    extractFromSurfaceCoeffs
    {
        includedAngle $INCLUDED_ANGLE;
    }

    writeObj           yes;
}

EOF

    printf 'Added: %-35s name=%-20s type=%s\n' \
        "$filename" \
        "$surface_name" \
        "$patch_type"

    ((surface_count += 1))

done < <(tail -n +2 "$GEOMETRY_CSV")

if [[ $surface_count -eq 0 ]]; then
    echo
    echo "ERROR: No surfaces were found in:"
    echo "  $GEOMETRY_CSV"
    exit 1
fi

cat >> "$TEMP_FILE" <<'EOF'

// ************************************************************************* //
EOF

mv "$TEMP_FILE" "$OUTPUT_FILE"
trap - EXIT

echo
echo "Generation completed."
echo "Surface count: $surface_count"
echo
echo "Created:"
echo "  $OUTPUT_FILE"
