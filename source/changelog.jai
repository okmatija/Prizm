/*

Directories support (0.2.4)
-------------------
Test it, I have seen crashes when I add or remove directories
Make sure starting watching a directory works well
nocommit Fix flat shading not working on all backfaces when backface mode is set to .FIXED??
nocommit Fix selection color not working across directories
nocommit Fix sizing of help window and directory loading window. Look up the child window thing
nocommit Highlight background of folder name when doing RMB menu
nocommit RMB on preset group and command output group
nocommit make the table in the folder UI nicer (sorting, )

OBJ support (0.3.0)
-----------
>>> Improve the obj loading, make it work when indices are negative, and make the vertices store normals and tangents too
Fix the missing annotations when reading file: E:\Dropbox\Prism\shapes-novc\Debug_Points_-1.000_+0.000_+0.000.obj
Fix annotations on polyline soup entities
Make -1 reference the last item in the item list, so you can run commands without knowing the entity index, this can be used make commands put into obj file comments work, particularly color related ones
Just handle comments on the p directive, concat them with the comment on the vertex..?
Check that floats with + starting them are parsed
Is there a more robust string to float method?
Don't crash when loading an invalid obj file e.g., delete vertices in the cube but keep the faces
TODO Make mesh.normals.count == mesh.indices.count so we can support a separate normal at each face vertex, currently the code uses per-vertex normals which is very restrictive
Asynchronously load files
Enable visualization of tangent vectors

Misc
----
nocommit Make the changelog more readable when its very long

*/


// TODO Integrate a newer version of Simp and make it share the context so that rendering works correctly
// TODO Refactor selection mode: decouple from clipping sphere mode, support multiple selection sets, allow selection of triangles
// TODO Fix sphere clipping not working right after perturbing vertices. Load cube twice, perturb by a significant amount. Note that sphere clipping seems to work on the original cube geometry.
// TODO Make action buttons cycle forward with LMB and backward with RMB? or maybe if you scroll while on them
// TODO Fix missing shading when using face-normal rendering. looks like its just a solid color??
// TODO Make tooltips over item color square show the shortcuts
// TODO Implement multiple selection objects and make them imgui selectable widgets that behave like the item list ones

PRISM_VERSION_0_2_4 :: App.Version.{"0.2.4", "WIP", #string DONE
- Improved item reloading behaviour:
  - Items which are preset shapes are 'reloaded' by calling their creation functions again
  - Items which are outputs of console commands 'reloaded' by re-evaluating the console command string. Note:
    - It is up to the command author to define the semantics of this operation.
    - This feature makes the make_Grid_on_near_plane command more useful as it can be re-evaluated after you move the camera. This function is still mostly a weird experiment though.
  - Items are reloaded in order of decreasing creation time, with items loaded from disk preceeding console command output items or preset shape items
    - This heuristic is designed to give the expected behaviour in simple cases like reload a file from disk, run command A on it and then run command B on the output of command A
- Added a feature where Shift LMB on the item name will center the camera on the item and have the item fill the screen while positioning near/far planes so the rest of the scene is visible
- Changed sort_by_name command to make it case insensitive
- Removed select_remove_selected_items since this is easily accomplished by making a selection and pressing the delete key
- Preset buttons now act consistently with the global duplicate file behaviour setting (located under the 'Settings' in the help menu)
- Detected changes to file mod time (using GetFileTime/stat.st_mtime on windows/linux resp.) and changes to file size on disk. Related behaviour changes:
  - Changed the timestamp associated with items loaded from disk to be the file mod time. Previously this was the time the file was loaded into Prism.
  - Changed reload item button so its disabled if the file mod time and file size are unchanged from when the file was first loaded. The old behaviour where reloads can be triggered with no constraints by unchecking the 'Disable reload if file unchange' box in under Settings. Press h for help
  - Added an asterisk to the end of item names for items read from disk if the file has been modified or has changed size since it was loaded
  - Added a checkbox to enable auto-reloading when the file of an item read from disk is modified
- Changed the behaviour of .obj loading so it logs warnings and tries to display broken geometry rather failing to load the shape
  - Missing normals (occuring when a face uses an index which exceeds the number of normals in the file) are set to zero
  - Missing vertices (occuring when a face uses an index which exceeds the number of vertices in the file) are positioned at an "Invalid Point" position
  - Vertices with invalid components (inf/nan) have those components set to the corresponding component of "Invalid Point"
  - Normals/tangents with invalid components (inf/nan) have those components set to zero
  - Invalid faces are ignored in some cases, in other cases we still fail to parse and don't load the shape
  - Note: The "Invalid Point" defaults to (0,0,0) but is customizable under 'Options' in the main panel
- Added item grouping
  - Items loaded from files on disk are grouped in the item list according to their containing directory path name
  - Items loaded from preset buttons are grouped together
  - Items created by console commands are grouped together
  - Directories dropped into Prism will create directory groups which default to auto loading/reloading any contained files
  - If files are added to a directory that already exists give that file the auto load state
- TODO Deduplicated vertices in the cube.obj preset shape
- Fixed issue where files loaded from the commandline used a relative rather than absolute filename
- Updated to compiler version beta 0.1.036
DONE
};

PRISM_VERSION_0_2_3 :: App.Version.{"0.2.3", "26 May 2022", #string DONE
- Added a basic annotation functionality where comments in obj files are parsed and stored on the items
  - Annotations are accessible in a foldable section in the item context menu
  - Standalone/block comments are collected and any comment starting the file is displayed in a tooltip when the item is hovered, this can be disabled under 'Options' in the main panel
  - End of line comments after v/f/l directives are associated with the corresponding point/face/line and can be used to focus the relevant element
  - Note that the 'p' directive needed for point clouds does not accept annotations, put these on 'v' instead
- Changed the default color for the 'solid color' background option to make it a lighter grey
- Added a new 'item_flip_normals' command which works triangle mesh items
- Added a new 'item_focus_segment' command which works like the existing 'item_focus_triangle'/'item_focus_vertex'
- Added a item visibility checkbox under the 'Rendering' section of the item context menu, this can also be used to toggle visibility of multiple items
- Fixed alignment of the 'Reload'buttons in the item context menu
- Fixed a bug where preset items were cleared when pressing the 'Reload' button in the item context menu
- Fixed a bug where the camera wouldn't follow the cursor correctly after running a item_focus_vertex command was executed
- Fixed a bunch of bugs that occur when items have non-identity transforms because of various confusions between model/world space
DONE
};

PRISM_VERSION_0_2_2 :: App.Version.{"0.2.2", "18 May 2022", #string DONE
- Improved performance of text label rendering (Fixes ISSUE_004)
- Reorganised the main panel:
  - Moved the item list into a foldable 'Items' section and added a button to add preset shapes which are baked into the executable, press 'F1' to load a cube and 'F2' to load a "widget"
  - Added the selection item into a new 'Selections' section, in future we'll add the ability to have multiple selection items
  - Moved some settings which were previously in the help menu into an 'Options' section
- Improvements/changes to the UI:
  - Clarified which item(s) are being modified by the item context menu by adding a border to the popup window and setting the target item(s) background rect color
  - Clarified cycle/toggle state of action buttons by changing the button color
  - Added an alternative UI for 'Actions' (a.k.a. state changes applied to groups of items), this UI is accessible via RMB on the 'Actions' section in the main panel
  - Added a button under the 'Changelog' section of the help menu to save the changelog to disk. This is useful for searching the changelog
  - Added a button in the console Options menu to save the console log to disk. This is useful for searching log messages
  - Added a keybinding 'x' to clear all element and vertex text labels from target items (target items depend on the modifiers pressed, see the 'Actions' section tooltip)
- Added `item_copy_clipping_ranges` and `item_copy_clipping_sphere` commands and extended the names of `select_remove` and `select_toggle` to be more descriptive
- Fixed a bug where normals on the points of a 3D polyline soup were not rendered
- Fixed a bug where clipping sphere mode activated on all items when no items were selected but in that case it should only activate on the intersected item
DONE
};

PRISM_VERSION_0_2_1 :: App.Version.{"0.2.1", "27 March 2022", #string DONE
- Changed the modifier used to make mouse scrolling zoom into the camera look position from Control to Shift
  - This change improves the UX when looking at small details with clip spheres/`item_focus_*` commands because the user can hold Shift while rotating/zooming/clipping the scene
  - Note: The original Ctrl Scroll binding was chosen to match the Ctrl RMB binding for setting the orbit point, but those operations clashed in an annoying way (which was easy to notice but hard to explain)
- Improvements to the console:
  - Added an 'Options' button next to the input box which can toggle between interactive and transparent console log modes and enable/disable scrolling to new log output
    - In interactive mode the console log captures mouse input so the user can scroll through log messages by hovering over the log (eventually copy/paste from the log will also work here)
    - In transparent mode the console log ignores mouse inputs so the user can interact with the scene behind the console while still reading console log text. This is the default mode
  - Moved the world axes to the bottom right so it doesn't obscure text in transparent mode
  - Made the Console scroll to the bottom when a new log message is posted, this can be turned off in the Options menu
  - Added ability to scroll the console log by using the scroll wheel when hovering over the console input text field. This works regardless of interactive/transparent mode
  - Changed the command documentation output color to make it more clear when autocomplete has narrowed down to only one option
  - Renamed 'console_show_history', 'console_clear_history' and 'console_clear_log' to 'console_history_show', 'console_history_clear' and 'console_log_clear' for better autocomplete namespacing
  - Renamed functions operating on an item to have a common 'item_' prefix. The 'debug_*' functions which operate on an item are changed though
  - Changed the 'select_if*' functions to keep existing selections and just add to them
  - Added new 'select_toggle' and 'select_remove' functions
  - Improved the `item_focus_vertex' and 'item_focus_triangle` commands to give more intuitive results and added an option to also update the item's clipping sphere
- Improvements to rendering:
  - Improved the lighting/shading to use a camera-aligned directional light, so each triangle is has a constant lighting across it indicating its angle
  - Fixed flat shading breaking at high zoom levels (Fixes ISSUE_003)
  - Added more shading modes for backfacing triangles and exposed a cycle button/keybinding to change them
  - Changed the default backface shading mode to use a fixed pinkish color
- Renamed the potentially confusing 'Tgl Item Viz' button which didn't really behave like a toggle button when pressed without a modifier. Now its called 'Edit Item Viz'
- Replaced four 'Tgl Elem/Vert IDs/XYZ' buttons with two 'Cyc Elem/Vert Label' buttons which cycle through having all four combinations of index/position label visibility
  - Changed the keybinding for cycling opacity to 'o', which is was made available by the above change
- Changed the UX for text rendering, now point/element labels are rendering within a disk around the cursor, default radius 200 pixels
  - This is useful as a workaround for slow text rendering, but will probably also be a permanent feature since its helpful for reducing label clutter
  - The radius of the disk can be changed (along with other label settings) via RMB on the label action buttons. Note each item caches its own copy of these settings
- Fixed the tooltip for the 'Reload Items' button when it operates on visible items (i.e., when no modifier key is down)
- Fixed some unituitive/strange behaviour related to selecting vertices (normals were being used, and were sometimes incorrect due to unitialized memory, now normals are ignored)
- Fixed an issue where 'Ctrl RMB' did not allow placing the camera orbit on vertices which were not reference by a line/triangle
- Various minor improvements to the item context menu
DONE
};

PRISM_VERSION_0_2_0 :: App.Version.{"0.2.0", "15 March 2022", #string DONE
- Major UI/UX overhaul/improvements:
  - Changed the key-binding modifier pattern introduced in Version 0.1.1
    - Key-only bindings act on visible items, this allows the corresponding buttons to do something by default
    - Control modified bindings act on selected items, this is consistent with control LMB selecting items in the Item List
    - Shift modified bindings act on all items
  - Added a sliders to the camera UI so that the near and far clippings planes can be adjusted
  - Added a Actions menu to the Item List with buttons whose behaviour can be modified with modifier keys following pattern described above
  - Added a 'Known issues' section to the help menu
  - Changed the initial camera look direction to be along .{-1,-1,-1}
  - Changed defaults so the camera max zoom out is not limited by the scene bounding sphere, this can be toggled the help menu User Settings
  - Changed the binding to fit the visible items on screen from 'r' to 'f'
  - Changed the bindings to toggle the console and entire UI to '`' and 'Ctrl `', previously these were the other way around
  - Removed cursor warping when sweeping over checkboxes, sweeping still works but only uses the cursor y position
  - Various minor improvements related to window positioning, colors and tooltips
- Improved performance of ray intersection queries against Mesh items
- Added a 'custom' build option which runs a gui at compile-time where the user can set build options and choose which console commands are available
- Added option to add index/centroid labels to triangles and segments for mesh or polyline/polygon items respectively
- Added `focus_on_triangle` and `focus_on_vertex` commands to position the camera so the triangle/vertex of index mostly fills the screen
- Fixed labels not clipping against clipping volumes
- Fixed lexer not considering decimal strings with an 'e', but no '.', to be floats
- Fixed a crash when requesting point label rendering for point clouds
- Fixed a bug where changes to the float labelling format on a selection of elements was ignored
- Fixed a performance problem caused by a missing early-out of text rendering code
DONE
};

PRISM_VERSION_0_1_2 :: App.Version.{"0.1.2", "4 January 2022", #string DONE
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

PRISM_VERSION_0_1_1 :: App.Version.{"0.1.1", "1 December 2021", #string DONE
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

PRISM_VERSION_0_1_0 :: App.Version.{"0.1.0", "20 October 2021", #string DONE
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
    array_add(*app.changelog, PRISM_VERSION_0_2_4);
    array_add(*app.changelog, PRISM_VERSION_0_2_3);
    array_add(*app.changelog, PRISM_VERSION_0_2_2);
    array_add(*app.changelog, PRISM_VERSION_0_2_1);
    array_add(*app.changelog, PRISM_VERSION_0_2_0);
    array_add(*app.changelog, PRISM_VERSION_0_1_2);
    array_add(*app.changelog, PRISM_VERSION_0_1_1);
    array_add(*app.changelog, PRISM_VERSION_0_1_0);
}
