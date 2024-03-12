# Prizm

Prizm is a tool for debugging computational geometry algorithms using a simple workflow:

1. Write debug files using the [obj format](https://paulbourke.net/dataformats/obj/)
2. Inspect the files to find bugs

There are many tools which can be used to implement this workflow (e.g., [MeshLab](https://www.meshlab.net/), [Polyscope](https://polyscope.run/), [ParaView](https://www.paraview.org/), [Meshmixer](https://meshmixer.com/), [Graphite](https://github.com/BrunoLevy/GraphiteThree), [VisIt](https://github.com/visit-dav/visit)). Prizm differs from these tools in the following ways:

* **Narrower scope**. The tools listed above have modelling features or geometry processing features or are platforms for _developing_ geometry processing algorithms. Prizm, on the other hand, is hyper focused on the two-step debugging workflow outlined above, which means that it ships with only a small number of geometry processing features, ones that have directly helped with debugging.

* **Simpler to extend**. It is common for other to be written in C++ and allow scripting using Python, the binding code to implement this interoperation complicates the program making it harder to understand/change/extend.  Prizm is implemented using [Jai](https://youtube.com/playlist?list=PLmV5I2fxaiCKfxMBrNsU1kgKJXD3PkyxO&si=WBp0cEltcc6PuWS5), a new systems programming language with powerful metaprogramming features and super fast compile times. Using Jai enables scripting to implemented via regular functions tagged with a `@RegisterCommand` [note](https://github.com/Jai-Community/Jai-Community-Library/wiki/Metaprogramming#notes) which the [build program](source/first.jai) can inspect to generate the boiler plate code so that the function can be called in the console*

* **Simpler/faster UI/UX**.  This is of course a very subjective point, but nevertheless, the narrow scope of Prizm means that all the effort/iteration around improving UI/UX is necessarily focussed on the singular debugging use case and this has (hopefully) resulted in a tool which enables users to identify and fix problems very quickly.  Prizm and its predecessors have been used for many years to debug problems arising in different domains and its feature set has evolved through direct experience. It should be useful when inspecting a single file or a large set of files which need to be sorted/transformed in batches.

* **Stand-alone**.  Some tools can directly embedded in your C++ program, and programmers familiar with graphics APIs can of course write their own visualization code for debugging directly in the original program.  This is helpful because you can inspect data as you step through your program.  Prizm is not a library and cannot be directly embedded in another program but it has other features which aim to support the same convenience as far as possible (in particular see the hot-reloading, window manipulation, obj authoring API and color selection features mentioned in the [manual](docs/MANUAL.md)).  Relatedly, Prizm is not intended to be in development forever, once the features outlined in the [roadmap](docs/ROADMAP.md) are complete the program will not change much, the idea being that in order to be maximally effective while debugging your tools should fade into the background and not change underneath you.

\* _Jai is currently is closed beta so, for now, Prizm will hopefully be useful in binary form, but when the compiler is publically released C++ users will find it very easy to pick up._
