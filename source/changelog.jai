PRISM_VERSION_WIP :: App.Version.{VERSION_STRING, #string DONE
- Improved performance of ray intersection queries against Mesh items
- Added a 'custom' build option which runs a gui at compile-time where the user can set build options and choose which console commands are available
- Added option to add index/centroid labels to triangles and segments for mesh or polyline/polygon items respectively
- Fixed labels not clipping against clipping volumes
- Fixed lexer not considering decimal strings with an 'e', but no '.', to be floats
- Fixed a crash when requesting point label rendering for point clouds
- Fixed a bug where changes to the float labelling format on a selection of elements was ignored
- Fixed a performance problem caused by a missing early-out of text rendering code
- Removed cursor warping when sweeping over checkboxes, sweeping still works but only uses the cursor y position
- Various minor UI improvements related to window positioning, colors and tooltips
DONE
};

PRISM_VERSION_0_1_2 :: App.Version.{"0.1.2, 4 January 2022", #string DONE
- Improvements to the console:
  - Command history is saved and loaded to a `console_history.txt` file in the current working directory to preserve it across sessions
  - Added command documentation strings automatically deduced from the comment preceeding the procedure in the Jai source code
  - When tab-completion yields a unique result the command documentation is printed to the console log
  - Renamed console-specific commands to start with a `console_` prefix
  - Console command error checking now supports unsigned integers
- Added some new commands to the console:
  - `find_open_edges` adds an item containing the soup of edges belonging to only one triangle in the given mesh item
  - `perturb_positions` modifies the position data of an item to randomly chosen new positions on spheres of a given radius centered on the original positions
  - `make_Grid` adds a 3D grid item
  - `make_Grid_on_near/far_plane` adds 2D grid items filling the camera near/far planes
  - `make_Grid_on_xy/yz/zx_plane` adds 2D grid items on the xy/yz/zx planes through the current orbit point
  - `make_Grid_on_xyz_planes` adds 2D grid items on the xy, yz and zx planes through the current orbit point
  - Tip: When using `make_Grid_on_*_plane` add grids with multiple resolutions /before/ adjusting the camera to get nicely aligned multi-resolution overlays
  - Tip: The orbit points can be set on a model using C-RMB in Selection Mode, the orbit can be reset to 0,0,0 in the camera control UI.
- Refactored UI code to use the Dear ImGui 1.85 module bundled with the Jai compiler
- Fixed a bug where the rendering mode couldn't be switched using the combo box
- Fixed a bug where the item generation index wasn't properly displayed when more than one item with the same name was loaded
- Simplified the help panel, application settings have been moved there as well (press h for help)
- Sample shapes are now in a top-level shapes/ folder, previously they were in a nested one (data/shapes/)
DONE
};

PRISM_VERSION_0_1_1 :: App.Version.{"0.1.1, 1 December 2021", #string DONE
- Changed Selection Mode toggle keybinding to s from m
- Changed to flat shading by default, the old smooth shading behavior is accessible in the item context menu
- Changed rendering of back faces to use an darkened version of the front face color
- Improved rendering of mesh edges/wireframes using the SolidWireframe algorithm by Samuel Gateau
  - Fixes z-fighting/incorrect occulusion issues which could make some mesh edges invisible
  - Fixes jaggies appearing on most edges, edges belonging to only one triangle or silhouette edges still have jaggies
- Added ability to clip within a sphere when Selection Mode is enabled (i.e., when the Selection item is visible)
  - The clipping sphere center is positioned by clicking on a visible entity and the radius is changed by dragging the mouse and set on release
  - The clipping sphere is applied to the visible entity on which it is centered, and to any selected entities (regardless of visibility)
  - Key bindings are shown when hovering the Selection Mode checkbox, or in the help menu (press h for help)
  - Note: In future, when spatial lookups accelerate selection queries, the Selection Mode concept will be removed (it'll be always on)
- Added an option to disable back face screentone effect, accessible in the item context menu
- Added a button to show/hide this changelog (as it appeared when the app was compiled) in the help menu
- Added some key-bindings following the pattern: key-only performs operation on selected items, control-key performs on all items and shift-key performs on visible items (press 'h' for help)
- Fixed an issue where normal vectors were not affected by clipping domains
- Fixed some .obj parsing warnings and errors
- Fixed command line loading of multiple files using wildcards not working when the pattern started with a dot slash
- Fixed a rare crash which could occur when toggling visibility and there was just one item in the item list
- Changed the keybinding to rotate the camera around the selected axis in the camera control pane (press h for help)
- Increased the default max point count for selectable entities from 100,000 to 5,000,000
- Reduced the frequency of color changes in the default background shader
- Various UI and widget aligment improvements to the item context menu and camera control panels
DONE
};

PRISM_VERSION_0_1_0 :: App.Version.{"0.1.0, 20 October 2021", #string DONE
Initial release. Press h for help, features not mentioned in the help message include:

- Supports simple .obj files (containing v, vn, p, l, f directives) and .wkt files (containing POINT, MULTIPOINT, LINESTRING, MULTILINESTRING directives)
- Drag and drop multiple files, or load them from command line using the '*' wildcard (e.g, `Prism.exe debug*obj` loads all non-empty obj files starting with 'debug')
- Default colors are picked using a hash of the filename
- Files can be reloaded in the item context menu or by pressing F5
  - The visual fade of the item name indicates a file load occurred
  - Files which become empty/invalid after reloading are displayed with faded-out grey text
- World axes orientation (left-handed for now) renders in the bottom left of the screen
- Console commands can be registered adding a @RegisterCommand note to procedures
DONE
};

init_changelog :: () {
    array_add(*app.changelog, PRISM_VERSION_WIP);
    array_add(*app.changelog, PRISM_VERSION_0_1_2);
    array_add(*app.changelog, PRISM_VERSION_0_1_1);
    array_add(*app.changelog, PRISM_VERSION_0_1_0);
}
