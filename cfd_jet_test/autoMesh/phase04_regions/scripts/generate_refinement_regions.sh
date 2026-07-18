#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Phase 04 — Generate refinementRegions.block
#
# Input:
#   phase04_regions/config/refine.txt
#   phase01_scan/generated/geometry.csv
#
# Supported syntax:
#
#   + <name> inside <level>
#   + <name> distance <distance> <level>
#
# Examples:
#
#   + object inside 4
#   + inlet distance 0.005 2
#
# Output:
#   phase04_regions/generated/refinementRegions.block
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AUTOMESH_DIR="$(cd "$PHASE_DIR/.." && pwd)"

REFINE_FILE="${1:-$PHASE_DIR/config/refine.txt}"
GEOMETRY_CSV="${2:-$AUTOMESH_DIR/phase01_scan/generated/geometry.csv}"
OUTPUT_FILE="${3:-$PHASE_DIR/generated/refinementRegions.block}"

echo "========================================"
echo "Phase 04 — Generate refinementRegions"
echo "========================================"
echo
echo "Refinement list:"
echo "  $REFINE_FILE"
echo
echo "Geometry inventory:"
echo "  $GEOMETRY_CSV"
echo
echo "Output:"
echo "  $OUTPUT_FILE"
echo

if [[ ! -f "$REFINE_FILE" ]]; then
    echo "ERROR: refine.txt was not found:"
    echo "  $REFINE_FILE"
    exit 1
fi

if [[ ! -f "$GEOMETRY_CSV" ]]; then
    echo "ERROR: geometry.csv was not found:"
    echo "  $GEOMETRY_CSV"
    exit 1
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

TEMP_FILE="$(mktemp)"
trap 'rm -f "$TEMP_FILE"' EXIT

# ------------------------------------------------------------
# Check whether a geometry name exists in geometry.csv
# ------------------------------------------------------------
geometry_exists()
{
    local target_name="$1"

    awk -F',' -v target="$target_name" '
        NR > 1 {
            gsub(/\r/, "", $2)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)

            if ($2 == target) {
                found = 1
                exit
            }
        }

        END {
            exit(found ? 0 : 1)
        }
    ' "$GEOMETRY_CSV"
}

cat > "$TEMP_FILE" <<'EOF'
refinementRegions
{
EOF

region_count=0
line_number=0

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do

    ((line_number += 1))

    # Remove Windows carriage returns
    raw_line="${raw_line//$'\r'/}"

    # Trim leading and trailing spaces
    line="$(printf '%s' "$raw_line" |
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    # Skip blank lines
    [[ -z "$line" ]] && continue

    # Skip comments
    [[ "$line" == \#* ]] && continue

    # Only active lines beginning with +
    if [[ "$line" != +* ]]; then
        echo "Warning: ignored line $line_number:"
        echo "  $raw_line"
        continue
    fi

    # Remove leading +
    line="${line#+}"

    # Trim again
    line="$(printf '%s' "$line" |
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    read -r -a fields <<< "$line"

    if (( ${#fields[@]} < 3 )); then
        echo "ERROR: Invalid syntax at line $line_number:"
        echo "  $raw_line"
        exit 1
    fi

    geometry_name="${fields[0]}"
    mode="${fields[1]}"

    if ! geometry_exists "$geometry_name"; then
        echo "ERROR: Geometry name was not found in geometry.csv."
        echo "Line: $line_number"
        echo "Name: $geometry_name"
        exit 1
    fi

    case "$mode" in

        inside)
            if (( ${#fields[@]} != 3 )); then
                echo "ERROR: Invalid inside syntax at line $line_number."
                echo
                echo "Expected:"
                echo "  + <name> inside <level>"
                echo
                echo "Received:"
                echo "  $raw_line"
                exit 1
            fi

            level="${fields[2]}"

            if ! [[ "$level" =~ ^[0-9]+$ ]]; then
                echo "ERROR: inside level must be an integer."
                echo "Line:  $line_number"
                echo "Value: $level"
                exit 1
            fi

            cat >> "$TEMP_FILE" <<EOF
    $geometry_name
    {
        mode inside;

        levels
        (
            (1E15 $level)
        );
    }

EOF

            printf 'Added: %-25s mode=inside   level=%s\n' \
                "$geometry_name" \
                "$level"
            ;;

        distance)
            if (( ${#fields[@]} != 4 )); then
                echo "ERROR: Invalid distance syntax at line $line_number."
                echo
                echo "Expected:"
                echo "  + <name> distance <distance> <level>"
                echo
                echo "Received:"
                echo "  $raw_line"
                exit 1
            fi

            distance="${fields[2]}"
            level="${fields[3]}"

            if ! [[ "$distance" =~ ^[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?$ ]]; then
                echo "ERROR: distance must be numeric."
                echo "Line:  $line_number"
                echo "Value: $distance"
                exit 1
            fi

            if ! [[ "$level" =~ ^[0-9]+$ ]]; then
                echo "ERROR: distance level must be an integer."
                echo "Line:  $line_number"
                echo "Value: $level"
                exit 1
            fi

            cat >> "$TEMP_FILE" <<EOF
    $geometry_name
    {
        mode distance;

        levels
        (
            ($distance $level)
        );
    }

EOF

            printf 'Added: %-25s mode=distance distance=%s level=%s\n' \
                "$geometry_name" \
                "$distance" \
                "$level"
            ;;

        *)
            echo "ERROR: Unsupported refinement mode at line $line_number."
            echo "Mode: $mode"
            echo
            echo "Supported modes:"
            echo "  inside"
            echo "  distance"
            exit 1
            ;;
    esac

    ((region_count += 1))

done < "$REFINE_FILE"

cat >> "$TEMP_FILE" <<'EOF'
}
EOF

mv "$TEMP_FILE" "$OUTPUT_FILE"
trap - EXIT

echo
echo "Generation completed."
echo "Active refinement regions: $region_count"
echo
echo "Created:"
echo "  $OUTPUT_FILE"

if (( region_count == 0 )); then
    echo
    echo "No active '+' entries were found."
    echo "An empty refinementRegions block was generated."
fi
