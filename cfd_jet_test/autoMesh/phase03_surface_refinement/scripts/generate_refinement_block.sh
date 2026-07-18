#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Phase 03B — Generate refinementSurfaces.block
#
# Input:
#   phase03_surface_refinement/config/refinement.csv
#
# CSV format:
#   filename,name,patchType,minLevel,maxLevel,enabled
#
# Output:
#   phase03_surface_refinement/generated/refinementSurfaces.block
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

REFINEMENT_CSV="${1:-$PHASE_DIR/config/refinement.csv}"
OUTPUT_FILE="${2:-$PHASE_DIR/generated/refinementSurfaces.block}"

echo "========================================"
echo "Phase 03B — Generate refinement block"
echo "========================================"
echo
echo "Input:"
echo "  $REFINEMENT_CSV"
echo
echo "Output:"
echo "  $OUTPUT_FILE"
echo

if [[ ! -f "$REFINEMENT_CSV" ]]; then
    echo "ERROR: refinement.csv not found:"
    echo "  $REFINEMENT_CSV"
    echo
    echo "Run first:"
    echo "  $PHASE_DIR/scripts/generate_refinement_csv.sh"
    exit 1
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

TEMP_FILE="$(mktemp)"
trap 'rm -f "$TEMP_FILE"' EXIT

cat > "$TEMP_FILE" <<'EOF'
refinementSurfaces
{
EOF

surface_count=0

while IFS=',' read -r filename surface_name patch_type min_level max_level enabled; do

    filename="${filename//$'\r'/}"
    surface_name="${surface_name//$'\r'/}"
    patch_type="${patch_type//$'\r'/}"
    min_level="${min_level//$'\r'/}"
    max_level="${max_level//$'\r'/}"
    enabled="${enabled//$'\r'/}"

    [[ -z "$filename" ]] && continue

    enabled_lower="$(printf '%s' "$enabled" | tr '[:upper:]' '[:lower:]')"

    if [[ "$enabled_lower" != "true" &&
          "$enabled_lower" != "yes" &&
          "$enabled_lower" != "1" ]]; then

        printf 'Skipped: %-30s enabled=%s\n' \
            "$surface_name" \
            "$enabled"

        continue
    fi

    if ! [[ "$min_level" =~ ^[0-9]+$ ]]; then
        echo "ERROR: minLevel must be an integer."
        echo "Surface: $surface_name"
        echo "Value:   $min_level"
        exit 1
    fi

    if ! [[ "$max_level" =~ ^[0-9]+$ ]]; then
        echo "ERROR: maxLevel must be an integer."
        echo "Surface: $surface_name"
        echo "Value:   $max_level"
        exit 1
    fi

    if (( min_level > max_level )); then
        echo "ERROR: minLevel cannot be greater than maxLevel."
        echo "Surface: $surface_name"
        echo "Level:   ($min_level $max_level)"
        exit 1
    fi

    case "$patch_type" in
        patch|wall|empty|symmetry|symmetryPlane|wedge|cyclic)
            ;;
        *)
            echo "ERROR: Unsupported patch type:"
            echo "  $patch_type"
            echo "Surface:"
            echo "  $surface_name"
            exit 1
            ;;
    esac

    cat >> "$TEMP_FILE" <<EOF
    $surface_name
    {
        level ($min_level $max_level);

        patchInfo
        {
            type $patch_type;
        }
    }

EOF

    printf 'Added: %-30s type=%-14s level=(%s %s)\n' \
        "$surface_name" \
        "$patch_type" \
        "$min_level" \
        "$max_level"

    ((surface_count += 1))

done < <(tail -n +2 "$REFINEMENT_CSV")

cat >> "$TEMP_FILE" <<'EOF'
}
EOF

if [[ $surface_count -eq 0 ]]; then
    echo
    echo "ERROR: No enabled surfaces were found."
    exit 1
fi

mv "$TEMP_FILE" "$OUTPUT_FILE"
trap - EXIT

echo
echo "Created:"
echo "  $OUTPUT_FILE"
echo
echo "Enabled surface count: $surface_count"
