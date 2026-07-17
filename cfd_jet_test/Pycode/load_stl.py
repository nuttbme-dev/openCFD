from paraview.simple import *
import glob
import os

STL_DIR = "/home/nuttbme/Documents/git/openCFD/cfd_jet_test/STL"

stl_files = sorted(
    glob.glob(os.path.join(STL_DIR, "*.stl")) +
    glob.glob(os.path.join(STL_DIR, "*.STL"))
)

if not stl_files:
    raise RuntimeError("No STL files found in: " + STL_DIR)

view = GetActiveViewOrCreate("RenderView")

for full_path in stl_files:
    filename = os.path.basename(full_path)
    source_name = os.path.splitext(filename)[0]

    stl = STLReader(
        registrationName=source_name,
        FileNames=[full_path]
    )

    Show(stl, view)

print("Loaded", len(stl_files), "STL files")

