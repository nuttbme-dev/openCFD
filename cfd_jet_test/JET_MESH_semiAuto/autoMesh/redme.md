Phase 0 — Geometry Source
cfd_jet_test/
└── constant/
    └── triSurface/
        ├── inlet_patch.stl
        ├── object_wall.stl
        ├── cone1_wall.stl
        ├── cone2_wall.stl
        ├── front_empty.stl
        └── back_empty.stl

โฟลเดอร์นี้เป็น source of truth ของ geometry

Phase 1 — Scan Geometry
autoSnappy/
├── phase01_scan/
│   ├── scripts/
│   └── generated/

หน้าที่:

อ่าน constant/triSurface/*.stl
แยกชื่อ surface
แยก tag จาก filename
สร้าง geometry inventory

output:

autoSnappy/phase01_scan/generated/geometry.csv
Phase 2 — Surface Features
autoSnappy/
├── phase02_features/
│   ├── config/
│   ├── scripts/
│   └── generated/

หน้าที่:

กำหนด feature extraction
กำหนด feature level
สร้าง surfaceFeatureExtractDict
สร้าง features block
Phase 3 — Surface Refinement
autoSnappy/
├── phase03_surface_refinement/
│   ├── config/
│   ├── scripts/
│   └── generated/

หน้าที่:

กำหนด minLevel
กำหนด maxLevel
กำหนด patch type
สร้าง refinementSurfaces block
Phase 4 — Refinement Regions
autoSnappy/
├── phase04_regions/
│   ├── config/
│   ├── scripts/
│   └── generated/

หน้าที่:

อ่าน geometry bounds
สร้าง refinement zones
สร้าง refinementRegions block
Phase 5 — Mesh Controls
autoSnappy/
├── phase05_mesh_controls/
│   ├── config/
│   ├── scripts/
│   └── generated/

หน้าที่:

maxLocalCells
maxGlobalCells
nCellsBetweenLevels
resolveFeatureAngle
locationInMesh
Phase 6 — Dictionary Build
autoSnappy/
├── phase06_build/
│   ├── templates/
│   ├── scripts/
│   └── generated/

หน้าที่:

รวม geometry
รวม features
รวม refinementSurfaces
รวม refinementRegions
รวม mesh controls
สร้าง snappyHexMeshDict
Phase 7 — Validation and Run
autoSnappy/
├── phase07_run/
│   ├── scripts/
│   └── logs/

หน้าที่:

foamDictionary
surfaceFeatureExtract
snappyHexMesh
checkMesh
Full structure
cfd_jet_test/
├── constant/
│   └── triSurface/
│
├── system/
│
└── autoSnappy/
    ├── phase01_scan/
    │   ├── scripts/
    │   └── generated/
    │
    ├── phase02_features/
    │   ├── config/
    │   ├── scripts/
    │   └── generated/
    │
    ├── phase03_surface_refinement/
    │   ├── config/
    │   ├── scripts/
    │   └── generated/
    │
    ├── phase04_regions/
    │   ├── config/
    │   ├── scripts/
    │   └── generated/
    │
    ├── phase05_mesh_controls/
    │   ├── config/
    │   ├── scripts/
    │   └── generated/
    │
    ├── phase06_build/
    │   ├── templates/
    │   ├── scripts/
    │   └── generated/
    │
    └── phase07_run/
        ├── scripts/
        └── logs/
