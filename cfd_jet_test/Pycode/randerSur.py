from paraview.simple import *

view = GetActiveViewOrCreate("RenderView")

representation_map = {
    "1": "Surface",
    "2": "Surface With Edges",
    "3": "Wireframe",
}

while True:
    print()
    print("1 = Surface")
    print("2 = Surface With Edges")
    print("3 = Wireframe")
    print("0 = Exit")
    print()

    choice = input("Select mode: ").strip().lower()

    if choice in ("0", "q", "quit", "exit"):
        print("Representation controller closed.")
        break

    if choice not in representation_map:
        print("Invalid input. Use 1, 2, 3, or 0.")
        continue

    representation = representation_map[choice]

    for source in GetSources().values():
        display = GetDisplayProperties(source, view=view)
        display.Representation = representation

        if representation == "Surface With Edges":
            display.EdgeColor = [0.0, 0.0, 0.0]
            display.LineWidth = 1.0

        elif representation == "Wireframe":
            display.LineWidth = 1.0

    Render(view)

    print("Changed to:", representation)
