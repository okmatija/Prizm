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
- **Phase 4 — Normals, AABB, background, axes triad, demo mode.** ✅ Six new GLSL 450 shaders
  (background full-screen triangle with Shadertoy gradient + iTime UBO; AABB 24-vertex LINELIST
  from gl_VertexIndex + AABB_UBO; normals LINELIST with endpoint derived from gl_VertexIndex%2).
  Normal buffers (base_pos, normal) built in `maybe_update_render_info_gpu` for tri/seg/pt.
  Two-pass frame: Pass A = background + geometry; Pass B = axes triad + ImGui. render_text GL
  clear removed. All sample shapes pass.
- **Phase 5 — Width fidelity.** ✅ Instance-based quad expansion for thick lines and sized
  points. Static 6-vertex unit-quad buffers created once at init. Segments bind the existing
  position+color buffer via INSTANCE input rate (pitch=24 strides over A/B pairs). Points and
  vertex positions similarly instanced (pitch=12). Width/size stay in a per-draw UBO so no
  buffer rebuild on UI slider changes. Removed Phase 0–2 hello-triangle scaffolding.
- ~~**Phase 6 — Deferred path.**~~ **Dropped.** The deferred renderer is experimental and off by
  default; it will be deleted rather than ported.
- **Phase 7 — macOS + Windows bring-up.** Shader bytecode vendored in `shaders/` (SPIR-V
  only; ~50 KB). first.jai detects glslangValidator at build time: if present, recompiles and
  updates `shaders/`; if absent, uses the vendored files. Windows via Vulkan (SPIRV) should work
  as-is; D3D12 (DXIL) and macOS Metal (METALLIB/MSL) require SDL_shadercross for runtime
  cross-compilation — not yet integrated. Needs a native Windows/macOS test build to confirm.

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

## 12. Tracy profiling investigation (notes, 2026-06-01)

Status: **research only** — no code written yet. Goal: add Tracy support so we can profile both
CPU and GPU work. The existing `tracy` build mode (`first.jai:127`) already wires up the
auto-instrumentation plugin; this section covers what module to use and what GPU-side work
requires.

### 12.1 Candidate modules

Two community jai-tracy bindings exist. Both were cloned to `/tmp` and reviewed in full.

#### roeyb1/jai-tracy (https://github.com/roeyb1/jai-tracy)

- **Tracy version:** 0.12.2 (latest as of 2026-06-01).
- **Tracy source:** full subtree inside the repo (no git submodule). Pre-built `linux/libtracy.a`
  + `linux/libtracy.so` and `windows/libtracy.dll` + `windows/libtracy.lib` are committed, so
  contributors need zero extra steps to link — just add to modules path.
- **Rebuild:** run `jai generate.jai` to recompile from the vendored Tracy source if needed.
  Compiles with `-DTRACY_ON_DEMAND` (only captures when a profiler is connected, no overhead
  otherwise) and `-DTRACY_EXPORTS`.
- **API surface:**
  - `ZoneScoped()` — automatic zone begin/end via `defer`; name defaults to procedure name from
    `#procedure_name(#this)`, computed at compile time. Optionally pass `$name`, `text`, `color`,
    `value`.
  - `FrameMark()` — unnamed frame boundary.
  - `FrameMarkStart(name)` / `FrameMarkEnd(name)` — named frame boundaries for multi-frame
    spans (e.g. async tasks, render passes). **Only roeyb1 exposes these.**
  - Full set of memory, plot, message, and lockable-context bindings from `TracyC.h`.
- **GPU bindings:** raw C-level `___tracy_emit_gpu_*` functions present in `bindings.jai`
  (zone begin/end/alloc, time, new context, context name, calibration, time-sync, plus _serial
  variants for non-concurrent contexts). No Jai-level GPU helpers are provided above the C FFI.
- **Auto-instrumentation plugin:** `get_plugin()` in `instrument.jai` injects `ZoneScoped()`
  into every procedure body at compile time (configurable: `-min_size N` to skip small procs,
  `-modules` to also instrument stdlib, `should_instrument` callback hook in `My_Plugin`).
  The `@NoProfile` note on a procedure skips it.
- **Linux linkage:** `libpthread`, `libdl`, `libc++`. Requires `libc++` (`sudo apt install libc++-dev`
  if not already present from SDL/ImGui build).
- **Windows linkage:** `msvcprt` (release CRT, correct).
- **No README** — read `runtime.jai` and `instrument.jai` directly.

#### rluba/jai-tracy (https://github.com/rluba/jai-tracy)

- **Tracy version:** 0.11.1 (README says 0.11.1; submodule pinned to commit
  `5d542dc09f3d9378d005092a4ad446bd405f819a` of wolfpld/tracy, which is the 0.11.1 tag).
- **Tracy source:** git submodule (not included). Run `git submodule update --init` then
  `jai generate.jai` before first use. **No prebuilt binaries committed** — contributors must
  build from source.
- **API surface:** Same `ZoneScoped` + `FrameMark()`. Missing `FrameMarkStart`/`FrameMarkEnd`.
  Otherwise the same raw GPU bindings in `bindings.jai`.
- **Windows linkage:** `msvcprtd` (debug CRT only) — a potential link error in release builds.
- **README:** good setup docs including a section on compile-time metaprogram profiling
  (profiling `#run` code / the metaprogram itself by self-compiling with the plugin).
- **Last updated:** older; no updates since rluba changed lib naming for Unix linking.

### 12.2 Recommendation: use roeyb1

Prefer **roeyb1/jai-tracy** for Prizm:

1. Newer Tracy (0.12.2 vs 0.11.1) — viewer and library must match; being up to date avoids
   version skew with downloaded Tracy GUI builds.
2. Pre-built binaries committed — zero build-from-source requirement (matches how SDL3 and ImGui
   are vendored in `modules/`).
3. `FrameMarkStart`/`FrameMarkEnd` are useful for naming async spans (e.g. a frame that spans
   multiple GPU submissions).
4. Correct Windows CRT linkage (`msvcprt` not `msvcprtd`).

**Integration path:** add as a git subtree at `modules/tracy` (same pattern as `modules/SDL3`
and `modules/ImGui`). The existing `first.jai` wiring (`array_add(*plugins_to_create, .{name="tracy"})`)
already expects a module named `tracy` on the import path — adding `modules/` to the path
(already done at `first.jai:150`) means it "just works" once the subtree is added.

### 12.3 CPU-side profiling — straightforward

The auto-instrumentation plugin already injects `ZoneScoped()` into every procedure, so the
main loop, render calls, file loading, OBJ parsing, etc. all get zones with no manual
annotation. Add `FrameMark()` in the main loop (one already exists at `prizm.jai:144`) and
build with `jai first.jai - tracy` — done.

The `should_instrument` hook lets us skip hot inner loops (e.g. tight OBJ parsing inner loops)
that are too small to profile meaningfully; hook this in `first.jai` when needed rather than
setting a blanket `-min_size` threshold.

### 12.4 GPU-side profiling — requires manual work

Neither module provides Jai helpers above the raw C FFI for GPU zones. We need to write a small
`source/render/tracy_gpu.jai` with the following:

#### Current renderer: OpenGL

OpenGL GPU profiling uses `glQueryCounter(GL_TIMESTAMP)` pairs around each draw, and the CPU
reports the retrieved timestamps to Tracy asynchronously. The flow:

1. **Init** — create a GL timer query pool (ring buffer of N query objects).
   Call `___tracy_emit_gpu_new_context` with:
   - `gpuTime` = result of `glGetInteger64v(GL_TIMESTAMP)` (current GPU clock)
   - `period` = 1.0 (GL timestamps are already in nanoseconds)
   - `type` = 2 (OpenGL — value from `TracyC.h` enum `GpuContextType`)
   - `flags` = 0, `_context` = returned context id.
2. **Per zone (begin)** — pick a query id from the ring, call
   `glQueryCounter(query_id, GL_TIMESTAMP)`, then call `___tracy_emit_gpu_zone_begin_alloc`
   with `srcloc`, `queryId`, and the context id.
3. **Per zone (end)** — call `glQueryCounter(end_query_id, GL_TIMESTAMP)`, then call
   `___tracy_emit_gpu_zone_end` with `queryId` + context id.
4. **Per frame** — iterate available (non-pending) queries; for each result call
   `___tracy_emit_gpu_time` with the retrieved `int64` timestamp, `queryId`, and context id.
   Also call `___tracy_emit_gpu_calibration` periodically to correct CPU/GPU clock drift.

This is entirely doable with the bindings already present in roeyb1. Wrap it in convenience
macros (`GpuZone :: ($name := "") #expand`) matching `ZoneScoped` style.

#### Future renderer: SDL3 GPU (Vulkan on Linux)

SDL3 GPU API exposes an opaque `*SDL_GPUDevice`. It does **not** expose the underlying
`VkDevice`/`VkQueue`/`VkCommandBuffer` handles that Tracy's Vulkan GPU profiling (`TracyVulkan.hpp`)
requires. This is the key obstacle.

Options:

**A. SDL GPU calibrated timestamps (approximate, no driver-level GPU insight)**
Use `___tracy_emit_gpu_new_context` with `type` = 0 (Unknown/CPU-mode), and report
CPU-measured timestamps around `SDL_SubmitGPUCommandBuffer` as a proxy. This gives
command-buffer-level granularity but no sub-pass breakdown. Very easy to implement.

**B. Vulkan interop via SDL_Vulkan / SDL_GetGPUDeviceDriver (investigation needed)**
SDL3's GPU layer is a thin Vulkan wrapper on Linux. SDL3 does expose
`SDL_GetGPUDeviceDriver(device)` (returns `"vulkan"`) and some Vulkan interop at the window
level via `SDL_Vulkan_GetInstanceExtensions`. However there is **no public API to get the
underlying `VkDevice`** from an `SDL_GPUDevice`. This would require either:
  - Reading SDL3 internal structs (fragile, non-ABI-stable hack), or
  - Filing an SDL feature request for `SDL_GetGPUVulkanDevice()`.

**C. Dual-path: GL profiling now, defer SDL GPU profiling**
Implement OpenGL Tracy GPU zones before the SDL GPU port is complete. Once the port ships,
revisit using option A (approximate) or B. Given the SDL GPU port is still at Phase 7
(Windows/macOS bring-up), this is the pragmatic sequence.

**Recommended approach:** implement option C. GL GPU profiling (option C first part) provides
immediate value for the current renderer. Write the GL helper in `source/render/tracy_gpu.jai`
so that all draw calls in `source/render/render.jai` can add a `GpuZone()` around them with
minimal churn. Scope option A after the SDL GPU port stabilises.

### 12.5 What to instrument first (priority list)

Once the module is in place, high-value annotation sites (CPU side gets auto-instrumented; GPU
side requires manual `GpuZone` calls):

1. **CPU:** OBJ loading + `maybe_update_render_info` — already covered by auto-instrumentation.
2. **CPU:** `handle_events` + UI build pass — covered automatically.
3. **GPU:** `render_entities` outer loop — one `GpuZone` per entity to spot per-entity GPU cost.
4. **GPU:** Each pipeline draw call in `render.jai` — find the N most expensive pipelines.
5. **GPU:** Buffer upload copy passes — understand upload bandwidth cost.
6. **CPU plot:** `FrameMark` + `___tracy_emit_plot_int("entity_count", ...)` — correlate GPU
   cost with scene complexity.

### 12.6 Open questions

- Does `libc++` conflict with anything in the existing SDL3/ImGui link? The SDL3 `.so` is
  pre-linked; ImGui is a static `.a`. Check with a test link before committing the subtree.
- Tracy viewer binary: the user runs the Tracy GUI app separately (Windows or Linux). Confirm
  the Tracy 0.12.2 GUI is available as a pre-built download from
  `https://github.com/wolfpld/tracy/releases`.
- Should `tracy` be a git subtree (like SDL3/ImGui) or a git submodule? Subtree preferred:
  no extra `git submodule update` step for contributors; matches existing conventions.

---

## 13. Tracy integration (2026-06-02)

Status: **DONE (CPU profiling)** — `modules/tracy` replaced with roeyb1/jai-tracy (Tracy 0.12.2);
auto-instrumentation wired in `first.jai`; manual zones added in key paths; GPU profiling deferred.

### 13.1 What was done

- **Replaced `modules/tracy`** with roeyb1/jai-tracy (subtree pattern, matching SDL3/ImGui).
  Removed the old vrcamillo v0.9.1 module (no Linux binaries, Windows-only, outdated API).
  New module: Tracy 0.12.2, pre-built `linux/libtracy.a` + `linux/libtracy.so` and
  `windows/libtracy.dll` + `windows/libtracy.lib`, full Tracy C++ source in `tracy/` for rebuilds.

- **Auto-instrumentation**: `first.jai` already wired the plugin (`array_add(*plugins_to_create,
  .{name="tracy"})` when `tracy` arg is passed). The plugin injects `ZoneScoped()` at the top of
  every procedure with ≥ 100 sub-expressions, using `#procedure_name(#this)` as the zone name. No
  manual annotation needed for basic CPU coverage.

- **`FrameMark()`** already present in `prizm.jai:144` under `#if USE_TRACY`, marking frame
  boundaries so Tracy separates per-frame data correctly.

- **Manual zones added** (all gated with `#if USE_TRACY`):
  - `prizm.jai` GPU submit block: zone `"gpu_submit"` (red, 0xC04020) — wraps buffer upload +
    both render passes + command buffer submit; makes the entire GPU phase visible at a glance.
  - `sdlgpu_render.jai` `maybe_update_render_info_gpu`: sub-zones `"mesh_triangles"` (blue),
    `"mesh_segments"` (green), `"mesh_points"` (orange) — breaks down per-geometry CPU build cost.
  - `io_obj.jai` `load_obj`: zone `"load_obj"` (teal, 0x40A0C0) — highlights OBJ parse time.

- **`first.jai` help string** updated to document `tracy` as a build option.

### 13.2 Linux library setup

The pre-built `linux/libtracy.so` in the repo was rebuilt from source using g++ on Ubuntu 22.04
(glibc 2.35). The dynamic `.so` is used rather than the static `.a` to avoid the need for an
explicit `libstdc++` link (which lld-linux can't find via its default search paths on Ubuntu).
`libstdc++.so.6` is pulled in transitively through the `.so`'s SONAME dependency list.

**If the bundled `.so` doesn't work** (wrong glibc or ABI), rebuild it from source (§13.4) and
check in the new file. `first.jai` copies `libtracy.so` next to the `Prizm` executable on each
build so the dynamic linker finds it at runtime.

On Windows no extra steps are needed; `windows/libtracy.dll` links against `msvcprt` (MSVC release CRT).

### 13.3 How to build and run a profiling session

**Step 1 — Build Prizm with Tracy:**

```bash
/mnt/c/Dev/jai/bin/jai-linux first.jai - tracy
```

This produces the normal `Prizm` executable with Tracy profiling compiled in. Because the library is
built with `-DTRACY_ON_DEMAND`, it has zero overhead when no Tracy GUI is connected.

**Step 2 — Download the Tracy GUI:**

Get the Tracy 0.12.x viewer from the releases page (Tracy version must match the library):
`https://github.com/wolfpld/tracy/releases`

- Linux: download `tracy-0.12.x-linux-x86_64.tar.gz` and extract
- Windows: download `Tracy-0.12.x.7z`

Run the `tracy` (Linux) or `Tracy.exe` (Windows) executable.

**Step 3 — Profile:**

1. Start the Tracy GUI.
2. Run Prizm: `./Prizm shapes/*.obj`
3. In Tracy GUI, click **Connect** (it will auto-detect the running process on `localhost:8086`).
4. Prizm will start streaming profiling data. The GUI shows per-frame CPU zones and the frame timeline.

**Interpreting the timeline:**

- **Frame separator** (`FrameMark`): each vertical bar in Tracy's "Frames" bar is one Prizm frame.
- **`gpu_submit`** (red): the entire SDL GPU command recording + submit for one frame.
- **`maybe_update_render_info_gpu`** (auto-named): how long dirty mesh CPU-to-GPU uploads take.
  - **`mesh_triangles`** (blue): triangle soup build (normal computation, barycentric packing).
  - **`mesh_segments`** (green): segment buffer build.
  - **`mesh_points`** (orange): point buffer build.
- **`load_obj`** (teal): OBJ file parse time — visible as a spike when files are loaded or reloaded.
- All other procedures are auto-instrumented and appear with their source names.

**Useful Tracy shortcuts:**
- `F` — frame detail view
- `S` — statistics view (sort procedures by total/mean time)
- `Z` — zoom to selection
- Click a zone to inspect call stack and timing

### 13.4 Rebuilding the Tracy library from source

Only needed if the pre-built `.so` doesn't work on the target system (e.g. glibc version mismatch).

**Linux (g++, Ubuntu 22.04+):**

```bash
cd modules/tracy
g++ -std=c++20 -DTRACY_ENABLE -DTRACY_EXPORTS -DTRACY_ON_DEMAND \
    -Wno-deprecated-declarations -fPIC -shared \
    -o linux/libtracy.so tracy/public/TracyClient.cpp \
    -lpthread -ldl
# Do NOT commit libtracy.a — the dynamic .so is what first.jai copies to the output directory.
```

The roeyb1 `jai generate.jai` approach also works but requires the Jai `Bindings_Generator` module
(which needs libclang) and will also regenerate `bindings.jai`. Use the manual `g++` command above
if you only need to rebuild the library for a new glibc.

**Windows (from a Visual Studio Developer Command Prompt):**

```
cd modules\tracy
jai generate.jai
# Outputs: windows\libtracy.dll, windows\libtracy.lib
```

**macOS (stretch goal — not yet tested):**

```bash
brew install llvm  # or use Xcode clang
cd modules/tracy
jai generate.jai
# Outputs: macos/libtracy.a, macos/libtracy.so (universal binary for x64+arm64)
# Then add macOS libtracy binaries and test the build.
```

Note: `bindings.jai` already has the `#library "macos/libtracy"` clause; only the binary is missing.
Ask before attempting macOS work — it needs a native Mac build environment.

### 13.5 GPU profiling (deferred)

CPU profiling is complete. GPU profiling (seeing which draw calls cost what on the GPU) is deferred.
See §12.4 for the design: the current OpenGL path can use `glQueryCounter` + Tracy GPU zones;
the SDL3 GPU path would need an SDL Vulkan interop or calibrated timestamp approximation.
Implement after the SDL GPU port stabilises (post-§9 Phase 7).

---

## 11. Decisions (resolved 2026-05-31)

1. **Shader bytecode in the repo:** ✅ Vendored SPIR-V (`.spv`) in `shaders/` (~50 KB, no LFS
   needed at this size). `first.jai` detects `glslangValidator` at build time; if absent, uses
   the vendored files. DXIL/MSL cross-compilation deferred to SDL_shadercross integration.
2. **ImGui platform backend:** **Delete both `source/imgui_impl_sdl.jai` and
   `source/imgui_impl_opengl3.jai`**. Use the official `ImplSDL3_*` + `ImplSDLGPU3_*` pair from
   `modules/ImGui/backends/`. Platform event reading in `handle_events` is unaffected.
3. **Deferred renderer:** **Dropped** — deleted, not ported (RT-6).
4. **Shader authoring language:** **GLSL 450** → SPIR-V (+ MSL/DXIL via SDL_shadercross).
5. **Clip-space strategy:** **Global fix** — pass `depth_range_01=true` to
   `orthographic_projection_matrix` and fix all `z=-1` unproject call-sites (RT-5).
