# Prizm

Prizm is a tool for debugging computational geometry algorithms using a simple workflow:

1. Write debug files using the [OBJ format](https://paulbourke.net/dataformats/obj/)
2. Inspect the files to find bugs

See the [wiki](https://github.com/okmatija/Prizm/wiki) for video tutorials. There is also a [Discord](https://discord.gg/zxKqvwmXNs) server.

<p align="center">
  <img src="docs/Prizm_0.8.0.png" width="640" title="Prizm 0.8.0 Screenshot" alt="Prizm 0.8.0 Screenshot">
</p>

There are many tools which can be used to implement this two-step debugging workflow (e.g., [MeshLab](https://www.meshlab.net/), [Polyscope](https://polyscope.run/), [ParaView](https://www.paraview.org/), [Meshmixer](https://meshmixer.com/), [Graphite](https://github.com/BrunoLevy/GraphiteThree), [VisIt](https://github.com/visit-dav/visit)). Prizm differs from these tools in the following ways:

* **Narrower scope**.  The tools listed above have modelling features, geometry processing features, or are platforms for _developing_ geometry processing algorithms. Prizm on the other hand is exclusively focused on the workflow outlined above, which means that it ships with only a small number of geometry processing features, the ones that have directly helped with debugging.  Furthermore, Prizm is not intended to be in development forever, once the issues for the `Version 1.0.0` milestone are addressed the program will stabilize and recieve only bug fix changes, to be maximally effective while debugging becoming familiar with your tools and being able to rely on them not changing much is helpful.

* **Simpler/faster UI/UX**.  This is of course a very subjective, but nevertheless the narrow scope of Prizm means that all the effort/iteration around improving UI/UX is necessarily focussed on the singular debugging use case.  This focus has (hopefully) resulted in a tool which enables users to identify and fix problems very quickly.  Prizm and its predecessors have been used for many years to debug problems arising in different domains and its feature set has evolved through direct experience. It should be useful when inspecting a single file or in cases where you need to sift through/transform a large set of files to identify a problem.

* **Simpler to extend**. It is common for other tools to be written in C++ with runtime scripting provided by Python.  This system is typically implemented via complicated binding code which makes the program harder to understand/change.  Prizm provides similar scripting functionality, without the complicated binding code, by having its [build program](first.jai) scan for functions marked with a special `@RegisterCommand` [note](https://github.com/Jai-Community/Jai-Community-Library/wiki/Metaprogramming#notes) and then generating the required boiler plate (with comprehensive error checking) to make the function callable from the [runtime console](https://github.com/okmatija/Prizm/wiki#console-commands).  This feature, when combined with fast compile times and hot reloading (see [#10](https://github.com/okmatija/Prizm/issues/10)), will provide a powerful and convenient scripting UX.

* **Stand-alone**.  Some tools can be directly embedded in your C++ program and programmers familiar with graphics APIs can of course write their own visualization code for debugging directly in the original program.  These features can be very helpful because you can inspect data as you step through your program.  Prizm is intentionally not a library and cannot be directly embedded in other programs, it is intended to be useful in any situtation where you might be developing geometry code, regardless of framework or language etc.  We have attempted to mitigate the downsides of having a stand-alone tool by implementing features which aim to support the same convenience (see the [obj authoring APIs](https://github.com/okmatija/Prizm/wiki#obj-file-authoring-apis), and [#4](https://github.com/okmatija/Prizm/issues/4))

_Disclaimer: Prizm is currently useful only as an executable because it is implemented using [Jai](https://youtube.com/playlist?list=PLmV5I2fxaiCKfxMBrNsU1kgKJXD3PkyxO&si=WBp0cEltcc6PuWS5), a new systems programming language which is in closed beta.  When the compiler is publically released people familiar with C++ will find Jai very easy to pick up and fun to use._
