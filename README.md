# Prizm

Prizm is a tool for debugging computational geometry algorithms using a simple workflow:

1. Write debug files using the [obj format](https://paulbourke.net/dataformats/obj/)
2. Inspect the files to find bugs

<p align="center">
  <img src="docs/Prizm_0.8.0.png" width="640" title="Prizm 0.8.0 Screenshot" alt="Prizm 0.8.0 Screenshot">
</p>

There are many tools which can be used to implement this workflow (e.g., [MeshLab](https://www.meshlab.net/), [Polyscope](https://polyscope.run/), [ParaView](https://www.paraview.org/), [Meshmixer](https://meshmixer.com/), [Graphite](https://github.com/BrunoLevy/GraphiteThree), [VisIt](https://github.com/visit-dav/visit)). Prizm differs from these tools in the following ways:

* **Narrower scope**.  The tools listed above have modelling features, geometry processing features, or are platforms for _developing_ geometry processing algorithms. Prizm on the other hand is hyper focused on the two-step debugging workflow outlined above, which means that it ships with only a small number of geometry processing features, the ones that have directly helped with debugging.  Furthermore, Prizm is not intended to be in development forever, once the features outlined in the [roadmap](https://github.com/okmatija/Prizm/wiki#Roadmap) are complete the program will stabilize and recieve only bug fix changes, to be maximally effective while debugging becoming familiar with your tools and being able to rely on them not changing much is helpful.

* **Simpler/faster UI/UX**.  This is of course a very subjective, but nevertheless the narrow scope of Prizm means that all the effort/iteration around improving UI/UX is necessarily focussed on the singular debugging use case.  This focus has (hopefully) resulted in a tool which enables users to identify and fix problems very quickly.  Prizm and its predecessors have been used for many years to debug problems arising in different domains and its feature set has evolved through direct experience. It should be useful when inspecting a single file or in cases where you need to sift through/transform a large set of files to identify a problem.

* **Simpler to extend**. It is common for other tools to be written in C++ and scriptable at runtime using Python.  The binding code to implement this interoperation complicates the program making it harder to understand/change/extend.  Prizm is implemented using [Jai](https://youtube.com/playlist?list=PLmV5I2fxaiCKfxMBrNsU1kgKJXD3PkyxO&si=WBp0cEltcc6PuWS5), a new systems programming language with powerful metaprogramming features and very fast compile times, together these features enable 'scripting' to be conveniently implemented via regular functions tagged with a `@RegisterCommand` [note](https://github.com/Jai-Community/Jai-Community-Library/wiki/Metaprogramming#notes) which the [build program](first.jai) can inspect to generate the boiler plate code so that the function can be called in the console*.

* **Stand-alone**.  Some tools can directly embedded in your C++ program, and programmers familiar with graphics APIs can of course write their own visualization code for debugging directly in the original program.  This is helpful because you can inspect data as you step through your program.  Prizm is not a library and cannot be directly embedded in another program but it has other features which aim to support the same convenience (see  the [manual](https://github.com/okmatija/Prizm/wiki/Manual) for more details).

The [wiki](https://github.com/okmatija/Prizm/wiki) has further details, including a usage [manual](https://github.com/okmatija/Prizm/wiki/#Manual).

\* _Jai is currently is closed beta so, for now, Prizm will hopefully be useful in binary form, but when the compiler is publically released C++ users will find it very easy to pick up.  Also, implementing hot code reloading is a high priority feature on the [roadmap](https://github.com/okmatija/Prizm/wiki/Roadmap), this feature is needed to better match the runtime scripting feature in other tools._
