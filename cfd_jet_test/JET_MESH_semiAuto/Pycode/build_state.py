import os

CASE_DIR = "/home/nuttbme/Documents/nuej_jet/JET_MESH"
PYCODE_DIR = os.path.join(CASE_DIR, "Pycode")

exec(open(os.path.join(PYCODE_DIR, "load_stl.py")).read())
exec(open(os.path.join(PYCODE_DIR, "Zcolor.py")).read())
exec(open(os.path.join(PYCODE_DIR, "save_state.py")).read())
