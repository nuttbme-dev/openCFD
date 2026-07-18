#!/usr/bin/env bash
cd ~/Documents/nuej_jet/JET_MESH/autoMesh/phase01_scan/generated &&
rm -rf *.csv && 
cd ~/Documents/nuej_jet/JET_MESH/autoMesh/phase02_features/generated &&
rm -rf *.block  surfaceFeatureExtractDict && 
cd ~/Documents/nuej_jet/JET_MESH/autoMesh/phase02_features/config
rm -rf *.csv && 
cd ~/Documents/nuej_jet/JET_MESH/autoMesh/phase03_surface_refinement/generated &&
rm -rf *.block 
cd ~/Documents/nuej_jet/JET_MESH/autoMesh/phase03_surface_refinement/config &&
rm -rf *.csv
cd ~/Documents/nuej_jet/JET_MESH/autoMesh/phase04_regions/generated &&
rm -rf *.block 
cd ~/Documents/nuej_jet/JET_MESH/autoMesh/phase05_mesh_controls/generated &&
rm -rf *.block &&
cd ~/Documents/nuej_jet/JET_MESH/autoMesh/phase06_build/generated &&
rm -rf snappyHexMeshDict


