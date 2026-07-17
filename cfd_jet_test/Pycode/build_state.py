import os

CASE_DIR = "/home/nuttbme/Documents/git/openCFD/cfd_jet_test"
PYCODE_DIR = os.path.join(CASE_DIR, "Pycode")

exec(open(os.path.join(PYCODE_DIR, "load_stl.py")).read())
exec(open(os.path.join(PYCODE_DIR, "Zcolor.py")).read())
exec(open(os.path.join(PYCODE_DIR, "save_state.py")).read())
