#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Phase 02B — Generate features.block
#
# Input:
#   phase02_features/config/features.csv
#
# CSV format:
#   filename,name,patchType,featureLevel,enabled
#
# Output:
#   phase02_features/generated/features.block
#
# Example:
#   top1_patch.stl -> top1_patch.eMesh
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

FEATURES_CSV="${1:-$PHASE_DIR/config/features.csv}"
OUTPUT_FILE="${2:-$PHASE_DIR/generated/features.block}"

echo "========================================"
echo "Phase 02B — Generate features.block"
echo "========================================"
echo
echo "Input:"
echo "  $FEATURES_CSV"
echo
echo "Output:"
echo "  $OUTPUT_FILE"
echo

if [[ ! -f "$FEATURES_CSV" ]]; then
    echo "ERROR: features.csv not found:"
    echo "  $FEATURES_CSV"
    echo
    echo "Run first:"
    echo "  $PHASE_DIR/scripts/generate_features_csv.sh"
    exit 1
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

TEMP_FILE="$(mktemp)"
trap 'rm -f "$TEMP_FILE"' EXIT

cat > "$TEMP_FILE" <<'EOF'
features
(
EOF

feature_count=0

while IFS=',' read -r filename surface_name patch_type feature_level enabled; do

    filename="${filename//$'\r'/}"
    surface_name="${surface_name//$'\r'/}"
    patch_type="${patch_type//$'\r'/}"
    feature_level="${feature_level//$'\r'/}"
    enabled="${enabled//$'\r'/}"

    filename="$(printf '%s' "$filename" |
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    surface_name="$(printf '%s' "$surface_name" |
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    feature_level="$(printf '%s' "$feature_level" |
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    enabled="$(printf '%s' "$enabled" |
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    [[ -z "$filename" ]] && continue

    enabled_lower="$(printf '%s' "$enabled" |
        tr '[:upper:]' '[:lower:]')"

    if [[ "$enabled_lower" != "true" &&
          "$enabled_lower" != "yes" &&
          "$enabled_lower" != "1" ]]; then

        printf 'Skipped: %-30s enabled=%s\n' \
            "$surface_name" \
            "$enabled"

        continue
    fi

    if ! [[ "$feature_level" =~ ^[0-9]+$ ]]; then
        echo "ERROR: featureLevel must be an integer."
        echo "Surface: $surface_name"
        echo "File:    $filename"
        echo "Value:   $feature_level"
        exit 1
    fi

    # Convert STL filename to eMesh filename:
    # top1_patch.stl -> top1_patch.eMesh
    stl_stem="${filename%.*}"
    emesh_file="${stl_stem}.eMesh"

    cat >> "$TEMP_FILE" <<EOF
    {
        file "$emesh_file";
        level $feature_level;
    }

EOF

    printf 'Added: %-25s file=%-35s level=%s\n' \
        "$surface_name" \
        "$emesh_file" \
        "$feature_level"

    ((feature_count += 1))

done < <(tail -n +2 "$FEATURES_CSV")

cat >> "$TEMP_FILE" <<'EOF'
);
EOF

mv "$TEMP_FILE" "$OUTPUT_FILE"
trap - EXIT

echo
echo "Created:"
echo "  $OUTPUT_FILE"
echo
echo "Enabled feature count: $feature_count"
