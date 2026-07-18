#!/usr/bin/env bash
cd ~/Documents/nuej_jet/JET_MESH/autoMesh/phase01_scan/scripts &&
./scan_geometry.sh && 

cd ~/Documents/nuej_jet/JET_MESH/autoMesh/phase02_features/scripts &&
./generate_surfaceFeature.sh && 
./generate_features_csv.sh &&
./generate_features_block.sh &&
cd ~/Documents/nuej_jet/JET_MESH/autoMesh/phase03_surface_refinement/scripts &&
./generate_refinement_csv.sh &&
./generate_refinement_block.sh &&
cd ~/Documents/nuej_jet/JET_MESH/autoMesh/phase04_regions/scripts &&
./generate_refinement_regions.sh &&
cd ~/Documents/nuej_jet/JET_MESH/autoMesh/phase05_mesh_controls/scripts &&
./generate_mesh_controls.sh &&
cd ~/Documents/nuej_jet/JET_MESH/autoMesh/phase06_build/scripts &&
./build_snappyHexMeshDict.sh


