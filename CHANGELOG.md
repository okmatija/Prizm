## Version 0.2.0, Unreleased

- Changed to flat shading by default, the old smooth shading behavior is accessible in the item context menu
- Changed rendering of back faces to use an darkened version of the front face color
- Reduced the frequency of color changes in the default background shader
- Added an option to disable back face screentone effect, accessible in the item context menu
- Increased the default max point count for selectable entities from 100,000 to 5,000,000
- Fixed some .obj parsing warnings being incorrectly logged as errors


## Version 0.1.0, 20 October 2021

Press h for help.  Features not mentioned in the help message include:

- Supports simple .obj files (containing v, vn, p, l, f directives) and .wkt files (containing POINT, MULTIPOINT, LINESTRING, MULTILINESTRING directives)
- Drag and drop multiple files, or load them from command line using the '*' wildcard (e.g, `Prism.exe debug*obj` loads all non-empty obj files starting with 'debug')
- Default colors are picked using a hash of the filename
- Files can be reloaded in the item context menu or by pressing F5
  - The visual fade of the item name indicates a file load occurred
  - Files which become empty/invalid after reloading are displayed with faded-out grey text
- World axes orientation (left-handed for now) renders in the bottom left of the screen
- Console commands can be registered adding a @RegisterCommand note to procedures
