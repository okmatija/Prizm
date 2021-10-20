Prism
=====

A computational geometry debugging tool written in [Jai](https://youtu.be/TH9VCN6UkyQ).  Press h for help, see the CHANGELOG for a feature list.

The intended workflow is:

1. Run Prism and load geometry files or reload your previous debugging state
2. View the geometry to debug your algorithm
3. Write a Jai function and tag it with the @RegisterCommand note
4. Save your state and close Prism
5. Recompile and goto 1. The function you wrote in step 3 will now be available in the console

Other tools accomplish a similar workflow using e.g., python bindings, but since Jai has very fast compile times and convenient/powerful meta-programming we can do things differently and rely on only one programming language.  Obviously since Jai is still in closed beta this doesn't really work yet :) Also the saving/reloading state feature is not yet implemented so if you made a bunch of changes to visibility/clipping/colors etc it will be a bit more inconvenient to return to your previous state.