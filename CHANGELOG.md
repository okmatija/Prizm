## Version 0.2.0, Unreleased

- Changed Selection Mode toggle keybinding to s from m
- Changed to flat shading by default, the old smooth shading behavior is accessible in the item context menu
- Changed rendering of back faces to use an darkened version of the front face color
- Improved rendering of mesh edges/wireframes using the SolidWireframe algorithm by Samuel Gateau
  - Fixes z-fighting/incorrect occulusion issues which could make some mesh edges invisible
  - Fixes jaggies appearing on most edges, edges belonging to only one triangle or silhouette edges still have jaggies
- Added ability to clip within a sphere when Selection Mode is enabled
  - The clipping sphere center is positioned by click(ing on a visible entity and the radius is changed by dragging the mouse and set on release
  - The clipping sphere is applied to the visible entity on which it is centered, and to any selected entities (regardless of visibility)
  - Key bindings are shown when hovering the Selection Mode checkbox, or in the help menu (press h for help)
  - Note: In future, when spatial lookups accelerate selection queries, the Selection Mode concept will be removed (it'll be always on)
- Added an option to disable back face screentone effect, accessible in the item context menu
- Added a button to show/hide this changelog (when the app was compiled) in the help menu
- Added key-bindings following the pattern: 'k' performs operation on selected items, 'C-k' on all items and 'S-k' on visible items (press 'h' for help)
- Fixed an issue where normal vectors were not affected by clipping domains
- Fixed some .obj parsing warnings and errors
- Fixed command line loading of multiple files using wildcards not working when the pattern started with a dot slash
- Fixed a rare crash which could occur when toggling visibility and there was just one item in the item list
- Changed the keybinding to rotate the camera around the selected axis in the camera control pane (press h for help)
- Increased the default max point count for selectable entities from 100,000 to 5,000,000
- Reduced the frequency of color changes in the default background shader
- Various UI and widget aligment improvements to the item context menu and camera control panels


## Version 0.1.0, 20 October 2021

Initial release. Press h for help, features not mentioned in the help message include:

- Supports simple .obj files (containing v, vn, p, l, f directives) and .wkt files (containing POINT, MULTIPOINT, LINESTRING, MULTILINESTRING directives)
- Drag and drop multiple files, or load them from command line using the '*' wildcard (e.g, `Prism.exe debug*obj` loads all non-empty obj files starting with 'debug')
- Default colors are picked using a hash of the filename
- Files can be reloaded in the item context menu or by pressing F5
  - The visual fade of the item name indicates a file load occurred
  - Files which become empty/invalid after reloading are displayed with faded-out grey text
- World axes orientation (left-handed for now) renders in the bottom left of the screen
- Console commands can be registered adding a @RegisterCommand note to procedures
