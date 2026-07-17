# ParaView STL Automation Workflow

## 1. Purpose

This workflow automatically:

1. Loads all STL geometry files.
2. Creates one ParaView source for each STL file.
3. Assigns a different solid color to each source.
4. Applies additional ParaView actions.
5. Saves the complete ParaView pipeline as a state file.
6. Opens ParaView using the generated state.

The workflow is designed so that each action is stored in a separate Python file. This makes the system easier to modify and extend.

---

## 2. Project Structure

```text
cfd_jet_test/
├── STL/
│   ├── back.stl
│   ├── front.stl
│   ├── inlet.stl
│   ├── object.stl
│   └── ...
│
├── Pycode/
│   ├── load_stl.py
│   ├── Zcolor.py
│   ├── save_state.py
│   ├── build_state.py
│   └── paraviewCall.sh
│
└── jet_stl_state.pvsm

## shell in paraview

### set RenderView

from paraview.simple import *; view=GetActiveViewOrCreate("RenderView"); [setattr(GetDisplayProperties(s, view=view), "Representation", "Wireframe") for s in GetSources().values()]; Render(view)

