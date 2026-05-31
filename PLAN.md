# Plan: Port Prizm rendering to the SDL3 GPU API

Status: **DRAFT / not started** — this document is the design + tracking artifact for the
port. It is meant to be edited as we go. The "Regression tracker" section near the bottom is
the living record the task brief asks for: whenever behaviour changes (even slightly) from the
current OpenGL renderer, record it there.

Author note: everything below was written after reading the current renderer end-to-end
(`source/render/*`, `source/prizm.jai`, `source/camera.jai`, `source/clipping_sphere_mode.jai`,
`source/imgui_impl_*`, `first.jai`), the `modules/SDL3` + `modules/ImGui` setup, and the wiki
feature docs. File/line references are given so the reasoning can be checked.

---

## 0. Goals and constraints

1. Replace the OpenGL renderer + the hand-ported `imgui_impl_opengl3` / `imgui_impl_sdl`
   backends with the **SDL3 GPU API** for our own geometry and the **official
   `sdl3_gpu3` ImGui backend** shipped in `modules/ImGui/backends/`.
2. **Preserve current behaviour as closely as possible.** Where a feature cannot be reproduced
   exactly (geometry-shader effects, wide lines, point size — see §5), flag it loudly here and
   to the user rather than silently changing it.
3. The two features called out as especially important:
   - **Normal-vector display** (`render_mesh_*_normals`, `normals_*.geom`) — currently
     geometry-shader based, this is the trickiest visual feature to port.
   - **Clipping sphere / clipping slabs** (`clip_sphere`, `clip_range[3]`) — these are pure
     fragment-shader `discard`, so they port cleanly; the risk is just plumbing the uniforms.
4. **Build integration must stay simple.** Shaders must be compiled to GPU bytecode as part of
   the existing `first.jai` metaprogram with no extra manual steps for a normal `jai first.jai`
   build.
5. Target **Windows, Linux, macOS now, and the browser (WASM) eventually.** SDL_GPU gives us
   Vulkan/D3D12/Metal today; the browser story is discussed in §8 and is explicitly *not* part
   of the first milestone.

---

## 1. How the SDL3 GPU API works (for an OpenGL programmer)

You know OpenGL, so this section is framed entirely as "what's different from GL". The mental
model is much closer to Vulkan/Metal/D3D12 than to GL, but SDL hides almost all of the painful
parts (no descriptor pools, no manual memory allocation, no pipeline barriers in the common
case).

### 1.1 The big conceptual shift: no global state machine

OpenGL is one giant hidden state machine: you `glBindThis`, `glEnableThat`, then `glDraw`, and
the driver renders using whatever is currently bound. SDL_GPU has **almost no persistent
global state**. Instead:

- Almost everything you "set up" is baked into immutable **objects** created up-front
  (pipelines, buffers, textures, samplers, shaders).
- Per-frame work is recorded into a **command buffer** and submitted. The command buffer is the
  only "current" thing, and you pass it (or a pass handle derived from it) explicitly to every
  call. There is no `ScopeGlState()` dance (`render_utils.jai:117`) because there is no global
  state to save/restore.

This is why the port is mostly *mechanical but pervasive*: every `glEnable`, `glBlendFunc`,
`glPolygonMode`, `glLineWidth`, `glUseProgram`, `glBindVertexArray`, `glUniform*`, `glDrawArrays`
turns into either (a) a field on a pipeline-create-info struct chosen at init time, or (b) a
call that takes a render-pass handle.

### 1.2 The core objects (GL analogues in parentheses)

| SDL_GPU object | Created by | GL analogue |
| --- | --- | --- |
| `SDL_GPUDevice` | `SDL_CreateGPUDevice` | the GL context |
| `SDL_GPUShader` | `SDL_CreateGPUShader` (from **bytecode**) | a compiled+linked shader stage |
| `SDL_GPUGraphicsPipeline` | `SDL_CreateGPUGraphicsPipeline` | program + *all* fixed-function state (blend, depth, cull, fill mode, vertex layout, primitive type, target formats) frozen together |
| `SDL_GPUBuffer` | `SDL_CreateGPUBuffer` | VBO / IBO (GPU-side) |
| `SDL_GPUTransferBuffer` | `SDL_CreateGPUTransferBuffer` | the CPU-visible staging buffer you `glBufferData` from |
| `SDL_GPUTexture` | `SDL_CreateGPUTexture` | texture *and* renderbuffer/FBO attachment |
| `SDL_GPUSampler` | `SDL_CreateGPUSampler` | the `glTexParameteri` filter/wrap state, as an object |
| `SDL_GPUCommandBuffer` | `SDL_AcquireGPUCommandBuffer` | (no analogue — it's the recording context) |
| `SDL_GPURenderPass` | `SDL_BeginGPURenderPass` | a bound FBO + its clear/load/store + viewport/scissor |
| `SDL_GPUCopyPass` | `SDL_BeginGPUCopyPass` | the upload/`glBufferSubData`/`glTexImage2D` phase |

The single most important difference from GL: **`SDL_GPUGraphicsPipeline` is monolithic.**
In GL you freely toggle blend/depth/cull/polygon-mode between draws. In SDL_GPU all of that is
frozen into the pipeline at creation. So where Prizm today varies state per draw, we will need
*one pipeline object per distinct state combination*. Concretely (see §3) that means roughly:
"triangles-fill", "triangles-line" (fill mode LINE), "points/lines", "normals", "aabb-lines",
"background", plus the deferred-pipeline variants. We create them once in `init_rendering` and
just bind the right one.

### 1.3 The per-frame loop

GL today (`prizm.jai:160-219`):

```
ImGui_ImplOpenGL3_NewFrame(); ImGui_ImplSDL2_NewFrame(); ImGui.NewFrame();
glViewport(...); glClear(...);
... build UI ...
render_background(); render_selections(); render_entities();   // forward
render_text(); render_axes_triad();
ImGui.Render(); ImGui_ImplOpenGL3_RenderDrawData(...);
SDL_GL_SwapWindow(window);
```

SDL_GPU equivalent (sketch):

```jai
cmd := SDL_AcquireGPUCommandBuffer(gpu_device);

swapchain_tex : *SDL_GPUTexture;
SDL_WaitAndAcquireGPUSwapchainTexture(cmd, window, *swapchain_tex, *w, *h);

// --- Copy pass: upload any dirty vertex/index data (replaces glBufferData/SubData) ---
copy := SDL_BeginGPUCopyPass(cmd);
// ... SDL_UploadToGPUBuffer(...) for dirty meshes ...
SDL_EndGPUCopyPass(copy);

// --- Main render pass: draw into the swapchain texture ---
color_target := SDL_GPUColorTargetInfo.{
    texture = swapchain_tex,
    load_op = .CLEAR, clear_color = .{...}, store_op = .STORE,
};
depth_target := SDL_GPUDepthStencilTargetInfo.{ texture = depth_tex, load_op = .CLEAR, clear_depth = 1, ... };
pass := SDL_BeginGPURenderPass(cmd, *color_target, 1, *depth_target);

SDL_SetGPUViewport(pass, *viewport);
SDL_BindGPUGraphicsPipeline(pass, pipeline_triangles);
SDL_BindGPUVertexBuffers(pass, 0, *binding, 1);
SDL_PushGPUVertexUniformData(cmd, 0, *vert_uniforms, size_of(Vert_Uniforms));
SDL_PushGPUFragmentUniformData(cmd, 0, *frag_uniforms, size_of(Frag_Uniforms));
SDL_DrawGPUPrimitives(pass, vertex_count, 1, 0, 0);
// ... more binds + draws ...

// ImGui draws into the SAME render pass:
ImGui.Render();
ImGui_ImplSDLGPU3_PrepareDrawData(ImGui.GetDrawData(), cmd);   // must be BEFORE BeginRenderPass in the official example — see §6
ImGui_ImplSDLGPU3_RenderDrawData(ImGui.GetDrawData(), cmd, pass);

SDL_EndGPURenderPass(pass);
SDL_SubmitGPUCommandBuffer(cmd);   // replaces SDL_GL_SwapWindow
```

Things to internalise:

- **`glClear` is not a call** — it's the `load_op = .CLEAR` on a target plus `clear_color`/
  `clear_depth`. The "clear depth between layers to draw text/hover on top"
  (`render.jai:513`, `render_text.jai:3`) trick becomes either a *separate render pass* with
  `depth load_op = .CLEAR` and `color load_op = .LOAD`, or we keep depth and re-order. This is a
  real design point, see §3.3.
- **Uniforms are pushed, not set per-name.** There is no `glGetUniformLocation` /
  `glUniform3f`. You fill a CPU struct and `SDL_PushGPUVertexUniformData(cmd, slot, *data,
  size)`. This *kills* the entire `set_shader_uniform_value` / `cache_shader_uniform_location`
  machinery (`shader.jai`) and the per-frame `tprint("clip_range[%]...", it)` hot path
  (`shader_triangles.jai:71-76`, flagged `@Speedddddd` in the code) — good riddance, this will
  be faster.
- **Vertex layout is declared on the pipeline**, not via `glVertexAttribPointer` against a bound
  VAO. VAOs disappear entirely; we describe attributes once in
  `SDL_GPUVertexInputState` (slots, offsets, formats).
- **Submitting the command buffer is the swap.** `SDL_GL_SwapWindow` →
  `SDL_SubmitGPUCommandBuffer`.

### 1.4 Buffers and uploads

GL's `glBufferData(GL_ARRAY_BUFFER, ...)` becomes a two-step dance, exactly like Vulkan staging:

1. `SDL_CreateGPUBuffer(device, {usage = .VERTEX, size})` — the GPU-resident buffer.
2. `SDL_CreateGPUTransferBuffer(device, {usage = .UPLOAD, size})`, then
   `SDL_MapGPUTransferBuffer` → `memcpy` your data → `SDL_UnmapGPUTransferBuffer`.
3. In a copy pass, `SDL_UploadToGPUBuffer(copy, src_location, dst_region, cycle)`.

Prizm already uploads lazily and only when `Render_Info.is_dirty` (`render.jai:42`), so this
slots in naturally: the existing `maybe_update_render_info` becomes "if dirty, record uploads
into this frame's copy pass". The triangle-soup layout we already build (positions || normals ||
colors in one buffer, `render.jai:100-104`) maps directly onto a single `SDL_GPUBuffer` with
three vertex attributes at computed byte offsets.

### 1.5 Textures, render targets, samplers (for the deferred path / SSAO)

- A `SDL_GPUTexture` created with usage `COLOR_TARGET` / `DEPTH_STENCIL_TARGET` is what you
  render *into*; with usage `SAMPLER` it's what you read. The G-buffer textures
  (`render_pass.jai`) become `COLOR_TARGET | SAMPLER` textures.
- MRT (the G-buffer's 3 color attachments, `render_pass.jai:95-96`) is supported: pass an array
  of `SDL_GPUColorTargetInfo` to `SDL_BeginGPURenderPass`.
- **Sampling is split:** the *texture* and the *sampler* are separate objects, bound together
  via `SDL_GPUTextureSamplerBinding` and `SDL_BindGPUFragmentSamplers`. Our `Texture` struct
  (`texture.jai`) currently fuses `gl_handle` + filter + wrap; it splits into a texture handle +
  a sampler handle. The `Pixel_Format` enum maps to `SDL_GPUTextureFormat` (e.g. `RGBA32F` →
  `R32G32B32A32_FLOAT`, `Depth` → `D32_FLOAT`).

### 1.6 Shaders: the part that changes most

**SDL_GPU does not take GLSL source.** `SDL_CreateGPUShader` takes *compiled bytecode* in one of:
`SPIRV` (Vulkan), `DXBC`/`DXIL` (D3D12), `MSL`/`METALLIB` (Metal) — see the
`SDL_GPU_SHADERFORMAT_*` constants (`modules/SDL3/linux/linux.jai:595-601`). You query what the
device accepts with `SDL_GetGPUShaderFormats`. So we must compile our shaders offline (or at
load time). This is the single biggest build-system task — see §7.

Two more shader-side rules that bite GL programmers:

- **Resource binding is by explicit slot/space, per stage, by *category*.** In GLSL-for-GL you
  just name a uniform. For SDL_GPU shaders, the bytecode must declare resources in the register
  layout SDL expects (documented on `SDL_CreateGPUShader`): for each stage, samplers, then
  storage textures, then storage buffers, then uniform buffers, each in their own space. With
  the SPIR-V path produced by SDL_shadercross the convention is, per stage:
  `set 0` = sampled textures + samplers, `set 1` = storage textures/buffers (vertex) /
  `set 2` (fragment), `set 1`/`set 3` = uniform buffers. We just have to write the shaders to
  that convention and keep uniform-buffer **slot indices** in sync between the shader and the
  `SDL_PushGPU*UniformData(cmd, slot, ...)` call. This needs care and is a likely source of
  "renders black" bugs.
- **No geometry shaders. No tessellation.** SDL_GPU exposes vertex + fragment (+ compute) only.
  This is the central re-architecture for Prizm (see §5.1). Geometry shaders are used in:
  `triangles.geom`, `normals_points.geom`, `normals_segments.geom`, `normals_triangles.geom`.

### 1.7 Clip-space / NDC conventions (correctness-critical)

OpenGL clip space is `z ∈ [-1, +1]` with a lower-left origin. SDL_GPU follows the
D3D/Vulkan/Metal convention: **`z ∈ [0, +1]`**, and (for *render-to-texture*) a top-left texture
origin, so screen-space Y is effectively flipped relative to GL for offscreen targets.

Prizm's projection (`camera.jai:450`) calls Jai's `orthographic_projection_matrix`, which
**already has a `depth_range_01` parameter** (`Math/matrix.jai:652`). So the depth fix is a
one-liner: pass `depth_range_01 = true`. But there are knock-on effects we must audit carefully
because Prizm does a lot of unproject/screen math:

- `make_camera_ray` (`camera.jai:481`) and `to_screen_position` (`render_utils.jai:2`) assume
  the GL `[-1,1]` depth + Y-up NDC mapping. These are used for picking, clipping-sphere center
  placement, label placement. If we change the projection's depth range, the *inverse* used in
  `make_camera_ray` must match, and the `z=-1` "near plane" assumption (`camera.jai:494`,
  `update_camera` pan code `camera.jai:164`) becomes `z=0`. **This is the highest-risk
  correctness area of the whole port** — it touches camera navigation, picking, clipping, and
  labels, none of which are "rendering" per se but all of which silently depend on the matrix
  convention.
- Strategy: keep the world/view math identical; introduce the `[0,1]` projection *only* for the
  GPU `clip_from_view` uniform, and keep a separate GL-convention matrix for the CPU-side
  unproject/pick math **only if** decoupling is cleaner than fixing the few `z=-1`/`z=±1`
  call-sites. Decide this early (it's an open question in §10).

### 1.8 What SDL_GPU does *not* give us (vs GL)

- **`gl_PointSize` / wide points** — there is no per-vertex point size. `POINTLIST` renders 1px
  points. (Regression — §5.2.)
- **`glLineWidth` / wide lines** — line width is fixed at 1px on most backends. (Regression —
  §5.3.)
- **`glPolygonMode(GL_LINE)`** — *this one we keep*: pipelines have
  `SDL_GPUFillMode.LINE` (`modules/SDL3/linux/linux.jai:27398`), so the
  `render_mesh_triangles_as_lines` pass survives, just at 1px.
- Geometry shaders (§1.6).

---

## 2. Current renderer inventory (what we are porting)

Forward pipeline (default; `app.settings.feature_flags.use_deferred_renderer == false`,
`prizm.jai:198-206`):

- `render_background` — full-screen animated gradient, `gl_VertexID` quad, no VBO
  (`background.vert`/`background.frag`, `shader_background.jai`).
- `render_selections` — same draw routines as entities, run on the select-tool entity.
- `render_entities` → `render_entity_geometry` (`render.jai:714`) per entity, in
  opaque/transparent/hovered passes, each calling:
  - `render_mesh_triangles` (fill, Blinn-Phong, frontface/backface modes, solid wireframe via
    edge distance, clip sphere/ranges, flash "wave") — `triangles.{vert,geom,frag}`.
  - `render_mesh_triangles_as_lines` (`GL_LINE` polygon mode, degenerate-triangle visibility) —
    uses the points/lines shader.
  - `render_mesh_triangle_normals` / `_segment_normals` / `_point_normals` — geometry-shader
    normal vectors (`normals_*.geom`).
  - `render_mesh_segments`, `render_mesh_points`, `render_mesh_positions` — points/lines shader,
    `gl_PointSize`, `glLineWidth`.
  - `render_aabb` — 24-vertex line box from `gl_VertexID` + min/max uniforms (`aabb.vert`).
- `render_text` — **ImGui windows**, not GL geometry (`render_text.jai`). Ports *for free* once
  the ImGui backend swap is done; the stray `glEnable(GL_BLEND)` etc. in there are vestigial.
- `render_axes_triad`, `render_demo_mode` — small extra draws (axes triad uses the same shaders).

Deferred pipeline (experimental, off by default; `render_entities_gbuffer`, `render.jai:518`):
G-buffer (MRT: position/normal/base_color + depth) → SSAO → SSAO blur → lighting → blit to
screen. Shaders: `gbuffer.*`, `ssao.frag`, `ssao_blur.frag`, `triangles_deferred.frag`,
`quad.vert`, `debug_deferred.frag`.

ImGui integration today: hand-written Jai ports `source/imgui_impl_sdl.jai` (SDL3 platform,
despite the `SDL2` names) + `source/imgui_impl_opengl3.jai` (GL renderer). The platform backend
is already SDL3-correct; **only the renderer backend changes.**

---

## 3. The big architectural decisions

### 3.1 Pipeline inventory (replaces per-draw GL state)

Create these `SDL_GPUGraphicsPipeline`s once in `init_rendering`:

| Pipeline | Primitive | Fill | Blend | Depth test/write | Replaces |
| --- | --- | --- | --- | --- | --- |
| `pso_background` | TRIANGLESTRIP | FILL | off | off / off | `render_background` |
| `pso_triangles` | TRIANGLELIST | FILL | src-alpha | on / on | `render_mesh_triangles` |
| `pso_triangles_lines` | TRIANGLELIST | LINE | off | on / on | `render_mesh_triangles_as_lines` |
| `pso_points` | POINTLIST | FILL | src-alpha | on / on | `render_mesh_points`/`_positions` |
| `pso_lines` | LINELIST | FILL | src-alpha | on / on | `render_mesh_segments` |
| `pso_normals` | LINELIST | FILL | src-alpha | on / on | `render_mesh_*_normals` |
| `pso_aabb` | LINELIST | FILL | off | on / on | `render_aabb` |
| (deferred) `pso_gbuffer`, `pso_ssao`, `pso_ssao_blur`, `pso_lighting`, `pso_blit` | TRIANGLELIST | FILL | off | varies | deferred passes |

Transparency: today opaque vs transparent is just draw order + the same blend func
(`render.jai:505-506`). We keep the same blend state and the same ordering, so one
`pso_triangles` suffices (alpha comes from the uniform `color.w`).

### 3.2 Uniform buffer structs (replace `glUniform*` + the reflection machinery)

Define packed structs mirroring the shader uniform blocks, respecting std140 alignment
(`Vector3` → pad to 16 bytes, matrices are 4×`vec4`). Roughly:

```jai
Transform_UBO :: struct {            // vertex stage, slot 0
    clip_from_view  : Matrix4;
    view_from_world : Matrix4;
    world_from_model: Matrix4;
}
Clip_UBO :: struct {                 // fragment stage, slot 0 (shared by most shaders)
    clip_sphere      : Clip_Sphere_Std140;
    clip_sphere_prev : Clip_Sphere_Std140;
    clip_ranges      : [3]Clip_Range_Std140;
    clip_radius_mode : s32;
    _pad             : [3]s32;
}
Triangle_Style_UBO :: struct { ... } // fragment stage, slot 1
```

This replaces `shader.jai` (`Shader`, `Shader_Uniform`, `cache_shader_uniform_location`,
`set_shader_uniform_value`) entirely and removes the per-frame `tprint` uniform-name building.

### 3.3 The "clear depth between layers" pattern

Today Prizm calls `glClear(GL_DEPTH_BUFFER_BIT)` mid-frame three times to layer:
(1) scene, (2) text/hovered above scene (`render.jai:513`), (3) text labels again
(`render_text.jai:3`), (4) axes triad. With SDL_GPU, depth clears happen at render-pass
boundaries. Plan: split the frame into a small number of render passes that all target the
swapchain with `color load_op = .LOAD` but `depth load_op = .CLEAR`:

1. Pass A: background (no depth) + opaque + transparent entities + AABBs.
2. Pass B (depth cleared, color loaded): hovered entity on top + axes triad.
3. ImGui (text labels are ImGui windows; the ImGui backend renders in its own/last pass).

This reproduces the exact layering without `glClear` calls.

---

## 4. The SDL3-version-mismatch question — **confirmed: safe to ignore**

The concern: `modules/ImGui`'s `sdl3_gpu3` backend was *built against SDL **3.2.14** headers*
(`modules/ImGui/README.md:17`), but Prizm's `modules/SDL3` bindings are **3.4.4**
(`modules/SDL3/README.md:3`). Conclusion: **this is fine, with two conditions we control.**

Why it's fine:

- The backend is a prebuilt static lib (`modules/ImGui/backends/linux/ImGui_sdl3_gpu3`,
  referenced at `unix_sdl3_gpu3.jai:84`). Its `.jai` bindings file declares the SDL types it
  touches (`SDL_Window`, `SDL_GPUDevice`, `SDL_GPUCommandBuffer`, …) as **unqualified names**
  resolved at the `#load` site (see how `tests/test.jai` does `#import "sdl3"; #load
  "../backends/sdl3_gpu3.jai";`). So at *compile time* there is a single set of SDL types —
  Prizm's 3.4.4 ones. No duplicate-type clash as long as we import exactly one SDL3 module.
- At *runtime* there is a single `libSDL3.so.0` / `SDL3.dll` (3.4.4). SDL3 guarantees **ABI
  stability across the entire 3.x line**, and the GPU API has been stable since 3.2.0. A library
  compiled against 3.2.14 headers calling into a 3.4.4 runtime is exactly the
  "compiled-old/run-new" case SDL's ABI policy promises to support. The structs crossing the
  boundary (`SDL_GPUColorTargetInfo`, `SDL_Event`, opaque pointers) have stable layouts.

The two conditions:

1. **Exactly one SDL3 module in the Prizm build.** Keep `modules/SDL3` (3.4.4) as the only one;
   do *not* also pull in `modules/ImGui/tests/modules/sdl3` (that vendored 3.2.14 copy is only
   for the ImGui module's own test). The `#load "backends/sdl3_gpu3.jai"` must happen in a scope
   where Prizm's SDL3 is imported.
2. If we ever *regenerate* the ImGui backend ourselves, build it against 3.4.4 headers to make
   the match exact. Not required now.

Action: add a short note in `modules/ImGui/README.md` or here recording that we intentionally
run the 3.2.14-built backend against 3.4.4. (Tracked in §9 as RT-0, informational.)

---

## 5. Regression risks and how we handle each

### 5.1 Geometry shaders → vertex-shader / CPU expansion (REQUIRED rework)

SDL_GPU has no geometry shaders. Three uses:

**(a) `triangles.geom`** does two jobs:
- Computes the **flat-shading face normal** (`triangle_normal_ws`, cross of the 3 world
  positions). → Replace by either (i) computing the face normal on the CPU when we build the
  triangle-soup VBO and storing it as a per-vertex attribute (cheap, exact), or (ii)
  reconstructing it in the fragment shader via `dFdx/dFdy(fragment_position_ws)` (no extra data,
  visually identical, the standard technique). **Recommend (i)** — exact, and we already rebuild
  the soup buffer.
- Computes **screen-space edge distances** for the anti-aliased solid wireframe
  (`dist = area/length(edge)`, the NVIDIA "solid wireframe" method). This needs all three screen
  positions of the triangle, which a vertex shader doesn't have. → Replace with **barycentric
  coordinates as a per-vertex attribute** ((1,0,0),(0,1,0),(0,0,1) over the soup triangle) and
  do `min(bary)/fwidth` AA in the fragment shader. **Regression:** the AA falloff is computed
  slightly differently (perspective-correct screen distance vs `fwidth` of barycentrics); for an
  orthographic camera with triangle soup the two are visually near-identical, but it is *not*
  bit-exact. Record as RT-1.

**(b) `normals_*.geom`** (the flagged feature) generate a line per point / per segment-endpoint /
per triangle-vertex: base → base + normal·scale, with an interactive `normal_style_scale` and a
`normalized` toggle. → Replace **without any geometry shader** by building a `LINELIST` vertex
buffer with **2 vertices per normal**, each carrying `(base_position, normal)` plus an
`endpoint` flag (0 for base, 1 for tip). Vertex shader:
`pos = base + endpoint * normal * scale`. `scale`/`normalized` stay uniforms, so interactivity is
preserved with no buffer rebuild. This is an *exact* port (same math as the current `.geom`),
just relocated. Vertex counts: triangle = 3 segments (6 verts), segment = 2 (4 verts), point =
1 (2 verts). **No expected regression** beyond line width (see §5.3). This buffer can be built
from the data already assembled in `maybe_update_render_info`.

### 5.2 `gl_PointSize` → no GPU point size (REGRESSION)

`render_mesh_points`/`_positions` set `gl_PointSize` from `vertex_style.size`
(`points_lines.vert:22`, `render.jai:373`). SDL_GPU `POINTLIST` ignores size (1px). Options:
- **A (recommended):** render points as **instanced/expanded screen-aligned quads** (2 triangles
  per point) sized in pixels in the vertex shader. Exact visual match, supports any size,
  supports round points if we add a circle mask in the fragment shader. More work.
- **B (stopgap):** `POINTLIST` at 1px. Fast to implement, but **loses point size entirely** —
  unacceptable for the default look (vertices become invisible-ish). Use only as a temporary
  milestone. Record as RT-2.

### 5.3 `glLineWidth` → fixed 1px lines (REGRESSION)

Used for segments (`render.jai:431`), triangle-edges-as-lines (`render.jai:463`), and normal
vectors (`render.jai:305` etc.). Modern Vulkan/Metal/D3D back-ends generally clamp line width to
1px. Options:
- **A (recommended, later):** expand lines to **quads** (2 triangles per segment) with width in
  pixels in the vertex shader — exact control, works everywhere, also fixes WASM. Applies to
  segments, edges-as-lines, and normal vectors uniformly.
- **B (stopgap):** 1px `LINELIST`. The solid-wireframe-on-faces path (`pso_triangles` with the
  edge-distance AA) is unaffected and remains the primary way triangle edges look good; the
  `GL_LINE` pass is mainly for *degenerate* triangles, so 1px there is acceptable longer-term.
  Segment width and thick normals are the real losses. Record as RT-3.

### 5.4 Clipping sphere + clipping slabs (flagged feature) — LOW risk

Pure fragment-shader `discard` against `clip_sphere` / `clip_range[3]` uniforms
(`triangles.frag:147-178`, `points_lines.frag:42-78`, `normals.frag:60-77`). `discard` is fully
supported. The `clip_radius_mode` darken-on-shrink behaviour (`triangles.frag:166-176`, driven by
`clipping_sphere_mode.jai`) is also just fragment math. **Port = move these uniforms into the
`Clip_UBO` (§3.2) and keep the shader logic byte-for-byte.** The only risk is plumbing the UBO to
every pipeline that needs it (triangles, points/lines, normals). No visual regression expected.
Record as RT-4 only to track verification.

### 5.5 Misc

- `glColorMask`, `glGetIntegerv(GL_POLYGON_MODE)` save/restore (`render.jai:380`), `ScopeGlState`
  — all deleted; pipeline objects make them unnecessary.
- `SDL_GL_SetSwapInterval` / vsync → `SDL_SetGPUSwapchainParameters(present_mode)`.
- Window creation flag changes from `SDL_WINDOW_OPENGL` to **no GL flag** + `SDL_ClaimWindowForGPUDevice` (§6).
- The whole `gl_load` / GL proc loading and `DEBUG_OPENGL`/RenderDoc annotation path
  (`render_utils.jai:422-435`) is replaced by `SDL_CreateGPUDevice(debug_mode=true)` and the
  backend's own debug layers.

---

## 6. Window / device / ImGui bring-up (replaces `prizm.jai:49-123`, 226-235)

```jai
SDL_Init(SDL_INIT_VIDEO);

// No SDL_WINDOW_OPENGL flag anymore.
app.window = SDL_CreateWindow(name, w, h, SDL_WINDOW_RESIZABLE | SDL_WINDOW_BORDERLESS);

// Pick the shader formats we ship; debug_mode on for debug builds.
gpu := SDL_CreateGPUDevice(SDL_GPU_SHADERFORMAT_SPIRV | SDL_GPU_SHADERFORMAT_DXIL | SDL_GPU_SHADERFORMAT_MSL, DEBUG, null);
SDL_ClaimWindowForGPUDevice(gpu, app.window);
SDL_SetGPUSwapchainParameters(gpu, app.window, .SDR, .VSYNC);

// ImGui: platform backend swap. We can either keep our hand-ported source/imgui_impl_sdl.jai
// (it's already SDL3) OR use the official ImplSDL3_* from the backend lib. Using the official one
// is less code to maintain and is what the GPU renderer backend expects:
ImGui_Impl_CreateContext(...);
ImplSDL3_InitForSDLGPU(app.window);                 // from backends/sdl3_gpu3.jai
init_info := ImplSDLGPU3_InitInfo.{ Device = gpu,
    ColorTargetFormat = SDL_GetGPUSwapchainTextureFormat(gpu, app.window), ... };
ImplSDLGPU3_Init(*init_info);
```

Per frame, ImGui order matters (from the official `example_sdl3_sdlgpu3`):
`ImplSDLGPU3_NewFrame()` → build UI → `ImGui.Render()` →
`ImplSDLGPU3_PrepareDrawData(draw_data, cmd)` **before** beginning the render pass that ImGui
draws in → inside the pass, `ImplSDLGPU3_RenderDrawData(draw_data, cmd, pass)`. Event handling
(`ImplSDL3_ProcessEvent`) replaces our `ImGui_ImplSDL2_ProcessEvent` call (`prizm.jai:304`).

Decision (§10): keep our `source/imgui_impl_sdl.jai` platform port, or switch to the backend's
`ImplSDL3_*`? Recommend **switching to the official `ImplSDL3_*`** so platform + renderer are a
matched pair from one source, and we can delete both `source/imgui_impl_*` files. (Our keymap
still reads SDL events directly in `handle_events`, which is independent and stays.)

---

## 7. Shader build integration (the "keep it simple" requirement)

We author shaders **once** and compile to the formats the target backends need. Recommended
toolchain:

- **Author in Vulkan-style GLSL (`#version 450`)** — closest to what we already have, so the
  team's GLSL knowledge transfers. Our existing `.vert`/`.frag` need only modest edits
  (uniform blocks instead of loose uniforms; remove `.geom`; bindings per §1.6).
- **Compile GLSL → SPIR-V** with `glslang`/`glslc` at build time.
- **SPIR-V → MSL (Metal) and DXIL (D3D12)** with **SDL_shadercross** (the SDL-blessed
  cross-compiler that wraps DXC + SPIRV-Cross). Either:
  - **Offline (recommended for shipping):** produce `.spv` + `.dxil` + `.msl`/`.metallib` at
    build time, embed all three with `#run read_entire_file`, pick at runtime by
    `SDL_GetGPUShaderFormats`. Deterministic, no runtime tool dependency.
  - **Runtime:** ship only `.spv` and call SDL_shadercross at load to translate. One artifact,
    but adds a runtime lib and per-launch cost.

`first.jai` integration: the metaprogram already runs arbitrary code and shells out
(`run_command` is used for the shipping zip, `first.jai:218`). Add a `compile_shaders()` step at
the top of `build()` (after `set_working_directory`) that, for each shader, invokes the
compiler(s) and writes outputs into `.build/shaders/`. The render code then does
`#run read_entire_file(".build/shaders/triangles.vert.spv")` instead of the current
`#run read_entire_file("source/render/triangles.vert")` (`shader_triangles.jai:106`). Because it
all runs inside the existing metaprogram, a plain `jai first.jai` still "just builds". Guard the
external-tool calls with a clear `compiler_report` error if `glslc`/`shadercross` aren't on PATH,
listing the one-time install step — never fail silently.

Open question (§10): vendor prebuilt `.spv`/`.dxil`/`.msl` in the repo so contributors without
the shader toolchain can still build, regenerating only when shaders change? (Mirrors how
SDL3/ImGui binaries are already vendored + LFS'd.)

---

## 8. Cross-platform and WASM

- **Linux** → Vulkan (SPIR-V). **Windows** → D3D12 (DXIL) or Vulkan. **macOS** → Metal
  (MSL/metallib). SDL_GPU selects the backend; we just ship the matching bytecode and let
  `SDL_GetGPUShaderFormats` pick. The `first.jai` SDL3 lib-copy step (`first.jai:54-70`) already
  handles the three desktop runtimes.
- **Browser / WASM:** ⚠️ **Not in the first milestone.** As of SDL 3.4.x there is no *stable*
  released SDL_GPU WebGPU backend (work is ongoing upstream). So "Prizm in the browser" depends
  on either (a) SDL_GPU's future WebGPU backend landing, at which point we'd add a WGSL output to
  the shader build (SDL_shadercross can target WGSL), or (b) a separate WebGL2 fallback path
  (large extra effort, and WebGL2 has no geometry shaders either — but our post-port shaders
  won't use them, which is a nice alignment). Designing the renderer now *as if* geometry
  shaders and wide lines don't exist (which the port forces anyway) is exactly what keeps the
  browser door open. Track WASM as a separate future milestone; do not let it block the desktop
  port.

---

## 9. Phased execution plan

Each phase should compile and run (use `/mnt/c/Dev/jai/bin/jai-linux first.jai -` to typecheck;
the first compile of new code usually needs explicit numeric casts — expected).

- **Phase 0 — Spike (no Prizm changes).** ✅ `spike/spike.jai` + `spike/build.jai`: window with
  ImGui demo rendered through `sdl3_gpu3`, built against SDL 3.4.4. Confirmed RT-0 safe.
- **Phase 1 — Device + ImGui only.** ✅ Replaced GL context with `SDL_CreateGPUDevice` +
  `SDL_ClaimWindowForGPUDevice`; swapped ImGui to `ImplSDL3_*` + `ImplSDLGPU3_*`; deleted both
  `imgui_impl_opengl3.jai` and `imgui_impl_sdl.jai`. Skipped `init_rendering()` + `init_icons()`
  (GL-dependent; Phase 2+). Icon image calls guarded with `if gl_handle` for Phase 1. UI runs,
  viewport is blank (dark background from SDL_GPU clear).
- **Phase 2 — Shader build pipeline (§7).** ✅ `compile_shaders()` in `first.jai` runs
  `glslangValidator -V` for each GLSL source → `.build/shaders/<name>.spv` before
  `add_build_file`; bytecode embedded via `#run read_entire_file`. `source/render/sdlgpu_hello.jai`
  creates a pipeline from the SPIR-V and draws a hardcoded RGB triangle before ImGui each frame.
  Requires `glslang-tools` (`sudo apt install glslang-tools`).
- **Phase 3 — Buffers + points/lines + triangles pipelines.** ✅ `source/render/sdlgpu_render.jai`:
  SDL GPU buffer upload (transfer→GPU via copy passes, separated from render pass); four pipelines
  (triangles fill/line, linelist, pointlist); GLSL 450 shaders with Transform/Clip/Style UBOs.
  Face normals CPU-computed; barycentric wireframe via fwidth. `maybe_update_render_info` gutted
  to bounding-sphere only (GL VBO code dead). All sample OBJ shapes run. RT-4 (clipping) plumbed;
  RT-5 (depth range / Y flip) not yet fixed — geometry position TBD until tested on a display.
- **Phase 4 — Normals (flagged feature, §5.1b), AABB, background, axes triad, demo mode.**
  **Exit:** forward renderer at parity except the known line/point-width regressions.
- **Phase 5 — Width fidelity.** Implement quad-expanded thick lines + sized point quads
  (§5.2A/§5.3A) to close RT-2/RT-3. **Exit:** visual parity with the GL renderer.
- ~~**Phase 6 — Deferred path.**~~ **Dropped.** The deferred renderer is experimental and off by
  default; it will be deleted rather than ported.
- **Phase 7 — macOS + Windows bring-up**, then **WASM** as a separate milestone (§8).

---

## 10. Regression tracker (LIVING — update as we port)

| ID | Area | Status | Description / decision |
| --- | --- | --- | --- |
| RT-0 | SDL version | **Verified** | ImGui `sdl3_gpu3` backend built vs SDL 3.2.14, run against 3.4.4. Confirmed safe in `spike/spike.jai` (Phase 0). |
| RT-1 | Solid wireframe AA | Open | `triangles.geom` screen-space edge-distance AA → barycentric + `fwidth`. Visually near-identical for ortho camera; not bit-exact. Verify against `shapes/*`. |
| RT-2 | Point/vertex size | Open | `gl_PointSize` unsupported. Phase 3 ships 1px stopgap; Phase 5 restores via sized quads. |
| RT-3 | Line width | Open | `glLineWidth` unsupported (segments, edges-as-lines, normals). Phase 3/4 ship 1px; Phase 5 restores via quad expansion. Solid wireframe-on-faces unaffected. |
| RT-4 | Clipping sphere/slabs | Open (low risk) | Pure `discard`, ported as-is via `Clip_UBO`. Track only to confirm visual parity incl. `clip_radius_mode` darken. |
| RT-5 | Clip-space/unproject | Open (high risk) | `[-1,1]`→`[0,1]` depth globally: pass `depth_range_01=true` to `orthographic_projection_matrix`; fix all `z=-1` near-plane assumptions in `make_camera_ray`, `to_screen_position`, pan/orbit code (`camera.jai`). Picking/labels/clipping depend on this. |
| RT-6 | Deferred renderer | **Dropped** | Deleted, not ported. Experimental and off by default. |

---

## 11. Decisions (resolved 2026-05-31)

1. **Shader bytecode in the repo:** **Vendor prebuilt** `.spv`/`.dxil`/`.msl` via LFS (mirrors
   how SDL3/ImGui binaries are already handled). Contributors without `glslc`/SDL_shadercross can
   still build; bytecode is regenerated when shaders change.
2. **ImGui platform backend:** **Delete both `source/imgui_impl_sdl.jai` and
   `source/imgui_impl_opengl3.jai`**. Use the official `ImplSDL3_*` + `ImplSDLGPU3_*` pair from
   `modules/ImGui/backends/`. Platform event reading in `handle_events` is unaffected.
3. **Deferred renderer:** **Dropped** — deleted, not ported (RT-6).
4. **Shader authoring language:** **GLSL 450** → SPIR-V (+ MSL/DXIL via SDL_shadercross).
5. **Clip-space strategy:** **Global fix** — pass `depth_range_01=true` to
   `orthographic_projection_matrix` and fix all `z=-1` unproject call-sites (RT-5).
