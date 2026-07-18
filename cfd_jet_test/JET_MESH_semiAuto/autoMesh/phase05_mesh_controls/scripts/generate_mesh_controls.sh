#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Phase 05 — Generate meshControls.block
#
# Input:
#   phase05_mesh_controls/config/meshControls.conf
#
# Output:
#   phase05_mesh_controls/generated/meshControls.block
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CONFIG_FILE="${1:-$PHASE_DIR/config/meshControls.conf}"
OUTPUT_FILE="${2:-$PHASE_DIR/generated/meshControls.block}"

echo "========================================"
echo "Phase 05 — General Mesh Controls"
echo "========================================"
echo
echo "Config:"
echo "  $CONFIG_FILE"
echo
echo "Output:"
echo "  $OUTPUT_FILE"
echo

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: meshControls.conf was not found:"
    echo "  $CONFIG_FILE"
    exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

required_variables=(
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
        echo "ERROR: Missing variable in config:"
        echo "  $variable_name"
        exit 1
    fi
done

mkdir -p "$(dirname "$OUTPUT_FILE")"

TEMP_FILE="$(mktemp)"
trap 'rm -f "$TEMP_FILE"' EXIT

cat > "$TEMP_FILE" <<EOF
// ============================================================
// Generated general mesh controls
// Source: $CONFIG_FILE
// ============================================================

castellatedMeshControls
{
    maxLocalCells           $MAX_LOCAL_CELLS;
    maxGlobalCells          $MAX_GLOBAL_CELLS;
    minRefinementCells      $MIN_REFINEMENT_CELLS;

    nCellsBetweenLevels     $N_CELLS_BETWEEN_LEVELS;

    resolveFeatureAngle     $RESOLVE_FEATURE_ANGLE;

    allowFreeStandingZoneFaces
                            $ALLOW_FREE_STANDING_ZONE_FACES;
}


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


addLayersControls
{
    relativeSizes           $RELATIVE_SIZES;

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
EOF

mv "$TEMP_FILE" "$OUTPUT_FILE"
trap - EXIT

echo "Created:"
echo "  $OUTPUT_FILE"
echo
echo "Phase 05 generation completed."
