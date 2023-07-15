PRISM_VERSION_0_7_0 :: App.Version.{"0.7.0", "WIP", #string DONE
- New Feature: Attributes TODO Add a feature flag for enabling this

  - Attributes are complementary to annotations but are intended to be dense (every mesh element will have a value) overlays of typed data associated with mesh elements (vertex/face/edge/halfedges...). Currently string, float, Vector3, Matrix3 types are supported. The concept of annotations has been refined to be a sparse overlay of string data attached mesh elements which are addressable via the .obj format e.g., vertices via lines starting with the 'v' directive, and faces via lines starting with the 'f' directive
  - TODO Added a new preset shape prism_obj_format_reference.obj which functions as a demo of how the semantic obj comments in Prism will work. This shape is also available via the Preset button.
  - Multiple attributes are supported, and each will have its own tab in the item context menu
  - TODO Added a preset example to demonstrate the new annotation functionality
DONE};

PRISM_VERSION_0_6_1 :: App.Version.{"0.6.1", "WIP", #string DONE
- Changes to api/cpp/Prism.h

  - Changed the default value of set_precision() from 6 to std::numeric_limits<double>::max_digits10 so it can be used to restore the default precision (which is std::numeric_limits<double>::max_digits10). Also added an optional pointer argument which can return the previous precision.
  - Renamed and renamed set_precision_max_digits10() function to set_precision_to_roundtrip_floats() and added an optional pointer argument which can return the previous precision.
  - Removed the set_precision_digits10() since it doesn't guarantee round-trip float -> text -> float conversions
  - Added index arguments to the point2/point3, segment2/segment3 and triangle2/triangle3 functions, all indices are defaulted to negative values which write the same string as before this change
  - Added an attribute() function with no arguments, similar to the annotation() function with no arguments, and move the attribute functions further down the function list to present simpler concepts on first reading
  - Improved the documentation

- Changes to api/cpp/Prism_Unreal.h

  - Added a function to create an Obj from UE::Geometry::TDynamicMeshOverlay. This function visualizes the overlay elements as annotated point elements where the annotations include element id and element value attributes.

- Improved support for annotations:

  - Replaced the single annotations settings which affected all annotations with separate settings for vertices/points/segments/triangles
  - TODOOO Due to the above change the old "Rendering" and "Labeling" sections of the Detail panel are replaced with fields in the new "Vertices", "Points", "Segments", "Triangles" sections

- Improved support for normals:

  - Added support for `f i//a j//b k//c` lines in the .obj file where i,j,k can be different from  a,b,c (previously this was only working if i,j,k==a,b,c)
  - Added support for oriented polylines and oriented point clouds i.e., `l i//a j//b k//c` and `p i//a j//b k//c` lines in the .obj file 
  - Added an option to normalize obj normal data (vn-directives) before applying normal scaling. This is on by default to preserve old behaviour, you could turn it off if the length of the normals in the .obj file is encoding something interesting.
DONE};

PRISM_VERSION_0_6_0 :: App.Version.{"0.6.0", "10 May 2023", #string DONE
- Added a header-only C++ API for writing .obj files with Prism-specific extensions

  - Usage: Navigate to the "Prism > Tools > API > C++", configure the API by pressing checkboxes and press the button to copy the relevant string (containing #includes and config #defines) to your clipboard, then paste that string into the file you want to debug
  - The API has functions to write geometry in plain .obj format (based on http://paulbourke.net/dataformats/obj/) as well as functions to write Prism-specific extensions e.g., annotations and command annotations. See the `Prism::documentation()` function for more info
  - The API optionally supports working with Unreal data types and module dependencies are optional (e.g., API functions using types/headers from the GeometryCore module can be excluded if you want to use the API in a module which doesn't depend on GeometryCore)
  - The API can be configured to be usable with small standalone projects in which case the it will only depend on the C++ STL (future work could remove this)
  - Having this debug code live outside your project is a feature since it ensures you can't accidentally commit code which writes out objs to production: your CI/CD pipeline should fail to compile because it won't be able to find the Prism API headers

- Improved behavior of buttons along the bottom of the screen

  - Buttons are now hidden when bottom of the screen when there is no selection since they require a selection to work. We could have just disabled them but we chose to hide them instead.
  - Buttons are now colored to reflect the underlying state. Different hues represent different states, when the buttons are transparent they are in the default state.
  - The implementation has been reworked in various ways to achieve a more do-what-I-mean behavior
  - The changes also affect the corresponding shortcuts

- Added support for obj files with f-directives connecting more than 3 vertices (aka polygon elements represented as triangle fans). Any annotation will be is added to each triangle separately
- Added support for obj files with l-directives connecting more than 2 vertices (aka polyline elements). Any annotation will be is added to each segment element separately
- Added a build warning when the compiler version used to compile Prism is different from the expected one (aka the one Matija is using)
- Added a suggestion to the file written by the button "Help > Changelog > Save to CHANGELOG.md" to suggest you read the changelog on https://markdownlivepreview.com
- Added a bunch of `set_XXX` console commands to configure display/rendering state for items loaded in Prism e.g., `set_annotation_visible` to set annotation label visibility for a given item.  These functions are callable as command annotations in the C++ API
- Added a Reload button under "Details > Display > Selection" which now always appears. Previously it was only visible when more than one item was selected
- Removed `item_` prefix for some console commands, e.g., `item_set_primary_color` -> `set_primary_color`
- Fixed a bug where annotation labels were not show when only annotation labels were requested
- Fixed a minor bug where the order of items changed when items were deleted, previously the last item in the list would replace the deleted item
DONE};

PRISM_VERSION_0_5_1 :: App.Version.{"0.5.1", "17 Feburary 2023", #string DONE
- Fixed a bug where obj files with command annotations that should have created more than one item were not working
- Fixed a bug where obj files with 2D vertex directives (e.g., `v 1 2`) where not parsed correctly
- Fixed a bug where the state displayed by some widgets in the Details pane when multiple items were selected was incorrect
- Fixed a crash that could happen while building spatial indices
- Fixed a bug where `*` wildcard matching only searched paths nested below the executable location. For now `*` is only accepted when matching filenames, for example:
  - `Prism.exe ../Path/To/Debug/*obj` works
  - `Prism.exe ../Debug/h*/cube.obj` does not
- Added a `load` command which can be called while Prism is running to load files as if they were given via the command line on startup
  - The example above can be implemented in the console using `load "../Path/To/Debug/*obj"`
- Added a `pwd` command which prints the directory containing the Prism executable, which can be useful if you want to pass relative paths to `load`
- Improved text labeling so it skips checking against elements (points, lines, triangles) which are not definitely not going to be visible
- Improved text labeling on overlapping geometry in some cases

DONE};

PRISM_VERSION_0_5_0 :: App.Version.{"0.5.0", "15 January 2023", #string DONE
- Changes to the UI

  - Made the Light theme the default, the Dark theme can be set in "Edit > Preferences > Appearance"
  - Removed the "Remove" buttons item are now removed by selecting them and pressing the delete key
  - Removed the item context menu which was accessed with RMB on the item name, there is now a "Details" section which shows that information
  - Removed the selection context menu which was accessed with RMB on a selected item, when multiple items are selected the "Details" section shows common data which, when edited, is applied to all items in the selection. 
  - Adopted a more idiomatic layout for application options with new Edit/View/Help tabs. In future we'll move these to the OS application window
  - Added boxes around the widgets within sections, to make it visually clearer what options are in what section
  - Reduced the spacing between items in the item/annotation lists/tables
  - Removed header annotations (the first block of obj comments) from the item name tooltips by default, these can be turned on under "Edit > Preferences > Miscellaneous"
  - Improved the layout/presentation in general. Most notably in the "Labeling", "Clipping" and "Information" sections and the key bindings sections in the "Help" tab
  - Improved the clipping sphere UI by intializing the sphere to bound the aabb of the item selection being clipped
  - Fixed some section header not extending for the full window width
  - Fixed some buttons which were not working
  - Note: UI changes can be annoying but this should happen less as we move towards something more familiar/idiomatic (to users of Unreal/Blender). Planned future work, just FYI, is:
    - Clarify when widgets in the "Details" section have multiple values e.g., using tri-state checkboxes where tick => ON, no-tick => OFF and solid fill => some selected items ON, others OFF
    - Figure out how to make a usable borderless SDL window and Move Prism/Edit/View/Help tabs into the OS window
    - Move to imgui's docking branch to add dockable/resizable windows which will be useful when we expand functionality to add data to geometry

- Changes to shortcuts

  - Pressing 'f' key
    - Old behavior: Focus visible items (i.e., set camera planes/look position/eye position) 
    - New behavior: Focus selected items, and pressing multiple times toggles between filling the screen with selected or visible items
    - Improved the accuracy of the focussing by accounting for clipping spheres. Clipping ranges will be accounted for in future work
  - Pressing 'p' key
    - Old behavior: Cycle vertex point rendering
    - New behavior: None
  - Pressing 'v' key
    - Old behavior: None
    - New behavior: Cycle vertex point rendering
    - Note: This key is a better mnemonic now that point elements (obj p-directives) and vertices (obj v-directives) are distinguished. There is no shortcut for cycling point element size, this can be done in the "Rendering" section of the items details
  - Clicking LMB on an item name
    - Old behavior: Focussed the item
    - New behavior: Sets the item selection to the clicked item. With Ctrl also down, toggle the item in the selection
  - Clicking LMB on an item in the viewport
    - Old behavior: None
    - New behavior: Sets the item selection to the clicked item or clears the selection if click is far from any items. With Ctrl also down, toggle the item in the selection
  - Changed how modifier keys Ctrl/Shift affect item state changing shortcuts (e.g., 'i', 'j', 'k', 'l' etc)
    - Old behavior: Ctrl applied the state change to selected items, Shift applied the state change to all items
    - New behavior: Modifiers have no effect, all shortcuts target selected items when the shortcuts are pressed unmodified

- Changes to .obj file loading

  - New Feature: Comments ignored by Prism
    - Any text on a line after a second # is ignored. This a way to add text to the obj file in a way that it will be ignored by Prism
    - An Annotation in Prism is now the text between two # characters
  - New Feature: Command Annotations
    - Annotations starting with an exclamation mark (lines starting #!) are "command annotations": the text following the ! is interpreted as a console command and is executed after parsing all the geometry in the file
    - In future this feature will be expanded to do things like map data annotated on mesh triangles to triangle edges and we may change the policy on when the commands are executed
    - Examples of command annotations (note the second # starts a comment ignored by Prism and is a convenient place to document the effect/intent of the command):

      #! prism_log "hello world!"         # Prints "hello world!" to the console as the file is loaded
      #! item_set_primary_color 0 255 0 0 # Sets the highest-dimensional element color to red. Note if you change the color of the item and then reload it a different feature preserves the manually changed color
      #! item_find_open_edges 0           # Finds triangle edges not shared by another triangle and adds them as segments
      #! item_find_open_edges 0 1         # As above, but puts the segments into a new item, after a file with this line is loaded two items are created. If you want to run a command on the created item its index will be 1

  - Added support for multiple element types in the same item. Previously Prism could only load objs which were entirely triangles, entirely segments or entirely points
  - Added support for negative indices, so a file containing the text "v 0 0 0\n  v 1 0 0\n  l 1 2" is equivalent to a file containing the text "v 0 0 0\n  v 1 0 0\n  l -2 -1"
    - Useful so you don't need to track the current vertex index, or if you're writing a triangle soup where it can reduce the file size

- Changes to label rendering

  - Added a new "ray-cast" Labeling mode in which labels are shown on the intersected/closest point/segment/triangle
    - The ray-cast Labeling mode is the new default
    - The ray-cast Labeling mode uses "Closest-Point Query Radius" which can be set in the "Edit > Preferences > Viewport" tab
    - The old "spotlight" Labeling mode can be enabled in the "Edit > Preferences > Labeling" section but note it still has the problem of not checking for occlusion
  - Improved issues with overlapping text labels
    - Labels of the same type and on the same item no longer overlap (e.g., index labels of two coincident points). This is probably the most common case
    - Labels of different types but on the same item can still overlap (e.g., a point index label and an annoation on that point). Future work will fix this case
    - Labels of the same type on different items can still overlap. Future work will fix this case
  - Removed the option to skip labeling back-facing triangles/oriented points since it was just confusing and not very useful
  - Removed the per-item label formatting options. Formatting options are now global and can be edited in the "Edit > Preferences > Labeling" section
  - Increased the default label scale from .3 to .4

- Changes to geometry selection:

  - Geometry selection is enabled/visible only when the "Prism > Tools > Select" section is open since the shortcuts are shared with the item selection mentioned under shortcuts above
  - Added ability to select triangles and segments as well points/vertices. What element gets selected is controlled by a radio button
  - This feature is very basic will be expanded/improved in future, feature requests welcome
  - Fixed strange coupling between geometry selection and sphere clipping mode, previously sphere clipping would only work when selecting geometry was enabled

- Changes to console commands

  - Added `item_clear_points`, `item_clear_segments` and `item_clear_triangles` commands
  - Added a parameter to `item_find_open_edges` which can be used to add the edges as segments in the target item rather than creating a new item. By default this new parameter modifies the target item, the old behavior can be recovered by passing 1 (true) for the new parameter.
  - Added an `item_find_unreferenced_positions` function which finds any positions (v-directives) which are not referenced by any element (p-, l- or f-directives) and then explicitly adds them as point elements.
  - Added an `item_find_zero_area_triangles` command which adds a new item containing all the zero area triangles
  - Added an `item_set_primary_color` command which sets the color of the highest-dimensional element (triangle > segment > point) in the mesh
  - Added parameters to the `select_if_empty` and `select_if_match` commands to invert the selection (Note you can also invert selections using the `Alt a` shortcut)
  - Removed `select_if_Mesh`, `select_if_Polygon_Soup`, `select_if_Polyline_Soup2` and `select_if_Polyline_Soup3` commands since they make less sense with the data structure changes mentioned in the obj loading section
  - Improved error reporting when a console command was not found
  - Fixed some incorrectly formatted command log output

- Miscellaneous changes

  - Fixed bug where the transform was not accounted for in mesh merging operations which affected geometry selection and the `debug_spatial_index` command
  - Fixed annoying behavior where the camera could orbit a bit after the orbit was placed via Ctrl RMB because the orbit code was not checking that Ctrl is not pressed
  - Removed the annotations UI when multiple items are selected, this was confusing, you can only inspect annotations when exactly one item is selected now
  - Added a setting to adjust the closest point query max distance in pixels. Change this to adjust how close the mouse click needs to be to select vertices/seed a clipping sphere, the default value is 20 pixels
  - Added feature to clipping sphere mode where engaging the mode (Shift LMB) while the cursor is far from the shape being clipped the entire shape is shown in a wireframe/point rendering so you can easily see the original unclipped shape
  - Added a very early prototype for "Demo Mode", which can be enabled under the "Options" tab.  Demo Mode will show mouse/key presses in the viewport and is intended to help with screen shares/demos
DONE
};

PRISM_VERSION_0_4_0 :: App.Version.{"0.4.0", "6 October 2022", #string DONE
- Improvements to Annotations:

  - Moved annotations into a separate "Annotations" tab in the item context menu
  - Added a radio button to populate the table with the annotations of a particular kind (vertex/line/face/block). Removed the now redundant "Target" column
  - Fixed annotations starting with a number but continued with a string being inferred to be number type rather than string type
  - Fixed strange coupling between annotation labels and vertex/face labels

- Changes to Main Panel UI:

  - Added a new "Help" tab which shows what was previously in the help menu. Removed the help binding 'h' because help is more discoverable now
  - Added a new "Options" tab which show options that were previously in a folding tree
  - Added a new "Items" tab which shows the list of items and the Selection UI
  - Added a new "Tools" section under the "Items" tab which has the "Reload", "Focus" and "Add" buttons as well as an item representing a "Point Selection"
  - Fixed incorrect positioning of item context menu when an item folder had a vertical scroll bar 

- Changes to Point Selection mechanics (selection here means picking out bits of geometry):

  - Renamed the "Default" selection to "Point Selection" since this object can only select points (using Ctrl LMB)
  - Replaced the old "Clear" with a "Cache" button adds the selection as an item in a "Selections" folder and then clears the selection. This is how users can make multiple selections
  - Removed the old "Add" button, which wasn't implemented but won't be needed because caching selections is the way user can to create/manage multiple selections
  - Changed the "Point Selection" color widget to also affect the color of the label text. The labels can be colored differently via the context menu, and still default to black
  - Note: A minor quirk with the "Cache" button is that in order to clear an item selection you cache it and then remove the added item. I didn't think it was worth the extra UI clutter for an additional button..
  - Note: Future versions will add "Triangle Selection" and "Edge Selection" UI, but this is not yet implemented

- Changes to Items list selection (selection here means picking items for bulk actions):

  - Added ability to select all items in a folder by using Ctrl LMB on the folder name
  - Added ability to change the color of selected items by editing the color widget of a selected item
  - Added ability to reset the color and display mode of selected items by pressing MMB on a selected item
  - Added ability to cycle the display mode of selected items by pressing RMB on a selected item
  - Added ability to change visibility of a selected item by changing the visibility of a selected item with a mouse click.
  - Note: Changing visibility by sweeping the mouse over a selected item's checkbox will not propogate the visibility change to other selected items, this is intended
  - Note: "Remove" button is the only widget in the item list that doesn't affect the whole selection when triggered on a selected item. To remove the whole selection press delete, or use the button in the item selection context menu
  - Note: The current plan is that having MMB reset values is an idiom which will be applied in other situations in future versions
  - Removed the 'Toggle folder selection' and 'Toggle folder visibility' buttons in the folder context menu since these operations can be accomplished using the above selection methods and the delete key (or item selection context menu)

- Changes to preset shapes:

  - Added two new preset shapes representing failed booleans courtesy of Jimmy Andrews, load them with F3 and F4, they have been annotated to function as a kind of Prism tutorial
  - Multiple instances of the same preset are generated with different names and hence colors.
  - Added a random shift transform when presets are added, the transform can be set to identity by holding Alt when adding the preset via the button (not the hotkey!)
  - Disabled reloading of preset shapes for code architecture reasons, will re-enable this functionality in a future version

- Added an initial version of a light color theme, you can set it under the "Options" tab
- Removed the limit on degree of zoom by changing the default value of `Options > Advanced > camera_zoom_min_screen_filling_length_mm` from 0.0001 to 0.0
- Improved UX when enabling visibility on previously hidden triangle/segment/point-based geometry which had triangles/segments/points not visible, enabling item visibility also enables visibility of the primary geometric primitive (triangles/segments/points)
- Fixed `item_focus_vertex`, `item_focus_segment`, `item_focus_triangle` and `item_find_open_edges` so they work for items with non-identity world_from_model transforms
DONE
};

PRISM_VERSION_0_3_1 :: App.Version.{"0.3.1", "22 September 2022", #string DONE
- Replaced the buttons previously in the "Actions" menu of the Item List with "Update" buttons along the bottom edge of the viewport. Update buttons work in the same way as the action buttons did but this was never properly explained, so here is how things work: Each item has its own settings struct storing geometry/text rendering info (point size, line width, clipping shape etc), there is also a stand-alone "template" setting struct which is used to implement the update buttons. When an update button is pressed two things happen: first, the corresponding member in the template is changed and second, the change is copied over to the settings struct of each targetted item. Note this template setting struct is also used to implement the selection context menu which appears when you RMB on a selected item in the item list (use Ctrl LMB to select an item in the Item List)

  - Update buttons toggle or cycle state of the targetted items (see the tooltips) and are triggered by pressing the corresponding button/keyboard shortcut
  - When an update returns to its initial/default setting the button flashes blue and briefly displays "Default" rather than the usual label
  - Changed face labeling update from cycling face index and centroid to just toggling the face index.  Centroid coordinates can still be set via item/selection context menu (RMB on an item/selection)
  - Changed all labeling actions to have a smaller default radius when labeling in a disk around the cursor (now its 50 pixels, previously it was 200 pixels)
  - Added new "Focus"/"Reload" buttons into the Item List next to the "Add" button, these act like update buttons in that modifier keys control which item set (visible, selected or all) are targetted

- Improved Annotation support:

  - Added in-viewport Annotation visualization which can be toggled using the new keybinding `k`, or via the new "Annotations" update button
  - Annotations on vertices/faces/edges are visualized in the same way as labels ie positioned at the vertex, or face/edge centroids
  - Changed keybinding `x` so that it also clears the labels associated with annotations
  - Improved the table view in the "Annotations" section of the item context menu:
    - Made the table look nicer and enabled various useful ImGui table options. Press RMB on the table header to see them
    - Made the "Annotation" and "Index" columns sortable (LMB on the column header performs the sort)
    - Fixed performance when scrolling though long lists of annotations
  - Added an initial version of typed annotations:
    - If the string following a # successfully parses as a float it will be stored as a float annotation, otherwise it will be stored as a string annotation
    - Type information is currently only used to implement sorting of the "Annotation" column
    - See `shapes/Edge_Soup.obj` for an example

- Changes to .obj file loading:
  - Files containing only `l` directives and 3D vertices (.z == 0) are loaded as a segment soup. Previously they were being silently converted to a polyline soup (array of arrays of points) which was annoying/unexpected because the edge numbering changes. In a later version this conversion will be implemented via a console command
  - Segment soups support annotations (polyline soups currently do not)

- Improved handling of long item lists by adding a scrolling region when displaying all items would exceed a threshold. This threshold can be customized in "Options > Advanced > Item List Max Size Before Scroll"
- Fixed performance when scrolling though long lists of messages in the console log
- Fixed annoying UI where item reload buttons were disabled when the item was unchanged on disk, now only the F5 shortcut is disabled in that case. A tooltip is displayed warning the user that they will be reloading an unchanged item
DONE
};

PRISM_VERSION_0_3_0 :: App.Version.{"0.3.0", "6 September 2022", #string DONE
- Improved item reloading behavior

  - Detected changes to file mod time (using GetFileTime/stat.st_mtime on windows/linux resp.) and changes to file size on disk. Related behavior changes:
  - Preset shapes are reloaded by calling their creation functions
  - Outputs of console commands are reloaded by calling their console command string. It is up to the command author to support command reloading in a way that makes sense
  - Items are reloaded in order of decreasing creation time, with items loaded from disk preceeding console command output items or preset shape items. This heuristic is designed to give the expected behavior in simple cases like reload a file from disk, run command A on it and then run command B on the output of command A
  - Changed reload item button so its disabled if the file mod time and file size are unchanged from when the file was first loaded. The old behavior where reloads can be triggered with no constraints by unchecking the 'Disable reload if file unchange' option
  - Added an asterisk to the end of item names for items read from disk if the file has been modified or has changed size since it was loaded
  - Added a checkbox to enable auto-reloading when the file of an item read from disk is modified

- Added item folders

  - Items loaded from files on disk are grouped in the item list according to their containing directory path name
  - Items loaded from preset buttons are grouped together in a 'Preset shapes' folder
  - Items created by console commands are grouped together in a 'Command output' folder
  - Directories dropped into Prism will create folders which default to auto loading/reloading any contained files
  - If files are added to a directory that already exists give that file the auto load state

- Changed the behavior of .obj loading so it logs warnings and tries to display broken geometry rather failing to load the shape

  - Missing normals (occuring when a face uses an index which exceeds the number of normals in the file) are set to zero
  - Missing vertices (occuring when a face uses an index which exceeds the number of vertices in the file) are positioned at an "Invalid Point" position
  - Vertices with invalid components (inf/nan) have those components set to the corresponding component of "Invalid Point"
  - Normals/tangents with invalid components (inf/nan) have those components set to zero
  - Invalid faces are ignored in some cases, in other cases we still fail to parse and don't load the shape
  - Note: The "Invalid Point" defaults to (0,0,0) but is customizable under 'Options' in the main panel

- Changes to console commands

  - The 'make_Grid_on_near_plane' command is more useful now since reloading it overwrites the existing item
  - The 'sort_by_name' command is now case insensitive
  - Removed 'select_remove_selected_items' since this is easily accomplished by making a selection and pressing the delete key

- Misc UI improvements

  - Added ability to change the global font scale using the slider in the Options menu, this is basic and can become blocky, it'll be reworked at some point
  - Added a feature where Shift LMB on the item name will center the camera on the item and have the item fill the screen while positioning near/far planes so the rest of the scene is visible
  - Changed the timestamp associated with items loaded from disk to be the file mod time. Previously this was the time the file was loaded into Prism.

- Fixed preset buttons so they act consistently with the global duplicate file behavior option
- Fixed issue where files loaded from the commandline used a relative rather than absolute filename
- Fixed issue where backfaces were not always rendered properly when the render mode was set to .NORMALS
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
- Fixed some unituitive/strange behavior related to selecting vertices (normals were being used, and were sometimes incorrect due to unitialized memory, now normals are ignored)
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
  - Added a Actions menu to the Item List with buttons whose behavior can be modified with modifier keys following pattern described above
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
- Fixed a bug where changes to the float Labeling format on a selection of elements was ignored
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
    //array_add(*app.changelog, PRISM_VERSION_0_7_0);
    array_add(*app.changelog, PRISM_VERSION_0_6_1);
    array_add(*app.changelog, PRISM_VERSION_0_6_0);
    array_add(*app.changelog, PRISM_VERSION_0_5_1);
    array_add(*app.changelog, PRISM_VERSION_0_5_0);
    array_add(*app.changelog, PRISM_VERSION_0_4_0);
    array_add(*app.changelog, PRISM_VERSION_0_3_1);
    array_add(*app.changelog, PRISM_VERSION_0_3_0);
    array_add(*app.changelog, PRISM_VERSION_0_2_2);
    array_add(*app.changelog, PRISM_VERSION_0_2_1);
    array_add(*app.changelog, PRISM_VERSION_0_2_0);
    array_add(*app.changelog, PRISM_VERSION_0_1_2);
    array_add(*app.changelog, PRISM_VERSION_0_1_1);
    array_add(*app.changelog, PRISM_VERSION_0_1_0);
}
