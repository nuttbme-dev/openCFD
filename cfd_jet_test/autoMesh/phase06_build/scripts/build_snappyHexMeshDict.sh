#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Phase 06 — Build snappyHexMeshDict
#
# Inputs:
#   phase01_scan/generated/geometry.csv
#   phase02_features/generated/features.block
#   phase03_surface_refinement/generated/refinementSurfaces.block
#   phase04_regions/generated/refinementRegions.block
#   phase05_mesh_controls/config/meshControls.conf
#   phase06_build/config/build.conf
#
# Output:
#   phase06_build/generated/snappyHexMeshDict
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AUTOMESH_DIR="$(cd "$PHASE_DIR/.." && pwd)"
CASE_DIR="$(cd "$AUTOMESH_DIR/.." && pwd)"

GEOMETRY_CSV="$AUTOMESH_DIR/phase01_scan/generated/geometry.csv"

FEATURES_BLOCK="$AUTOMESH_DIR/phase02_features/generated/features.block"

REFINEMENT_SURFACES_BLOCK="$AUTOMESH_DIR/phase03_surface_refinement/generated/refinementSurfaces.block"

REFINEMENT_REGIONS_BLOCK="$AUTOMESH_DIR/phase04_regions/generated/refinementRegions.block"

MESH_CONTROLS_CONFIG="$AUTOMESH_DIR/phase05_mesh_controls/config/meshControls.conf"

BUILD_CONFIG="$PHASE_DIR/config/build.conf"

OUTPUT_FILE="${1:-$PHASE_DIR/generated/snappyHexMeshDict}"

echo "========================================"
echo "Phase 06 — Build snappyHexMeshDict"
echo "========================================"
echo
echo "Case directory:"
echo "  $CASE_DIR"
echo
echo "Output:"
echo "  $OUTPUT_FILE"
echo

required_files=(
    "$GEOMETRY_CSV"
    "$FEATURES_BLOCK"
    "$REFINEMENT_SURFACES_BLOCK"
    "$REFINEMENT_REGIONS_BLOCK"
    "$MESH_CONTROLS_CONFIG"
    "$BUILD_CONFIG"
)

for required_file in "${required_files[@]}"; do
    if [[ ! -f "$required_file" ]]; then
        echo "ERROR: Required file was not found:"
        echo "  $required_file"
        exit 1
    fi
done

# ------------------------------------------------------------
# Load user configuration
# ------------------------------------------------------------

# shellcheck disable=SC1090
source "$MESH_CONTROLS_CONFIG"

# shellcheck disable=SC1090
source "$BUILD_CONFIG"

required_variables=(
    CASTELLATED_MESH
    SNAP
    ADD_LAYERS

    LOCATION_IN_MESH_X
    LOCATION_IN_MESH_Y
    LOCATION_IN_MESH_Z

    STL_SCALE

    MAX_LOCAL_CELLS
    MAX_GLOBAL_CELLS
    MIN_REFINEMENT_CELLS
    N_CELLS_BETWEEN_LEVELS
    RESOLVE_FEATURE_ANGLE
    ALLOW_FREE_STANDING_ZONE_FACES

    N_SMOOTH_PATCH
    TOLERANCE
    N_SOLVE_ITER
    N_RELAX_ITER
    N_FEATURE_SNAP_ITER
    IMPLICIT_FEATURE_SNAP
    EXPLICIT_FEATURE_SNAP
    MULTI_REGION_FEATURE_SNAP

    RELATIVE_SIZES
    EXPANSION_RATIO
    FINAL_LAYER_THICKNESS
    MIN_THICKNESS
    N_GROW
    FEATURE_ANGLE
    N_RELAX_ITER_LAYERS
    N_SMOOTH_SURFACE_NORMALS
    N_SMOOTH_NORMALS
    N_SMOOTH_THICKNESS
    MAX_FACE_THICKNESS_RATIO
    MAX_THICKNESS_TO_MEDIAL_RATIO
    MIN_MEDIAL_AXIS_ANGLE
    N_BUFFER_CELLS_NO_EXTRUDE
    N_LAYER_ITER

    MAX_NON_ORTHO
    MAX_BOUNDARY_SKEWNESS
    MAX_INTERNAL_SKEWNESS
    MAX_CONCAVE
    MIN_FLATNESS
    MIN_VOL
    MIN_TET_QUALITY
    MIN_AREA
    MIN_TWIST
    MIN_DETERMINANT
    MIN_FACE_WEIGHT
    MIN_VOL_RATIO
    MIN_TRI_TWIST
    N_SMOOTH_SCALE
    ERROR_REDUCTION

    MERGE_TOLERANCE
)

for variable_name in "${required_variables[@]}"; do
    if [[ -z "${!variable_name+x}" ]]; then
        echo "ERROR: Missing configuration variable:"
        echo "  $variable_name"
        exit 1
    fi
done

validate_boolean()
{
    local variable_name="$1"
    local value="${!variable_name}"

    case "$value" in
        true|false)
            ;;
        *)
            echo "ERROR: $variable_name must be true or false."
            echo "Received: $value"
            exit 1
            ;;
    esac
}

validate_boolean CASTELLATED_MESH
validate_boolean SNAP
validate_boolean ADD_LAYERS
validate_boolean ALLOW_FREE_STANDING_ZONE_FACES
validate_boolean IMPLICIT_FEATURE_SNAP
validate_boolean EXPLICIT_FEATURE_SNAP
validate_boolean MULTI_REGION_FEATURE_SNAP
validate_boolean RELATIVE_SIZES

mkdir -p "$(dirname "$OUTPUT_FILE")"

TEMP_FILE="$(mktemp)"
trap 'rm -f "$TEMP_FILE"' EXIT

# ------------------------------------------------------------
# OpenFOAM header and primary switches
# ------------------------------------------------------------

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
    object      snappyHexMeshDict;
}

castellatedMesh $CASTELLATED_MESH;
snap            $SNAP;
addLayers       $ADD_LAYERS;


// ============================================================
// Geometry
// ============================================================

geometry
{
EOF

# ------------------------------------------------------------
# Generate geometry entries from geometry.csv
# ------------------------------------------------------------

geometry_count=0

while IFS=',' read -r filename surface_name patch_type; do

    filename="${filename//$'\r'/}"
    surface_name="${surface_name//$'\r'/}"
    patch_type="${patch_type//$'\r'/}"

    [[ -z "$filename" ]] && continue

    cat >> "$TEMP_FILE" <<EOF
    "$filename"
    {
        type triSurfaceMesh;
        scale $STL_SCALE;
        name $surface_name;
    }

EOF

    printf 'Geometry: %-30s name=%s\n' \
        "$filename" \
        "$surface_name"

    ((geometry_count += 1))

done < <(tail -n +2 "$GEOMETRY_CSV")

if (( geometry_count == 0 )); then
    echo "ERROR: geometry.csv contains no surfaces."
    exit 1
fi

cat >> "$TEMP_FILE" <<'EOF'
}


// ============================================================
// Castellated mesh controls
// ============================================================

castellatedMeshControls
{
EOF

cat >> "$TEMP_FILE" <<EOF
    maxLocalCells           $MAX_LOCAL_CELLS;
    maxGlobalCells          $MAX_GLOBAL_CELLS;
    minRefinementCells      $MIN_REFINEMENT_CELLS;

    nCellsBetweenLevels     $N_CELLS_BETWEEN_LEVELS;

EOF

# ------------------------------------------------------------
# Insert features block inside castellatedMeshControls
# Remove the outer "features" indentation problem by indenting.
# ------------------------------------------------------------

sed 's/^/    /' "$FEATURES_BLOCK" >> "$TEMP_FILE"

printf '\n' >> "$TEMP_FILE"

sed 's/^/    /' "$REFINEMENT_SURFACES_BLOCK" >> "$TEMP_FILE"

printf '\n' >> "$TEMP_FILE"

sed 's/^/    /' "$REFINEMENT_REGIONS_BLOCK" >> "$TEMP_FILE"

cat >> "$TEMP_FILE" <<EOF

    resolveFeatureAngle     $RESOLVE_FEATURE_ANGLE;

    locationInMesh
    (
        $LOCATION_IN_MESH_X
        $LOCATION_IN_MESH_Y
        $LOCATION_IN_MESH_Z
    );

    allowFreeStandingZoneFaces
                            $ALLOW_FREE_STANDING_ZONE_FACES;
}


// ============================================================
// Snap controls
// ============================================================

snapControls
{
    nSmoothPatch            $N_SMOOTH_PATCH;
    tolerance               $TOLERANCE;
    nSolveIter              $N_SOLVE_ITER;
    nRelaxIter              $N_RELAX_ITER;

    nFeatureSnapIter        $N_FEATURE_SNAP_ITER;

    implicitFeatureSnap     $IMPLICIT_FEATURE_SNAP;
    explicitFeatureSnap     $EXPLICIT_FEATURE_SNAP;
    multiRegionFeatureSnap  $MULTI_REGION_FEATURE_SNAP;
}


// ============================================================
// Layer controls
// ============================================================

addLayersControls
{
    relativeSizes           $RELATIVE_SIZES;

    layers
    {
    }

    expansionRatio          $EXPANSION_RATIO;
    finalLayerThickness     $FINAL_LAYER_THICKNESS;
    minThickness            $MIN_THICKNESS;

    nGrow                   $N_GROW;
    featureAngle            $FEATURE_ANGLE;
    nRelaxIter              $N_RELAX_ITER_LAYERS;

    nSmoothSurfaceNormals   $N_SMOOTH_SURFACE_NORMALS;
    nSmoothNormals          $N_SMOOTH_NORMALS;
    nSmoothThickness        $N_SMOOTH_THICKNESS;

    maxFaceThicknessRatio   $MAX_FACE_THICKNESS_RATIO;

    maxThicknessToMedialRatio
                            $MAX_THICKNESS_TO_MEDIAL_RATIO;

    minMedialAxisAngle      $MIN_MEDIAL_AXIS_ANGLE;

    nBufferCellsNoExtrude   $N_BUFFER_CELLS_NO_EXTRUDE;
    nLayerIter              $N_LAYER_ITER;
}


// ============================================================
// Mesh quality controls
// ============================================================

meshQualityControls
{
    maxNonOrtho             $MAX_NON_ORTHO;
    maxBoundarySkewness     $MAX_BOUNDARY_SKEWNESS;
    maxInternalSkewness     $MAX_INTERNAL_SKEWNESS;

    maxConcave              $MAX_CONCAVE;
    minFlatness             $MIN_FLATNESS;

    minVol                  $MIN_VOL;
    minTetQuality           $MIN_TET_QUALITY;
    minArea                 $MIN_AREA;
    minTwist                $MIN_TWIST;
    minDeterminant          $MIN_DETERMINANT;

    minFaceWeight           $MIN_FACE_WEIGHT;
    minVolRatio             $MIN_VOL_RATIO;
    minTriangleTwist        $MIN_TRI_TWIST;

    nSmoothScale            $N_SMOOTH_SCALE;
    errorReduction          $ERROR_REDUCTION;
}


mergeTolerance              $MERGE_TOLERANCE;


// ************************************************************************* //
EOF

mv "$TEMP_FILE" "$OUTPUT_FILE"
trap - EXIT

echo
echo "Build completed."
echo "Geometry count: $geometry_count"
echo
echo "Created:"
echo "  $OUTPUT_FILE"
echo
echo "IMPORTANT:"
echo "  Verify locationInMesh before running snappyHexMesh."
