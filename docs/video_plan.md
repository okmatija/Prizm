# How to make the Video Tutorials

## Preparation

* Put the video test data in a C:/Demo/ to not dox your filesystem
* Run [ScreenToGif](https://www.screentogif.com/) and drag the gunsight icon on the Prizm window to resize to it, the bottom border should shift down a bit manually. Use ~30fps, webms compress well so you won't exceed the 10MB limit for github wiki images
* Make sure tooltips don't obscure things e.g., tooltips in console can obscure the command documentation
* Bring up explorer/notepad without using use alt tab since if that pops up over Prizm during the recording it looks bad.
* Note: Before implementing Demo Mode the plan was to use [Keyviz](https://github.com/mulaRahul/keyviz) to show the key presses, it runs in the background so to edit settings you need to look at its icon in the tray in the bottom right of your desktop. Configure it to show the overlay on the left and position the Prizm window so Keyviz renders in the bottom left of the Prizm window, it has nice graphics/animations for key presses, we could do a similar thing at some point so making a note here for future reference

## Video Tutorial Plans

This will take ages to make, expect to record the video many many times before you get a good one! (_Note: This makes it worthwhile attending to the tiny details in the previous section_)

### Basic Features Demo

* Enable Demo Mode
* Click part_07, the purple edge section
* Click the line button x1
* Press F to toggle the focus
* Change edges color via "Details > Triangles"
* Change triangle color via "Details > Triangles"
* Change triangle color via color box
* Restore triangle color via MMB
* Select all meshes
* Click the line button a few times
* Change the color of everything via the color box
* Restore the color of everything via MMB on the color box
* Hover mouse over the item list to show flashing
* Select the two broken items and invert the selection
* Zoom scoll into the broken items
* Rotate the broken items
* Change the alternative rotation axis to World_Z
* Alternative Rotate the broken items
* Start to click visibility on all of them
* Sweep drag to show them all
* Sweep drag to hide them all
* Ctrl sweep drag
* Shift sweep drag

### Annotations and Labelling Demo

* Enable Demo Mode
* Open Demo.obj in notepad
* Load Demo.obj and minimize the directory folder
* Use Details menu to enable triangle edges and increase point sizes
* Use Annotation tab and change Vertex annotations to dark red and Segment to dark yellow
* Collapse the Details section
* Set the focussed opacity to .7
* Pan Demo.obj so you can see notepad
* Circle the header annotation
*   "File > Preferences > Item List > Show Header Annotation Tooltips"
*   Show the header annotation
* Circle the segment annotations
*   Show the segment annotations
* Circle the point annotations
*   Show the point annotations
* Circle the triangle annotations and the ignore syntax
*   Show the triangle annotations
* Circle the command annotation
*   Show the command annotation output
* Close the console
* Turn on index labels
* Turn on position labels
* Open the Details section
* Focus segment 1
* Focus segment 2
* File > Preferences > Labelling > Float Format to SCIENTIFIC

### Console Commands and Clipping Demo

Uses a a file (curtously Jimmy Andrews) from a real debug sessions

* Enable Demo Mode
* Load BooleanB.obj
* Set color to a light grey
* Open the console
* Run "item_find_open_edges"
* Hover the edge item to show it in the viewport
* Rotate the camera so you can see it
* Do the clipping sphere thing
* Zoom in close to the edge
* Run "item_perturb_positions" a few times to see the gap more clearly
* "Details > Selection > Reload" to reload the geometry
* Remove the clipping sphere
* Focus the item
* Run "item_focus_triangle 0 187"
* Turn on indices and show Triangle 187

### Window Manipulation and Hot-Reloading Demo

* Run Prizm.exe --help
* Close Prizm.exe
* Run Prizm.exe --AlwaysOnTop
* Enable Demo Mode
* Open "View > Window Settings"
* Reduce focussed window opacity
* Restore focussed window opacity
* Reduce unfocussed window opacity
* Switching to vscode to demo it
* Run code shapes/Widget.obj
* Remove faces from Widget.obj
* Show the change in Prizm
* Press F5 to refresh
* Revert the change
* Press F5 to refresh
* Toggle auto reloading
* Make multiple changes to the obj and show them appearing
* Demo easy resizing and easy panning
* Demo clicking on the logo to change its color

### Prizm API and Hot-Reloading Demo

* Show a C++ marching squares program
* Run Prizm.exe --AlwaysOnTop
* Copy the Prizm API via the button
* Add debug logging to the program to write files to a Debug/ folder
* Load the empty folder in Prizm
* Step through the program and note how the contour updates
