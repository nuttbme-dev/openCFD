from paraview.simple import *
import colorsys
import glob
import os

STL_DIR = "/home/nuttbme/Documents/nuej_jet/JET_MESH/constant/triSurface"

# ล้าง source เก่าใน Pipeline Browser
for source in list(GetSources().values()):
    Delete(source)

view = GetActiveViewOrCreate("RenderView")
view.Background = [1.0, 1.0, 1.0]

# อ่านชื่อ STL ทั้งหมดอัตโนมัติ
stl_files = sorted(
    glob.glob(os.path.join(STL_DIR, "*.stl")) +
    glob.glob(os.path.join(STL_DIR, "*.STL"))
)

if not stl_files:
    raise RuntimeError("No STL files found in: " + STL_DIR)

number_of_files = len(stl_files)

for index, full_path in enumerate(stl_files):

    filename = os.path.basename(full_path)
    source_name = os.path.splitext(filename)[0]

    # กระจาย Hue ให้แต่ละไฟล์มีสีไม่เหมือนกัน
    hue = index / float(number_of_files)

    red, green, blue = colorsys.hsv_to_rgb(
        hue,
        0.70,   # saturation
        0.90    # brightness
    )

    color = [red, green, blue]

    stl = STLReader(
        registrationName=source_name,
        FileNames=[full_path]
    )

    display = Show(stl, view)

    # บังคับเป็น Solid Color
    ColorBy(display, None)

    display.Representation = "Surface"
    display.DiffuseColor = color
    display.AmbientColor = color
    display.Opacity = 1.0

    print(
        "{:<20} color = [{:.3f}, {:.3f}, {:.3f}]".format(
            filename,
            red,
            green,
            blue
        )
    )

ResetCamera(view)
Render(view)

print()
print("Loaded {} STL files.".format(number_of_files))
