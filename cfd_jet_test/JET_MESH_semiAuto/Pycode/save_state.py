from paraview.simple import *
import os

CASE_DIR = "/home/nuttbme/Documents/nuej_jet/JET_MESH"
STATE_FILE = os.path.join(CASE_DIR, "jet_stl_state.pvsm")

view = GetActiveViewOrCreate("RenderView")

ResetCamera(view)
Render(view)
SaveState(STATE_FILE)

print("State saved:", STATE_FILE)
