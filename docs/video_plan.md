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
* Select all meshes
* Click the line button x3
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

### Annotations and Auto-Reload Demo

* Enable Demo Mode
* Load Cube.obj and set the edges
* Set Normal rendering with RMB on the item color
* Open Cube.obj in notepad and highlight the annotations
* Toggle annotations as well as coordinates
* "File > Preferences > Item List > Show Header Annotation Tooltips"
* Show the annotation table then back to Display tab
* Delete some faces
* Show the star by the item name
* Press F5 to reload the file
* Change the auto reload state
* Delete/Restore faces some more times
* "File > Preferences > Item List > Show Header Annotation Tooltips"

### Console Commands and Clipping Demo

* Enable Demo Mode
* Load failed_boolean_b.obj
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

### Prizm Window Tips Demo

* Enable Demo Mode
* Load cube.obj
* Open "View > Window Settings"
* Reduce focussed window opacity
* Restore focussed window opacity
* Reduce unfocussed window opacity
* Switching to the explorer to demo it
* Restore unfocussed window opacity
* Hover over the Window Size tooltip
* Hover over the Window Postion tooltip
* Demo easy resizing and easy panning
