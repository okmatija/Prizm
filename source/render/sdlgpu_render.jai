// SDL3 GPU renderer — replaces the OpenGL render system.
// init_rendering_gpu() is called once at startup; render_entities_gpu() each frame.
// The GL-based Render_Info, shader_*.jai, and render_*.jai remain in the codebase but are unused.

//
// ---- GPU buffer handle per entity (stored alongside the legacy Render_Info) ----
//

Render_Info_GPU :: struct {
    is_dirty := true; // set when geometry changes; cleared after GPU upload

    // One SDL_GPUBuffer per geometry type.
    // Triangles buffer layout (non-interleaved, all arrays have NVT = 3*tri_count verts):
    //   [positions: NVT×12][smooth_normals: NVT×12][face_normals: NVT×12][barycentrics: NVT×12][colors: NVT×12]
    // Points buffer layout (NVP = point_count):
    //   [positions: NVP×12][colors: NVP×12]
    // Segments buffer layout (NVS = 2*seg_count):
    //   [positions: NVS×12][colors: NVS×12]
    // Positions buffer (unreferenced vertices, NVV = mesh.positions.count):
    //   [positions: NVV×12][colors: NVV×12]

    triangles_buf : *SDL_GPUBuffer;
    triangles_NVT : u32;          // vertex count for triangles (= 3 * tri_count)

    segments_buf  : *SDL_GPUBuffer;
    segments_NVS  : u32;          // = 2 * seg_count

    points_buf    : *SDL_GPUBuffer;
    points_NVP    : u32;          // = point_count

    positions_buf : *SDL_GPUBuffer;
    positions_NVV : u32;          // = position count

    // Normal vector LINELIST buffers (base_pos: vec3, normal: vec3) × 2 per normal.
    // Endpoint flag is derived from gl_VertexIndex % 2 in the shader.
    tri_normals_buf : *SDL_GPUBuffer; // 6 verts per triangle (3 normals × 2)
    tri_normals_NV  : u32;
    seg_normals_buf : *SDL_GPUBuffer; // 4 verts per segment  (2 normals × 2)
    seg_normals_NV  : u32;
    pt_normals_buf  : *SDL_GPUBuffer; // 2 verts per point    (1 normal  × 2)
    pt_normals_NV   : u32;
}

//
// ---- UBO structs (must match std140 layout in the shaders exactly) ----
//

Transform_UBO :: struct {
    clip_from_view   : Matrix4; // 64 bytes
    view_from_world  : Matrix4; // 64 bytes
    world_from_model : Matrix4; // 64 bytes
} // 192 bytes
#assert(size_of(Transform_UBO) == 192);

Clip_UBO :: struct {
    clip_sphere           : [4]float; // xyz=center, w=radius          (16 bytes)
    clip_sphere_prev      : [4]float; // xyz=center, w=radius          (16 bytes)
    clip_flags            : [4]u32;   // x=sphere_active, y=clip_radius_mode (16 bytes)
    range_normal          : [3][4]float; // xyz=normal, w=0             (48 bytes)
    range_min_max         : [3][4]float; // x=min, y=max, z=active_f   (48 bytes)
} // 144 bytes
#assert(size_of(Clip_UBO) == 144);

Triangle_Style_UBO :: struct {
    color                : [4]float; // rgba                            (16 bytes)
    edges_color          : [4]float; // rgba                            (16 bytes)
    backface_color_wave  : [4]float; // xyz=backface_rgb, w=wave        (16 bytes)
    look_dir_edges_width : [4]float; // xyz=look_dir, w=edges_width     (16 bytes)
    style_flags          : [4]u32;   // x=frontface_mode, y=backface_mode, z=flat_shading, w=backface_visible (16 bytes)
} // 80 bytes
#assert(size_of(Triangle_Style_UBO) == 80);

PL_Style_UBO :: struct {
    color       : [4]float; // rgba   (16 bytes)
    style_flags : [4]u32;   // x=color_mode, y=clip_mode (16 bytes)
    wave_pad    : [4]float; // x=wave (16 bytes)
} // 48 bytes
#assert(size_of(PL_Style_UBO) == 48);

AABB_UBO :: struct {
    clip_from_view   : Matrix4;  // 64
    view_from_world  : Matrix4;  // 64
    world_from_model : Matrix4;  // 64
    aabb_min         : [4]float; // 16
    aabb_max         : [4]float; // 16
    color            : [4]float; // 16
} // 240 bytes
#assert(size_of(AABB_UBO) == 240);

Background_UBO :: struct {
    resolution_time : [4]float; // xyz=resolution, w=iTime (16 bytes)
}
#assert(size_of(Background_UBO) == 16);

Normals_Vert_UBO :: struct {
    clip_from_view   : Matrix4;  // 64
    view_from_world  : Matrix4;  // 64
    world_from_model : Matrix4;  // 64
    normal_scale     : float;    // 4
    do_normalize     : u32;      // 4
    _pad0            : float;    // 4
    _pad1            : float;    // 4
} // 208 bytes
#assert(size_of(Normals_Vert_UBO) == 208);

Sized_Prim_Vert_UBO :: struct {
    clip_from_view   : Matrix4;  // 64
    view_from_world  : Matrix4;  // 64
    world_from_model : Matrix4;  // 64
    prim_size_px     : float;    // 4  — line width or point size in pixels
    viewport_w       : float;    // 4
    viewport_h       : float;    // 4
    _pad             : float;    // 4
} // 208 bytes
#assert(size_of(Sized_Prim_Vert_UBO) == 208);

Normals_Frag_UBO :: struct {
    color        : [4]float; // 16
    clip_sphere  : [4]float; // 16
    clip_flags   : [4]u32;   // 16
    range_normal : [3][4]float; // 48
    range_min_max: [3][4]float; // 48
} // 144 bytes
#assert(size_of(Normals_Frag_UBO) == 144);

//
// ---- Pipeline inventory ----
//

SDLGPU_Render_State :: struct {
    pso_triangles      : *SDL_GPUGraphicsPipeline; // FILL, depth on/write on, alpha blend
    pso_triangles_line : *SDL_GPUGraphicsPipeline; // LINE fill, depth on, no blend
    pso_lines          : *SDL_GPUGraphicsPipeline; // LINELIST, depth on, alpha blend
    pso_points         : *SDL_GPUGraphicsPipeline; // POINTLIST, depth on, alpha blend
    pso_background     : *SDL_GPUGraphicsPipeline; // TRIANGLELIST, no depth, no blend
    pso_aabb           : *SDL_GPUGraphicsPipeline; // LINELIST, depth on, no blend
    pso_normals        : *SDL_GPUGraphicsPipeline; // LINELIST, depth on, alpha blend
    pso_thick_lines    : *SDL_GPUGraphicsPipeline; // TRIANGLELIST, instance drawing, alpha blend
    pso_sized_points   : *SDL_GPUGraphicsPipeline; // TRIANGLELIST, instance drawing, alpha blend
    unit_quad_line_buf : *SDL_GPUBuffer; // 6-vertex unit quad for thick lines: (t, side)
    unit_quad_pt_buf   : *SDL_GPUBuffer; // 6-vertex unit square for sized points: (x, y)
}

g_sdlgpu : SDLGPU_Render_State;

// Compiled SPIR-V (embedded at build time)
SDLGPU_VERT_TRI,  _V1 :: #run read_entire_file(".build/shaders/sdlgpu_triangles.vert.spv");     #assert(_V1);
SDLGPU_FRAG_TRI,  _V2 :: #run read_entire_file(".build/shaders/sdlgpu_triangles.frag.spv");     #assert(_V2);
SDLGPU_VERT_PL,   _V3 :: #run read_entire_file(".build/shaders/sdlgpu_points_lines.vert.spv");  #assert(_V3);
SDLGPU_FRAG_PL,   _V4 :: #run read_entire_file(".build/shaders/sdlgpu_points_lines.frag.spv");  #assert(_V4);
SDLGPU_VERT_BG,   _V5 :: #run read_entire_file(".build/shaders/sdlgpu_background.vert.spv");    #assert(_V5);
SDLGPU_FRAG_BG,   _V6 :: #run read_entire_file(".build/shaders/sdlgpu_background.frag.spv");    #assert(_V6);
SDLGPU_VERT_AABB, _V7 :: #run read_entire_file(".build/shaders/sdlgpu_aabb.vert.spv");          #assert(_V7);
SDLGPU_FRAG_AABB, _V8 :: #run read_entire_file(".build/shaders/sdlgpu_aabb.frag.spv");          #assert(_V8);
SDLGPU_VERT_NRM,  _V9 :: #run read_entire_file(".build/shaders/sdlgpu_normals.vert.spv");       #assert(_V9);
SDLGPU_FRAG_NRM,  _VA :: #run read_entire_file(".build/shaders/sdlgpu_normals.frag.spv");       #assert(_VA);
SDLGPU_VERT_TL,   _VB :: #run read_entire_file(".build/shaders/sdlgpu_thick_lines.vert.spv");   #assert(_VB);
SDLGPU_VERT_SP,   _VC :: #run read_entire_file(".build/shaders/sdlgpu_sized_points.vert.spv");  #assert(_VC);

//
// ---- Helpers ----
//

make_gpu_shader :: (device : *SDL_GPUDevice, spv : string, stage : SDL_GPUShaderStage, num_uniform_buffers : u32) -> *SDL_GPUShader {
    info := SDL_GPUShaderCreateInfo.{
        code_size           = cast(u64) spv.count,
        code                = spv.data,
        entrypoint          = "main",
        format              = SDL_GPU_SHADERFORMAT_SPIRV,
        stage               = stage,
        num_uniform_buffers = num_uniform_buffers,
    };
    s := SDL_CreateGPUShader(device, *info);
    assert(s != null, "SDL_CreateGPUShader failed: %", to_string(SDL_GetError()));
    return s;
}

make_pipeline :: (
    device          : *SDL_GPUDevice,
    vert            : *SDL_GPUShader,
    frag            : *SDL_GPUShader,
    swapchain_fmt   : SDL_GPUTextureFormat,
    primitive_type  : SDL_GPUPrimitiveType,
    fill_mode       : SDL_GPUFillMode,
    blend           : bool,
    vertex_buf_descs: []SDL_GPUVertexBufferDescription,
    vertex_attrs    : []SDL_GPUVertexAttribute,
) -> *SDL_GPUGraphicsPipeline {

    color_desc := SDL_GPUColorTargetDescription.{
        format = swapchain_fmt,
        blend_state = ifx blend then SDL_GPUColorTargetBlendState.{
            src_color_blendfactor  = .SRC_ALPHA,
            dst_color_blendfactor  = .ONE_MINUS_SRC_ALPHA,
            color_blend_op         = .ADD,
            src_alpha_blendfactor  = .ONE,
            dst_alpha_blendfactor  = .ONE_MINUS_SRC_ALPHA,
            alpha_blend_op         = .ADD,
            enable_blend           = true,
        } else .{},
    };

    info := SDL_GPUGraphicsPipelineCreateInfo.{
        vertex_shader   = vert,
        fragment_shader = frag,
        primitive_type  = primitive_type,
        rasterizer_state = .{ fill_mode = fill_mode, cull_mode = .NONE },
        depth_stencil_state = .{
            compare_op                = .LESS_OR_EQUAL,
            enable_depth_test         = true,
            enable_depth_write        = true,
        },
        vertex_input_state = .{
            vertex_buffer_descriptions = vertex_buf_descs.data,
            num_vertex_buffers         = cast(u32) vertex_buf_descs.count,
            vertex_attributes          = vertex_attrs.data,
            num_vertex_attributes      = cast(u32) vertex_attrs.count,
        },
        target_info = .{
            color_target_descriptions = *color_desc,
            num_color_targets         = 1,
            depth_stencil_format      = depth_format,
            has_depth_stencil_target  = true,
        },
    };
    pso := SDL_CreateGPUGraphicsPipeline(device, *info);
    assert(pso != null, "SDL_CreateGPUGraphicsPipeline failed: %", to_string(SDL_GetError()));
    return pso;
}

//
// ---- Init / shutdown ----
//

depth_texture : *SDL_GPUTexture; // owned by this module; recreated on resize

init_depth_texture :: () {
    if depth_texture {
        SDL_ReleaseGPUTexture(app.gpu_device, depth_texture);
        depth_texture = null;
    }
    supported := SDL_GPUTextureSupportsFormat(app.gpu_device, .D32_FLOAT, .SDL_GPU_TEXTURETYPE_2D, SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET);
    if !supported {
        print("[sdlgpu] D32_FLOAT depth not supported, trying D16_UNORM\n");
    }
    fmt : SDL_GPUTextureFormat = ifx supported then .D32_FLOAT else .D16_UNORM;

    info := SDL_GPUTextureCreateInfo.{
        type                = .SDL_GPU_TEXTURETYPE_2D,
        format              = fmt,
        usage               = SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET,
        width               = cast(u32) app.window_size.width,
        height              = cast(u32) app.window_size.height,
        layer_count_or_depth = 1,
        num_levels          = 1,
        sample_count        = .SDL_GPU_SAMPLECOUNT_1,
    };
    depth_texture = SDL_CreateGPUTexture(app.gpu_device, *info);
    assert(depth_texture != null, "Failed to create depth texture: %", to_string(SDL_GetError()));

    depth_format = fmt; // store for pipeline creation
}

depth_format : SDL_GPUTextureFormat;

init_rendering_gpu :: () {
    gpu := app.gpu_device;
    fmt := SDL_GetGPUSwapchainTextureFormat(gpu, app.window);

    init_depth_texture(); // sets depth_format; must run before make_pipeline

    // ---- Triangle vertex layout (5 separate bindings, one per attribute array) ----
    tri_buf_descs := SDL_GPUVertexBufferDescription.[
        .{slot=0, pitch=12, input_rate=.VERTEX},
        .{slot=1, pitch=12, input_rate=.VERTEX},
        .{slot=2, pitch=12, input_rate=.VERTEX},
        .{slot=3, pitch=12, input_rate=.VERTEX},
        .{slot=4, pitch=12, input_rate=.VERTEX},
    ];
    tri_attrs := SDL_GPUVertexAttribute.[
        .{location=0, buffer_slot=0, format=.FLOAT3, offset=0}, // position
        .{location=1, buffer_slot=1, format=.FLOAT3, offset=0}, // smooth_normal
        .{location=2, buffer_slot=2, format=.FLOAT3, offset=0}, // face_normal
        .{location=3, buffer_slot=3, format=.FLOAT3, offset=0}, // barycentric
        .{location=4, buffer_slot=4, format=.FLOAT3, offset=0}, // color
    ];

    // ---- Points/lines vertex layout (2 bindings: position, color) ----
    pl_buf_descs := SDL_GPUVertexBufferDescription.[
        .{slot=0, pitch=12, input_rate=.VERTEX},
        .{slot=1, pitch=12, input_rate=.VERTEX},
    ];
    pl_attrs := SDL_GPUVertexAttribute.[
        .{location=0, buffer_slot=0, format=.FLOAT3, offset=0}, // position
        .{location=1, buffer_slot=1, format=.FLOAT3, offset=0}, // color
    ];

    vert_tri := make_gpu_shader(gpu, SDLGPU_VERT_TRI, .VERTEX,   1);
    frag_tri := make_gpu_shader(gpu, SDLGPU_FRAG_TRI, .FRAGMENT, 2);
    vert_pl  := make_gpu_shader(gpu, SDLGPU_VERT_PL,  .VERTEX,   1);
    frag_pl  := make_gpu_shader(gpu, SDLGPU_FRAG_PL,  .FRAGMENT, 2);

    g_sdlgpu.pso_triangles = make_pipeline(
        gpu, vert_tri, frag_tri, fmt, .TRIANGLELIST, .FILL, blend=true, tri_buf_descs, tri_attrs);
    g_sdlgpu.pso_triangles_line = make_pipeline(
        gpu, vert_tri, frag_tri, fmt, .TRIANGLELIST, .LINE, blend=false, tri_buf_descs, tri_attrs);
    g_sdlgpu.pso_lines = make_pipeline(
        gpu, vert_pl,  frag_pl,  fmt, .LINELIST,     .FILL, blend=true, pl_buf_descs, pl_attrs);
    g_sdlgpu.pso_points = make_pipeline(
        gpu, vert_pl,  frag_pl,  fmt, .POINTLIST,    .FILL, blend=true, pl_buf_descs, pl_attrs);

    SDL_ReleaseGPUShader(gpu, vert_tri);
    SDL_ReleaseGPUShader(gpu, frag_tri);
    SDL_ReleaseGPUShader(gpu, vert_pl);
    SDL_ReleaseGPUShader(gpu, frag_pl);

    // ---- Background: no vertex buffers, no depth ----
    {
        vert := make_gpu_shader(gpu, SDLGPU_VERT_BG, .VERTEX,   0);
        frag := make_gpu_shader(gpu, SDLGPU_FRAG_BG, .FRAGMENT, 1);
        empty_buf_descs : []SDL_GPUVertexBufferDescription;
        empty_attrs     : []SDL_GPUVertexAttribute;
        color_desc := SDL_GPUColorTargetDescription.{ format = fmt };
        info := SDL_GPUGraphicsPipelineCreateInfo.{
            vertex_shader   = vert,
            fragment_shader = frag,
            primitive_type  = .TRIANGLELIST,
            rasterizer_state = .{ fill_mode = .FILL, cull_mode = .NONE },
            target_info = .{
                color_target_descriptions = *color_desc,
                num_color_targets         = 1,
                depth_stencil_format      = depth_format,
                has_depth_stencil_target  = true, // pass uses depth target, but no depth test here
            },
        };
        g_sdlgpu.pso_background = SDL_CreateGPUGraphicsPipeline(gpu, *info);
        assert(g_sdlgpu.pso_background != null, "background pipeline failed: %", to_string(SDL_GetError()));
        SDL_ReleaseGPUShader(gpu, vert);
        SDL_ReleaseGPUShader(gpu, frag);
    }

    // ---- AABB: no vertex buffers, vertex UBO only ----
    {
        vert := make_gpu_shader(gpu, SDLGPU_VERT_AABB, .VERTEX,   1);
        frag := make_gpu_shader(gpu, SDLGPU_FRAG_AABB, .FRAGMENT, 0);
        empty_buf_descs : []SDL_GPUVertexBufferDescription;
        empty_attrs     : []SDL_GPUVertexAttribute;
        g_sdlgpu.pso_aabb = make_pipeline(gpu, vert, frag, fmt, .LINELIST, .FILL, blend=false, empty_buf_descs, empty_attrs);
        SDL_ReleaseGPUShader(gpu, vert);
        SDL_ReleaseGPUShader(gpu, frag);
    }

    // ---- Normals: (base_pos, normal) vertex layout, 2 vertex buffers ----
    {
        nrm_buf_descs := SDL_GPUVertexBufferDescription.[
            .{slot=0, pitch=12, input_rate=.VERTEX}, // in_base
            .{slot=1, pitch=12, input_rate=.VERTEX}, // in_normal
        ];
        nrm_attrs := SDL_GPUVertexAttribute.[
            .{location=0, buffer_slot=0, format=.FLOAT3, offset=0},
            .{location=1, buffer_slot=1, format=.FLOAT3, offset=0},
        ];
        vert := make_gpu_shader(gpu, SDLGPU_VERT_NRM, .VERTEX,   1);
        frag := make_gpu_shader(gpu, SDLGPU_FRAG_NRM, .FRAGMENT, 1);
        g_sdlgpu.pso_normals = make_pipeline(gpu, vert, frag, fmt, .LINELIST, .FILL, blend=true, nrm_buf_descs, nrm_attrs);
        SDL_ReleaseGPUShader(gpu, vert);
        SDL_ReleaseGPUShader(gpu, frag);
    }

    // ---- Thick lines: (t,side) VERTEX + (A,B,colorA,colorB) INSTANCE ----
    {
        tl_buf_descs := SDL_GPUVertexBufferDescription.[
            .{slot=0, pitch=8,  input_rate=.VERTEX},   // (t, side)
            .{slot=1, pitch=24, input_rate=.INSTANCE}, // in_pos_a (12) + in_pos_b (12)
            .{slot=2, pitch=24, input_rate=.INSTANCE}, // in_color_a (12) + in_color_b (12)
        ];
        tl_attrs := SDL_GPUVertexAttribute.[
            .{location=0, buffer_slot=0, format=.FLOAT2, offset=0},  // corner (t,side)
            .{location=1, buffer_slot=1, format=.FLOAT3, offset=0},  // in_pos_a
            .{location=2, buffer_slot=1, format=.FLOAT3, offset=12}, // in_pos_b
            .{location=3, buffer_slot=2, format=.FLOAT3, offset=0},  // in_color_a
            .{location=4, buffer_slot=2, format=.FLOAT3, offset=12}, // in_color_b
        ];
        vert := make_gpu_shader(gpu, SDLGPU_VERT_TL, .VERTEX,   1);
        frag := make_gpu_shader(gpu, SDLGPU_FRAG_PL, .FRAGMENT, 2); // reuse points/lines frag
        g_sdlgpu.pso_thick_lines = make_pipeline(gpu, vert, frag, fmt, .TRIANGLELIST, .FILL, blend=true, tl_buf_descs, tl_attrs);
        SDL_ReleaseGPUShader(gpu, vert);
        SDL_ReleaseGPUShader(gpu, frag);
    }

    // ---- Sized points: (x,y) VERTEX + (center,color) INSTANCE ----
    {
        sp_buf_descs := SDL_GPUVertexBufferDescription.[
            .{slot=0, pitch=8,  input_rate=.VERTEX},   // corner (x,y)
            .{slot=1, pitch=12, input_rate=.INSTANCE}, // in_center
            .{slot=2, pitch=12, input_rate=.INSTANCE}, // in_color
        ];
        sp_attrs := SDL_GPUVertexAttribute.[
            .{location=0, buffer_slot=0, format=.FLOAT2, offset=0}, // corner
            .{location=1, buffer_slot=1, format=.FLOAT3, offset=0}, // in_center
            .{location=2, buffer_slot=2, format=.FLOAT3, offset=0}, // in_color
        ];
        vert := make_gpu_shader(gpu, SDLGPU_VERT_SP, .VERTEX,   1);
        frag := make_gpu_shader(gpu, SDLGPU_FRAG_PL, .FRAGMENT, 2);
        g_sdlgpu.pso_sized_points = make_pipeline(gpu, vert, frag, fmt, .TRIANGLELIST, .FILL, blend=true, sp_buf_descs, sp_attrs);
        SDL_ReleaseGPUShader(gpu, vert);
        SDL_ReleaseGPUShader(gpu, frag);
    }

    // ---- Static unit-quad buffers uploaded once ----
    {
        // Thick-line quad: (t, side) — 6 vertices
        LINE_QUAD : [12]float : .[
            0, -1,  0, +1,  1, +1,   // tri 1
            0, -1,  1, +1,  1, -1,   // tri 2
        ];
        cmd := SDL_AcquireGPUCommandBuffer(gpu);
        g_sdlgpu.unit_quad_line_buf = upload_to_gpu_buffer(cmd, LINE_QUAD.data, size_of(type_of(LINE_QUAD)));

        // Sized-point quad: (x, y) corner — 6 vertices
        PT_QUAD : [12]float : .[
            -1, -1,  +1, -1,  +1, +1,  // tri 1
            -1, -1,  +1, +1,  -1, +1,  // tri 2
        ];
        g_sdlgpu.unit_quad_pt_buf = upload_to_gpu_buffer(cmd, PT_QUAD.data, size_of(type_of(PT_QUAD)));
        SDL_SubmitGPUCommandBuffer(cmd);
    }
}

deinit_rendering_gpu :: () {
    gpu := app.gpu_device;
    if g_sdlgpu.pso_triangles       SDL_ReleaseGPUGraphicsPipeline(gpu, g_sdlgpu.pso_triangles);
    if g_sdlgpu.pso_triangles_line  SDL_ReleaseGPUGraphicsPipeline(gpu, g_sdlgpu.pso_triangles_line);
    if g_sdlgpu.pso_lines           SDL_ReleaseGPUGraphicsPipeline(gpu, g_sdlgpu.pso_lines);
    if g_sdlgpu.pso_points          SDL_ReleaseGPUGraphicsPipeline(gpu, g_sdlgpu.pso_points);
    if g_sdlgpu.pso_background      SDL_ReleaseGPUGraphicsPipeline(gpu, g_sdlgpu.pso_background);
    if g_sdlgpu.pso_aabb            SDL_ReleaseGPUGraphicsPipeline(gpu, g_sdlgpu.pso_aabb);
    if g_sdlgpu.pso_normals         SDL_ReleaseGPUGraphicsPipeline(gpu, g_sdlgpu.pso_normals);
    if g_sdlgpu.pso_thick_lines     SDL_ReleaseGPUGraphicsPipeline(gpu, g_sdlgpu.pso_thick_lines);
    if g_sdlgpu.pso_sized_points    SDL_ReleaseGPUGraphicsPipeline(gpu, g_sdlgpu.pso_sized_points);
    if g_sdlgpu.unit_quad_line_buf  SDL_ReleaseGPUBuffer(gpu, g_sdlgpu.unit_quad_line_buf);
    if g_sdlgpu.unit_quad_pt_buf    SDL_ReleaseGPUBuffer(gpu, g_sdlgpu.unit_quad_pt_buf);
    if depth_texture                SDL_ReleaseGPUTexture(gpu, depth_texture);
}

//
// ---- Buffer upload helpers ----
//

upload_to_gpu_buffer :: (cmd : *SDL_GPUCommandBuffer, data : *void, byte_count : u32) -> *SDL_GPUBuffer {
    if byte_count == 0 return null;

    gpu := app.gpu_device;

    tbuf_info := SDL_GPUTransferBufferCreateInfo.{ usage = .UPLOAD, size = byte_count };
    tbuf := SDL_CreateGPUTransferBuffer(gpu, *tbuf_info);
    assert(tbuf != null);

    ptr := SDL_MapGPUTransferBuffer(gpu, tbuf, false);
    if ptr == null {
        print("[sdlgpu] SDL_MapGPUTransferBuffer returned null: %\n", to_string(SDL_GetError()));
        SDL_ReleaseGPUTransferBuffer(gpu, tbuf);
        return null;
    }
    memcpy(ptr, data, byte_count);
    SDL_UnmapGPUTransferBuffer(gpu, tbuf);

    gbuf_info := SDL_GPUBufferCreateInfo.{ usage = SDL_GPU_BUFFERUSAGE_VERTEX, size = byte_count };
    gbuf := SDL_CreateGPUBuffer(gpu, *gbuf_info);
    assert(gbuf != null);

    copy_pass := SDL_BeginGPUCopyPass(cmd);
    if copy_pass == null {
        print("[sdlgpu] SDL_BeginGPUCopyPass returned null: %\n", to_string(SDL_GetError()));
        SDL_ReleaseGPUBuffer(gpu, gbuf);
        SDL_ReleaseGPUTransferBuffer(gpu, tbuf);
        return null;
    }
    src := SDL_GPUTransferBufferLocation.{ transfer_buffer = tbuf, offset = 0 };
    dst := SDL_GPUBufferRegion.{ buffer = gbuf, offset = 0, size = byte_count };
    SDL_UploadToGPUBuffer(copy_pass, *src, *dst, false);
    SDL_EndGPUCopyPass(copy_pass);

    SDL_ReleaseGPUTransferBuffer(gpu, tbuf);
    return gbuf;
}

//
// ---- Vertex data builders ----
//

// Standard barycentric coords cycling per triangle vertex
BARY : [3]Vector3 : .[ .{1,0,0}, .{0,1,0}, .{0,0,1} ];

maybe_update_render_info_gpu :: (gpu_info : *Render_Info_GPU, render_info : *Render_Info, mesh : *Simple_Mesh, cmd : *SDL_GPUCommandBuffer) {
    if mesh.positions.count == 0 return;
    if !gpu_info.is_dirty return;
    defer gpu_info.is_dirty = false;

    // Bounding geometry (shared with ray-casting code)
    render_info.bounding_sphere = bounding_sphere_ritter(mesh.positions);
    render_info.bounding_aabb   = make_axis_box3(..mesh.positions);

    gpu := app.gpu_device;

    // ---- Triangles ----
    if mesh.triangles.count {
        N := 3 * mesh.triangles.count; // vertices in soup

        normals_attr : *Simple_Mesh_Triangle_Normals = find_or_add_mesh_attribute(mesh, TRIANGLE_NORMALS_ATTRIBUTE_NAME, Simple_Mesh_Triangle_Normals);
        assert(normals_attr != null);
        if normals_attr.values.count == 0 {
            compute_vertex_normals_from_triangles(mesh, normals_attr);
        }

        // Build CPU arrays
        positions   : [..]Vector3 = temp_array(Vector3); array_reserve(*positions,   N);
        smooth_norms: [..]Vector3 = temp_array(Vector3); array_reserve(*smooth_norms, N);
        face_norms  : [..]Vector3 = temp_array(Vector3); array_reserve(*face_norms,   N);
        barycentrics: [..]Vector3 = temp_array(Vector3); array_reserve(*barycentrics, N);
        colors      : [..]Vector3 = temp_array(Vector3); array_reserve(*colors,       N);

        for :ModelTriangleIterator mesh {
            vids := mesh_triangle_tuple(mesh, it_index);

            array_add(*positions, it.a);
            array_add(*positions, it.b);
            array_add(*positions, it.c);

            // Smooth normals: stored as 3 vec3s per triangle in normals_attr.values (Matrix3 layout)
            // Each Matrix3 stores 3 rows, each row is one vertex normal.
            if it_index < normals_attr.values.count {
                nm := normals_attr.values[it_index];
                array_add(*smooth_norms, .{nm._11, nm._12, nm._13});
                array_add(*smooth_norms, .{nm._21, nm._22, nm._23});
                array_add(*smooth_norms, .{nm._31, nm._32, nm._33});
            } else {
                face := normalize(cross(it.b - it.a, it.c - it.a));
                array_add(*smooth_norms, face);
                array_add(*smooth_norms, face);
                array_add(*smooth_norms, face);
            }

            // Face normal: cross product of world-space vertices (flat shading)
            face_n := normalize(cross(it.b - it.a, it.c - it.a));
            array_add(*face_norms, face_n);
            array_add(*face_norms, face_n);
            array_add(*face_norms, face_n);

            array_add(*barycentrics, BARY[0]);
            array_add(*barycentrics, BARY[1]);
            array_add(*barycentrics, BARY[2]);

            array_add(*colors, mesh.colors[vids.i]);
            array_add(*colors, mesh.colors[vids.j]);
            array_add(*colors, mesh.colors[vids.k]);
        }

        // Pack into one flat buffer [positions | smooth_n | face_n | bary | colors]
        NP := cast(u32)(N * size_of(Vector3));
        total := 5 * NP;
        flat_buf : *void = alloc(cast(s64) total,, temp);
        base := cast(*u8) flat_buf;
        memcpy(base + 0*NP, positions.data,    NP);
        memcpy(base + 1*NP, smooth_norms.data, NP);
        memcpy(base + 2*NP, face_norms.data,   NP);
        memcpy(base + 3*NP, barycentrics.data, NP);
        memcpy(base + 4*NP, colors.data,       NP);

        if gpu_info.triangles_buf  SDL_ReleaseGPUBuffer(gpu, gpu_info.triangles_buf);
        gpu_info.triangles_buf = upload_to_gpu_buffer(cmd, flat_buf, total);
        gpu_info.triangles_NVT = cast(u32) N;
    }

    // ---- Segments ----
    if mesh.segments.count {
        N := 2 * mesh.segments.count;
        NP := cast(u32)(N * size_of(Vector3));

        seg_pos   : [..]Vector3 = temp_array(Vector3); array_reserve(*seg_pos,   N);
        seg_color : [..]Vector3 = temp_array(Vector3); array_reserve(*seg_color, N);

        for :ModelSegmentIterator mesh {
            vids := mesh_segment_tuple(mesh, it_index);
            array_add(*seg_pos,   it.start);
            array_add(*seg_pos,   it.end);
            array_add(*seg_color, mesh.colors[vids.i]);
            array_add(*seg_color, mesh.colors[vids.j]);
        }

        flat_buf : *void = alloc(cast(s64)(2*NP),, temp);
        base := cast(*u8) flat_buf;
        memcpy(base,    seg_pos.data,   NP);
        memcpy(base+NP, seg_color.data, NP);

        if gpu_info.segments_buf  SDL_ReleaseGPUBuffer(gpu, gpu_info.segments_buf);
        gpu_info.segments_buf = upload_to_gpu_buffer(cmd, flat_buf, 2*NP);
        gpu_info.segments_NVS = cast(u32) N;
    }

    // ---- Points ----
    if mesh.points.count {
        N  := mesh.points.count;
        NP := cast(u32)(N * size_of(Vector3));

        pt_pos   : [..]Vector3 = temp_array(Vector3); array_reserve(*pt_pos,   N);
        pt_color : [..]Vector3 = temp_array(Vector3); array_reserve(*pt_color, N);

        for :ModelPointIterator mesh {
            array_add(*pt_pos,   it);
            array_add(*pt_color, mesh.colors[mesh.points[it_index]]);
        }

        flat_buf : *void = alloc(cast(s64)(2*NP),, temp);
        base := cast(*u8) flat_buf;
        memcpy(base,    pt_pos.data,   NP);
        memcpy(base+NP, pt_color.data, NP);

        if gpu_info.points_buf  SDL_ReleaseGPUBuffer(gpu, gpu_info.points_buf);
        gpu_info.points_buf = upload_to_gpu_buffer(cmd, flat_buf, 2*NP);
        gpu_info.points_NVP = cast(u32) N;
    }

    // ---- Triangle normal vectors (6 verts per triangle: 3 normals × 2 endpoints) ----
    if mesh.triangles.count {
        normals_attr : *Simple_Mesh_Triangle_Normals = find_mesh_attribute(mesh, TRIANGLE_NORMALS_ATTRIBUTE_NAME, Simple_Mesh_Triangle_Normals);
        if normals_attr && normals_attr.values.count == mesh.triangles.count {
            N  := 6 * mesh.triangles.count;
            NP := cast(u32)(N * size_of(Vector3));

            bases   : [..]Vector3 = temp_array(Vector3); array_reserve(*bases,   N);
            normals : [..]Vector3 = temp_array(Vector3); array_reserve(*normals, N);

            for tri_index : 0..mesh.triangles.count-1 {
                vids := mesh_triangle_tuple(mesh, tri_index);
                a := mesh.positions[vids.i];
                b := mesh.positions[vids.j];
                c := mesh.positions[vids.k];
                nm := normals_attr.values[tri_index];
                nv := Vector3.[.{nm._11, nm._12, nm._13}, .{nm._21, nm._22, nm._23}, .{nm._31, nm._32, nm._33}];
                pts := Vector3.[a, b, c];
                for i : 0..2 {
                    array_add(*bases,   pts[i]);
                    array_add(*bases,   pts[i]);
                    array_add(*normals, nv[i]);
                    array_add(*normals, nv[i]);
                }
            }

            flat_buf : *void = alloc(cast(s64)(2*NP),, temp);
            base := cast(*u8) flat_buf;
            memcpy(base,    bases.data,   NP);
            memcpy(base+NP, normals.data, NP);

            if gpu_info.tri_normals_buf  SDL_ReleaseGPUBuffer(gpu, gpu_info.tri_normals_buf);
            gpu_info.tri_normals_buf = upload_to_gpu_buffer(cmd, flat_buf, 2*NP);
            gpu_info.tri_normals_NV  = cast(u32) N;
        }
    }

    // ---- Segment normal vectors (4 verts per segment: 2 endpoints × 2) ----
    if mesh.segments.count {
        seg_nrm : *Simple_Mesh_Segment_Normals = find_mesh_attribute(mesh, SEGMENT_NORMALS_ATTRIBUTE_NAME, Simple_Mesh_Segment_Normals);
        if seg_nrm && seg_nrm.values.count == mesh.segments.count {
            N  := 4 * mesh.segments.count;
            NP := cast(u32)(N * size_of(Vector3));

            bases   : [..]Vector3 = temp_array(Vector3); array_reserve(*bases,   N);
            normals : [..]Vector3 = temp_array(Vector3); array_reserve(*normals, N);

            for seg_index : 0..mesh.segments.count-1 {
                vids := mesh_segment_tuple(mesh, seg_index);
                pts := Vector3.[mesh.positions[vids.i], mesh.positions[vids.j]];
                nm  := seg_nrm.values[seg_index];
                nv  := Vector3.[.{nm._11, nm._12, nm._13}, .{nm._21, nm._22, nm._23}];
                for i : 0..1 {
                    array_add(*bases,   pts[i]);
                    array_add(*bases,   pts[i]);
                    array_add(*normals, nv[i]);
                    array_add(*normals, nv[i]);
                }
            }

            flat_buf : *void = alloc(cast(s64)(2*NP),, temp);
            base := cast(*u8) flat_buf;
            memcpy(base,    bases.data,   NP);
            memcpy(base+NP, normals.data, NP);

            if gpu_info.seg_normals_buf  SDL_ReleaseGPUBuffer(gpu, gpu_info.seg_normals_buf);
            gpu_info.seg_normals_buf = upload_to_gpu_buffer(cmd, flat_buf, 2*NP);
            gpu_info.seg_normals_NV  = cast(u32) N;
        }
    }

    // ---- Point normal vectors (2 verts per point) ----
    if mesh.points.count {
        pt_nrm : *Simple_Mesh_Point_Normals = find_mesh_attribute(mesh, POINT_NORMALS_ATTRIBUTE_NAME, Simple_Mesh_Point_Normals);
        if pt_nrm && pt_nrm.values.count == mesh.points.count {
            N  := 2 * mesh.points.count;
            NP := cast(u32)(N * size_of(Vector3));

            bases   : [..]Vector3 = temp_array(Vector3); array_reserve(*bases,   N);
            normals : [..]Vector3 = temp_array(Vector3); array_reserve(*normals, N);

            for :ModelPointIterator mesh {
                n := pt_nrm.values[it_index];
                array_add(*bases,   it); array_add(*bases,   it);
                array_add(*normals, n);  array_add(*normals, n);
            }

            flat_buf : *void = alloc(cast(s64)(2*NP),, temp);
            base := cast(*u8) flat_buf;
            memcpy(base,    bases.data,   NP);
            memcpy(base+NP, normals.data, NP);

            if gpu_info.pt_normals_buf  SDL_ReleaseGPUBuffer(gpu, gpu_info.pt_normals_buf);
            gpu_info.pt_normals_buf = upload_to_gpu_buffer(cmd, flat_buf, 2*NP);
            gpu_info.pt_normals_NV  = cast(u32) N;
        }
    }

    // ---- Unreferenced vertex positions ----
    if mesh.positions.count {
        N  := mesh.positions.count;
        NP := cast(u32)(N * size_of(Vector3));

        flat_buf : *void = alloc(cast(s64)(2*NP),, temp);
        base := cast(*u8) flat_buf;
        memcpy(base,    mesh.positions.data, NP);
        memcpy(base+NP, mesh.colors.data,    NP);

        if gpu_info.positions_buf  SDL_ReleaseGPUBuffer(gpu, gpu_info.positions_buf);
        gpu_info.positions_buf = upload_to_gpu_buffer(cmd, flat_buf, 2*NP);
        gpu_info.positions_NVV = cast(u32) N;
    }
}

//
// ---- UBO fill helpers ----
//

fill_transform_ubo :: (world_from_model : Matrix4) -> Transform_UBO {
    ubo : Transform_UBO;
    // Flip top/bottom and use [0,1] depth range to match Vulkan NDC (Y-down, Z [0,1])
    cam := app.camera;
    ubo.clip_from_view   = orthographic_projection_matrix(cam.left, cam.right, cam.top, cam.bottom, cam.near, cam.far, depth_range_01=true);
    ubo.view_from_world  = make_look_at_matrix(app.camera);
    ubo.world_from_model = world_from_model;
    return ubo;
}

fill_clip_ubo :: (using di : Display_Info) -> Clip_UBO {
    ubo : Clip_UBO;
    ubo.clip_sphere      = .[clip_sphere.center.x, clip_sphere.center.y, clip_sphere.center.z, clip_sphere.radius];
    ubo.clip_sphere_prev = .[clip_sphere_prev.center.x, clip_sphere_prev.center.y, clip_sphere_prev.center.z, clip_sphere_prev.radius];
    ubo.clip_flags       = .[cast(u32) clip_sphere.is_active, cast(u32) clip_radius_mode, 0, 0];
    for i : 0..2 {
        r := clip_ranges[i];
        ubo.range_normal[i]  = .[r.normal.x, r.normal.y, r.normal.z, 0];
        ubo.range_min_max[i] = .[r.min, r.max, cast(float) cast(u32) r.is_active, 0];
    }
    return ubo;
}

fill_triangle_style_ubo :: (using di : Display_Info) -> Triangle_Style_UBO {
    ubo : Triangle_Style_UBO;
    wave := ifx flash_wave_dt == 0 then -1. else cos(5 * flash_wave_dt);
    look := normalize(current_look_direction());

    used_edges_width := triangle_style.edge_style.width;
    used_edges_visible := triangle_style.edge_style.visible;
    if clip_radius_mode_show_wireframe {
        used_edges_width   = MIN_EDGES_WIDTH_GL_FILL;
        used_edges_visible = true;
    }
    effective_edges_width := ifx used_edges_visible then max(used_edges_width, MIN_EDGES_WIDTH_GL_FILL) else 0.;
    if clip_radius_mode {
        effective_edges_width = max(triangle_style.edge_style.width, MIN_EDGES_WIDTH_GL_FILL);
        if clip_radius_mode_show_wireframe  effective_edges_width = MIN_EDGES_WIDTH_GL_FILL;
        if !triangle_style.edge_style.visible && !clip_radius_mode_show_wireframe  effective_edges_width = 0.;
    }

    ubo.color                = .[triangle_style.color.x, triangle_style.color.y, triangle_style.color.z, triangle_style.color.w];
    ubo.edges_color          = .[triangle_style.edge_style.color.x, triangle_style.edge_style.color.y, triangle_style.edge_style.color.z, triangle_style.edge_style.color.w];
    ubo.backface_color_wave  = .[triangle_style.backface_style.color.x, triangle_style.backface_style.color.y, triangle_style.backface_style.color.z, wave];
    ubo.look_dir_edges_width = .[look.x, look.y, look.z, effective_edges_width];
    ubo.style_flags          = .[
        cast(u32) triangle_style.color_mode,
        cast(u32) triangle_style.backface_style.color_mode,
        cast(u32) triangle_style.flat_shading,
        cast(u32) triangle_style.backface_style.visible,
    ];
    return ubo;
}

fill_pl_style_ubo :: (color : Vector4, color_mode : Color_Mode, clip_mode : Clip_Mode, wave : float) -> PL_Style_UBO {
    ubo : PL_Style_UBO;
    ubo.color       = .[color.x, color.y, color.z, color.w];
    ubo.style_flags = .[cast(u32) color_mode, cast(u32) clip_mode, 0, 0];
    ubo.wave_pad    = .[wave, 0, 0, 0];
    return ubo;
}

bind_pl_buffers :: (pass : *SDL_GPURenderPass, buf : *SDL_GPUBuffer, NP : u32) {
    bindings := SDL_GPUBufferBinding.[
        .{buffer=buf, offset=0},    // slot 0: positions
        .{buffer=buf, offset=NP},   // slot 1: colors
    ];
    SDL_BindGPUVertexBuffers(pass, 0, bindings.data, 2);
}

//
// ---- Per-entity render functions ----
//

sdlgpu_render_mesh_triangles :: (entity : *Entity, pass : *SDL_GPURenderPass, cmd : *SDL_GPUCommandBuffer) {
    using entity.display_info;
    if !entity.mesh.triangles.count return;
    if !triangle_style.visible return;
    if !entity.render_info_gpu.triangles_buf return;

    NVT := entity.render_info_gpu.triangles_NVT;
    NP  := NVT * size_of(Vector3);

    transform := fill_transform_ubo(entity.mesh.world_from_model);
    clip      := fill_clip_ubo(entity.display_info);
    style     := fill_triangle_style_ubo(entity.display_info);

    // Filled triangles with Blinn-Phong + wireframe
    SDL_BindGPUGraphicsPipeline(pass, g_sdlgpu.pso_triangles);
    {
        bindings := SDL_GPUBufferBinding.[
            .{buffer=entity.render_info_gpu.triangles_buf, offset=0},       // slot 0: positions
            .{buffer=entity.render_info_gpu.triangles_buf, offset=1*cast(u32)NP}, // slot 1: smooth_normal
            .{buffer=entity.render_info_gpu.triangles_buf, offset=2*cast(u32)NP}, // slot 2: face_normal
            .{buffer=entity.render_info_gpu.triangles_buf, offset=3*cast(u32)NP}, // slot 3: barycentric
            .{buffer=entity.render_info_gpu.triangles_buf, offset=4*cast(u32)NP}, // slot 4: color
        ];
        SDL_BindGPUVertexBuffers(pass, 0, bindings.data, 5);
    }
    SDL_PushGPUVertexUniformData(cmd, 0, *transform, size_of(Transform_UBO));
    SDL_PushGPUFragmentUniformData(cmd, 0, *clip,  size_of(Clip_UBO));
    SDL_PushGPUFragmentUniformData(cmd, 1, *style, size_of(Triangle_Style_UBO));
    SDL_DrawGPUPrimitives(pass, NVT, 1, 0, 0);

    // Degenerate triangle edges (LINE fill mode) — shows collapsed triangles
    if triangle_style.edge_style.visible || clip_radius_mode_show_wireframe {
        edge_style := fill_triangle_style_ubo(entity.display_info);
        // edges_width=0 in LINE mode suppresses the solid-wireframe overlay (it's pure GL_LINE here)
        edge_style.look_dir_edges_width[3] = 0.;
        edge_style.color = edge_style.edges_color;

        SDL_BindGPUGraphicsPipeline(pass, g_sdlgpu.pso_triangles_line);
        {
            bindings := SDL_GPUBufferBinding.[
                .{buffer=entity.render_info_gpu.triangles_buf, offset=0},
                .{buffer=entity.render_info_gpu.triangles_buf, offset=1*cast(u32)NP},
                .{buffer=entity.render_info_gpu.triangles_buf, offset=2*cast(u32)NP},
                .{buffer=entity.render_info_gpu.triangles_buf, offset=3*cast(u32)NP},
                .{buffer=entity.render_info_gpu.triangles_buf, offset=4*cast(u32)NP},
            ];
            SDL_BindGPUVertexBuffers(pass, 0, bindings.data, 5);
        }
        SDL_PushGPUVertexUniformData(cmd, 0, *transform, size_of(Transform_UBO));
        SDL_PushGPUFragmentUniformData(cmd, 0, *clip,       size_of(Clip_UBO));
        SDL_PushGPUFragmentUniformData(cmd, 1, *edge_style, size_of(Triangle_Style_UBO));
        SDL_DrawGPUPrimitives(pass, NVT, 1, 0, 0);
    }
}

sdlgpu_render_mesh_segments :: (entity : *Entity, pass : *SDL_GPURenderPass, cmd : *SDL_GPUCommandBuffer) {
    using entity.display_info;
    if !entity.mesh.segments.count return;
    if !segment_style.visible && !clip_radius_mode return;
    if !entity.render_info_gpu.segments_buf return;

    wave := ifx flash_wave_dt == 0 then -1. else cos(5 * flash_wave_dt);
    used_clip_mode := ifx clip_radius_mode then Clip_Mode.BLACKEN else Clip_Mode.HIDDEN;

    transform := fill_transform_ubo(entity.mesh.world_from_model);
    clip      := fill_clip_ubo(entity.display_info);
    style     := fill_pl_style_ubo(segment_style.color, segment_style.color_mode, used_clip_mode, wave);

    NVS := entity.render_info_gpu.segments_NVS;
    NP  := NVS * cast(u32) size_of(Vector3);

    SDL_BindGPUGraphicsPipeline(pass, g_sdlgpu.pso_lines);
    bind_pl_buffers(pass, entity.render_info_gpu.segments_buf, NP);
    SDL_PushGPUVertexUniformData(cmd, 0, *transform, size_of(Transform_UBO));
    SDL_PushGPUFragmentUniformData(cmd, 0, *clip,  size_of(Clip_UBO));
    SDL_PushGPUFragmentUniformData(cmd, 1, *style, size_of(PL_Style_UBO));
    SDL_DrawGPUPrimitives(pass, NVS, 1, 0, 0);
}

sdlgpu_render_mesh_points :: (entity : *Entity, pass : *SDL_GPURenderPass, cmd : *SDL_GPUCommandBuffer) {
    using entity.display_info;
    if !entity.mesh.points.count return;
    if !point_style.visible && !clip_radius_mode_show_wireframe return;
    if !entity.render_info_gpu.points_buf return;

    wave := ifx flash_wave_dt == 0 then -1. else cos(5 * flash_wave_dt);
    used_clip_mode := ifx clip_radius_mode then Clip_Mode.BLACKEN else Clip_Mode.HIDDEN;

    transform := fill_transform_ubo(entity.mesh.world_from_model);
    clip      := fill_clip_ubo(entity.display_info);
    style     := fill_pl_style_ubo(point_style.vertex_style.color, point_style.vertex_style.color_mode, used_clip_mode, wave);

    NVP := entity.render_info_gpu.points_NVP;
    NP  := NVP * cast(u32) size_of(Vector3);

    SDL_BindGPUGraphicsPipeline(pass, g_sdlgpu.pso_points);
    bind_pl_buffers(pass, entity.render_info_gpu.points_buf, NP);
    SDL_PushGPUVertexUniformData(cmd, 0, *transform, size_of(Transform_UBO));
    SDL_PushGPUFragmentUniformData(cmd, 0, *clip,  size_of(Clip_UBO));
    SDL_PushGPUFragmentUniformData(cmd, 1, *style, size_of(PL_Style_UBO));
    SDL_DrawGPUPrimitives(pass, NVP, 1, 0, 0);
}

sdlgpu_render_mesh_positions :: (entity : *Entity, pass : *SDL_GPURenderPass, cmd : *SDL_GPUCommandBuffer) {
    using entity.display_info;
    if !entity.mesh.positions.count return;
    if !vertex_style.visible && !clip_radius_mode_show_wireframe return;
    if !entity.render_info_gpu.positions_buf return;

    wave := ifx flash_wave_dt == 0 then -1. else cos(5 * flash_wave_dt);
    used_clip_mode := ifx clip_radius_mode then Clip_Mode.BLACKEN else Clip_Mode.HIDDEN;

    transform := fill_transform_ubo(entity.mesh.world_from_model);
    clip      := fill_clip_ubo(entity.display_info);
    style     := fill_pl_style_ubo(vertex_style.color, vertex_style.color_mode, used_clip_mode, wave);

    NVV := entity.render_info_gpu.positions_NVV;
    NP  := NVV * cast(u32) size_of(Vector3);

    SDL_BindGPUGraphicsPipeline(pass, g_sdlgpu.pso_points);
    bind_pl_buffers(pass, entity.render_info_gpu.positions_buf, NP);
    SDL_PushGPUVertexUniformData(cmd, 0, *transform, size_of(Transform_UBO));
    SDL_PushGPUFragmentUniformData(cmd, 0, *clip,  size_of(Clip_UBO));
    SDL_PushGPUFragmentUniformData(cmd, 1, *style, size_of(PL_Style_UBO));
    SDL_DrawGPUPrimitives(pass, NVV, 1, 0, 0);
}

//
// ---- Top-level render calls ----
// Split into two phases: upload (copy passes, before render pass) and draw (inside render pass).
//

// ---- Normal vector render helpers ----

fill_normals_vert_ubo :: (world_from_model : Matrix4, ns : Normal_Style) -> Normals_Vert_UBO {
    ubo : Normals_Vert_UBO;
    ubo.clip_from_view   = orthographic_projection_matrix(app.camera.left, app.camera.right, app.camera.top, app.camera.bottom, app.camera.near, app.camera.far, depth_range_01=true);
    ubo.view_from_world  = make_look_at_matrix(app.camera);
    ubo.world_from_model = world_from_model;
    ubo.normal_scale     = ns.scale;
    ubo.do_normalize     = cast(u32) ns.normalized;
    return ubo;
}

fill_normals_frag_ubo :: (ns : Normal_Style, clip_sphere : Clip_Sphere, clip_ranges : [3]Clip_Range) -> Normals_Frag_UBO {
    ubo : Normals_Frag_UBO;
    ubo.color       = .[ns.color.x, ns.color.y, ns.color.z, ns.color.w];
    ubo.clip_sphere = .[clip_sphere.center.x, clip_sphere.center.y, clip_sphere.center.z, clip_sphere.radius];
    ubo.clip_flags  = .[cast(u32) clip_sphere.is_active, 0, 0, 0];
    for i : 0..2 {
        r := clip_ranges[i];
        ubo.range_normal[i]  = .[r.normal.x, r.normal.y, r.normal.z, 0];
        ubo.range_min_max[i] = .[r.min, r.max, cast(float) cast(u32) r.is_active, 0];
    }
    return ubo;
}

bind_normals_buffers :: (pass : *SDL_GPURenderPass, buf : *SDL_GPUBuffer, NP : u32) {
    bindings := SDL_GPUBufferBinding.[
        .{buffer=buf, offset=0},   // slot 0: base positions
        .{buffer=buf, offset=NP},  // slot 1: normals
    ];
    SDL_BindGPUVertexBuffers(pass, 0, bindings.data, 2);
}

sdlgpu_render_mesh_triangle_normals :: (entity : *Entity, pass : *SDL_GPURenderPass, cmd : *SDL_GPUCommandBuffer) {
    using entity.display_info;
    if !entity.mesh.triangles.count return;
    if !triangle_style.normal_style.visible return;
    if !entity.render_info_gpu.tri_normals_buf return;

    NV := entity.render_info_gpu.tri_normals_NV;
    NP := NV * cast(u32) size_of(Vector3);
    vert_ubo := fill_normals_vert_ubo(entity.mesh.world_from_model, triangle_style.normal_style);
    frag_ubo := fill_normals_frag_ubo(triangle_style.normal_style, clip_sphere, clip_ranges);

    SDL_BindGPUGraphicsPipeline(pass, g_sdlgpu.pso_normals);
    bind_normals_buffers(pass, entity.render_info_gpu.tri_normals_buf, NP);
    SDL_PushGPUVertexUniformData(cmd, 0, *vert_ubo, size_of(Normals_Vert_UBO));
    SDL_PushGPUFragmentUniformData(cmd, 0, *frag_ubo, size_of(Normals_Frag_UBO));
    SDL_DrawGPUPrimitives(pass, NV, 1, 0, 0);
}

sdlgpu_render_mesh_segment_normals :: (entity : *Entity, pass : *SDL_GPURenderPass, cmd : *SDL_GPUCommandBuffer) {
    using entity.display_info;
    if !entity.mesh.segments.count return;
    if !segment_style.normal_style.visible return;
    if !entity.render_info_gpu.seg_normals_buf return;

    NV := entity.render_info_gpu.seg_normals_NV;
    NP := NV * cast(u32) size_of(Vector3);
    vert_ubo := fill_normals_vert_ubo(entity.mesh.world_from_model, segment_style.normal_style);
    frag_ubo := fill_normals_frag_ubo(segment_style.normal_style, clip_sphere, clip_ranges);

    SDL_BindGPUGraphicsPipeline(pass, g_sdlgpu.pso_normals);
    bind_normals_buffers(pass, entity.render_info_gpu.seg_normals_buf, NP);
    SDL_PushGPUVertexUniformData(cmd, 0, *vert_ubo, size_of(Normals_Vert_UBO));
    SDL_PushGPUFragmentUniformData(cmd, 0, *frag_ubo, size_of(Normals_Frag_UBO));
    SDL_DrawGPUPrimitives(pass, NV, 1, 0, 0);
}

sdlgpu_render_mesh_point_normals :: (entity : *Entity, pass : *SDL_GPURenderPass, cmd : *SDL_GPUCommandBuffer) {
    using entity.display_info;
    if !entity.mesh.points.count return;
    if !point_style.normal_style.visible return;
    if !entity.render_info_gpu.pt_normals_buf return;

    NV := entity.render_info_gpu.pt_normals_NV;
    NP := NV * cast(u32) size_of(Vector3);
    vert_ubo := fill_normals_vert_ubo(entity.mesh.world_from_model, point_style.normal_style);
    frag_ubo := fill_normals_frag_ubo(point_style.normal_style, clip_sphere, clip_ranges);

    SDL_BindGPUGraphicsPipeline(pass, g_sdlgpu.pso_normals);
    bind_normals_buffers(pass, entity.render_info_gpu.pt_normals_buf, NP);
    SDL_PushGPUVertexUniformData(cmd, 0, *vert_ubo, size_of(Normals_Vert_UBO));
    SDL_PushGPUFragmentUniformData(cmd, 0, *frag_ubo, size_of(Normals_Frag_UBO));
    SDL_DrawGPUPrimitives(pass, NV, 1, 0, 0);
}

// ---- AABB render ----

sdlgpu_render_aabb :: (aabb_model : AxisBox3, world_from_model : Matrix4, pass : *SDL_GPURenderPass, cmd : *SDL_GPUCommandBuffer) {
    ubo : AABB_UBO;
    ubo.clip_from_view   = orthographic_projection_matrix(app.camera.left, app.camera.right, app.camera.top, app.camera.bottom, app.camera.near, app.camera.far, depth_range_01=true);
    ubo.view_from_world  = make_look_at_matrix(app.camera);
    ubo.world_from_model = world_from_model;
    ubo.aabb_min = .[aabb_model.min_point.x, aabb_model.min_point.y, aabb_model.min_point.z, 0];
    ubo.aabb_max = .[aabb_model.max_point.x, aabb_model.max_point.y, aabb_model.max_point.z, 0];
    ubo.color    = .[BLUE.x, BLUE.y, BLUE.z, BLUE.w];

    SDL_BindGPUGraphicsPipeline(pass, g_sdlgpu.pso_aabb);
    SDL_PushGPUVertexUniformData(cmd, 0, *ubo, size_of(AABB_UBO));
    SDL_DrawGPUPrimitives(pass, 24, 1, 0, 0);
}

// ---- Background render ----

sdlgpu_render_background :: (pass : *SDL_GPURenderPass, cmd : *SDL_GPUCommandBuffer) {
    if app.background_style == .SOLID_COLOR {
        // Solid colour is handled by the render-pass clear colour — nothing extra to draw.
        return;
    }

    iTime := cast(float) SDL_GetTicks() / 1000.0;
    ubo := Background_UBO.{ resolution_time = .[
        cast(float) app.window_size.width,
        cast(float) app.window_size.height,
        1.0,
        iTime,
    ]};

    SDL_BindGPUGraphicsPipeline(pass, g_sdlgpu.pso_background);
    SDL_PushGPUFragmentUniformData(cmd, 0, *ubo, size_of(Background_UBO));
    SDL_DrawGPUPrimitives(pass, 3, 1, 0, 0);
}

// ---- Axes triad render ----

render_axes_triad_gpu :: (pass : *SDL_GPURenderPass, cmd : *SDL_GPUCommandBuffer) {
    if !app.triad.visible return;

    old_camera := app.camera;
    defer app.camera = old_camera;

    using *app.camera;
    w := cast(float) app.window_size.width;
    h := cast(float) app.window_size.height;
    s : float = 80.;

    near, far   = -s, s;
    bottom, top = 0., h;
    left, right = 0., w;
    unit_look := normalize(current_look_direction());
    look_position = Vector3.{};
    eye_position  = look_position - unit_look;

    offset_vs := Vector3.{s, s, 0.} + Vector3.{w - 2*s - WINDOW_BORDER_UI_OFFSET.x, WINDOW_BORDER_UI_OFFSET.y, 0};
    valid, world_from_view := inverse(make_look_at_matrix(app.camera));
    if !valid vlog_warning("render_axes_triad_gpu: could not invert look-at matrix");
    offset_ws := (world_from_view * Vector4.{xyz=offset_vs}).xyz;

    scale := make_scale_matrix4(.8 * Vector3.{s, s, s});
    shift := make_translation_matrix4(offset_ws);
    xform := shift * scale;

    app.triad.origin.mesh.world_from_model = xform;
    app.triad.x_axis.mesh.world_from_model = xform;
    app.triad.y_axis.mesh.world_from_model = xform;
    app.triad.z_axis.mesh.world_from_model = xform;

    sdlgpu_render_mesh_triangles(*app.triad.origin, pass, cmd);
    sdlgpu_render_mesh_triangles(*app.triad.x_axis, pass, cmd);
    sdlgpu_render_mesh_triangles(*app.triad.y_axis, pass, cmd);
    sdlgpu_render_mesh_triangles(*app.triad.z_axis, pass, cmd);
}

// ---- Top-level render calls ----
// Split into two phases: upload (copy passes, before render pass) and draw (inside render pass).

// Phase A: upload all dirty entity buffers via copy passes.
// Must be called BEFORE SDL_BeginGPURenderPass.
upload_entity_buffers_gpu :: (cmd : *SDL_GPUCommandBuffer) {
    for app.entities {
        maybe_update_render_info_gpu(*it.render_info_gpu, *it.render_info, *it.mesh, cmd);
    }
    // Selection entity
    {
        e := *app.select_tool.entity;
        maybe_update_render_info_gpu(*e.render_info_gpu, *e.render_info, *e.mesh, cmd);
    }
    // Axes triad entities (not in app.entities)
    if app.triad.visible {
        maybe_update_render_info_gpu(*app.triad.origin.render_info_gpu, *app.triad.origin.render_info, *app.triad.origin.mesh, cmd);
        maybe_update_render_info_gpu(*app.triad.x_axis.render_info_gpu, *app.triad.x_axis.render_info, *app.triad.x_axis.mesh, cmd);
        maybe_update_render_info_gpu(*app.triad.y_axis.render_info_gpu, *app.triad.y_axis.render_info, *app.triad.y_axis.mesh, cmd);
        maybe_update_render_info_gpu(*app.triad.z_axis.render_info_gpu, *app.triad.z_axis.render_info, *app.triad.z_axis.mesh, cmd);
    }
}

// ---- Thick-line and sized-point render helpers (Phase 5) ----

fill_sized_prim_vert_ubo :: (world_from_model : Matrix4, size_px : float) -> Sized_Prim_Vert_UBO {
    ubo : Sized_Prim_Vert_UBO;
    ubo.clip_from_view   = orthographic_projection_matrix(app.camera.left, app.camera.right, app.camera.top, app.camera.bottom, app.camera.near, app.camera.far, depth_range_01=true);
    ubo.view_from_world  = make_look_at_matrix(app.camera);
    ubo.world_from_model = world_from_model;
    ubo.prim_size_px     = size_px;
    ubo.viewport_w       = cast(float) app.window_size.width;
    ubo.viewport_h       = cast(float) app.window_size.height;
    return ubo;
}

sdlgpu_render_mesh_segments_thick :: (entity : *Entity, pass : *SDL_GPURenderPass, cmd : *SDL_GPUCommandBuffer) {
    using entity.display_info;
    if !entity.mesh.segments.count return;
    if !segment_style.visible && !clip_radius_mode return;
    if !entity.render_info_gpu.segments_buf return;

    wave         := ifx flash_wave_dt == 0 then -1. else cos(5 * flash_wave_dt);
    used_clip    := ifx clip_radius_mode then Clip_Mode.BLACKEN else Clip_Mode.HIDDEN;
    seg_count    := entity.mesh.segments.count;
    NVS          := entity.render_info_gpu.segments_NVS;           // = 2 * seg_count
    NP_bytes     := NVS * cast(u32) size_of(Vector3);              // byte size of positions half
    width        := ifx clip_radius_mode then 1. else segment_style.width;

    vert_ubo := fill_sized_prim_vert_ubo(entity.mesh.world_from_model, width);
    clip_ubo := fill_clip_ubo(entity.display_info);
    style    := fill_pl_style_ubo(segment_style.color, segment_style.color_mode, used_clip, wave);

    bindings := SDL_GPUBufferBinding.[
        .{buffer=g_sdlgpu.unit_quad_line_buf,           offset=0},        // slot 0: (t,side)
        .{buffer=entity.render_info_gpu.segments_buf,   offset=0},        // slot 1: positions A+B (stride=24)
        .{buffer=entity.render_info_gpu.segments_buf,   offset=NP_bytes}, // slot 2: colors A+B (stride=24)
    ];
    SDL_BindGPUGraphicsPipeline(pass, g_sdlgpu.pso_thick_lines);
    SDL_BindGPUVertexBuffers(pass, 0, bindings.data, 3);
    SDL_PushGPUVertexUniformData(cmd, 0, *vert_ubo, size_of(Sized_Prim_Vert_UBO));
    SDL_PushGPUFragmentUniformData(cmd, 0, *clip_ubo, size_of(Clip_UBO));
    SDL_PushGPUFragmentUniformData(cmd, 1, *style,    size_of(PL_Style_UBO));
    SDL_DrawGPUPrimitives(pass, 6, cast(u32) seg_count, 0, 0);
}

sdlgpu_render_mesh_points_sized :: (entity : *Entity, pass : *SDL_GPURenderPass, cmd : *SDL_GPUCommandBuffer) {
    using entity.display_info;
    if !entity.mesh.points.count return;
    if !point_style.visible && !clip_radius_mode_show_wireframe return;
    if !entity.render_info_gpu.points_buf return;

    wave         := ifx flash_wave_dt == 0 then -1. else cos(5 * flash_wave_dt);
    used_clip    := ifx clip_radius_mode then Clip_Mode.BLACKEN else Clip_Mode.HIDDEN;
    pt_count     := entity.mesh.points.count;
    NP_bytes     := entity.render_info_gpu.points_NVP * cast(u32) size_of(Vector3);
    size_px      := cast(float) (ifx clip_radius_mode_show_wireframe then 2 else point_style.vertex_style.size);

    vert_ubo := fill_sized_prim_vert_ubo(entity.mesh.world_from_model, size_px);
    clip_ubo := fill_clip_ubo(entity.display_info);
    style    := fill_pl_style_ubo(point_style.vertex_style.color, point_style.vertex_style.color_mode, used_clip, wave);

    bindings := SDL_GPUBufferBinding.[
        .{buffer=g_sdlgpu.unit_quad_pt_buf,           offset=0},        // slot 0: corner (x,y)
        .{buffer=entity.render_info_gpu.points_buf,   offset=0},        // slot 1: centers
        .{buffer=entity.render_info_gpu.points_buf,   offset=NP_bytes}, // slot 2: colors
    ];
    SDL_BindGPUGraphicsPipeline(pass, g_sdlgpu.pso_sized_points);
    SDL_BindGPUVertexBuffers(pass, 0, bindings.data, 3);
    SDL_PushGPUVertexUniformData(cmd, 0, *vert_ubo, size_of(Sized_Prim_Vert_UBO));
    SDL_PushGPUFragmentUniformData(cmd, 0, *clip_ubo, size_of(Clip_UBO));
    SDL_PushGPUFragmentUniformData(cmd, 1, *style,    size_of(PL_Style_UBO));
    SDL_DrawGPUPrimitives(pass, 6, cast(u32) pt_count, 0, 0);
}

sdlgpu_render_mesh_positions_sized :: (entity : *Entity, pass : *SDL_GPURenderPass, cmd : *SDL_GPUCommandBuffer) {
    using entity.display_info;
    if !entity.mesh.positions.count return;
    if !vertex_style.visible && !clip_radius_mode_show_wireframe return;
    if !entity.render_info_gpu.positions_buf return;

    wave         := ifx flash_wave_dt == 0 then -1. else cos(5 * flash_wave_dt);
    used_clip    := ifx clip_radius_mode then Clip_Mode.BLACKEN else Clip_Mode.HIDDEN;
    pos_count    := entity.mesh.positions.count;
    NP_bytes     := entity.render_info_gpu.positions_NVV * cast(u32) size_of(Vector3);
    size_px      := cast(float) (ifx clip_radius_mode_show_wireframe then 2 else vertex_style.size);

    vert_ubo := fill_sized_prim_vert_ubo(entity.mesh.world_from_model, size_px);
    clip_ubo := fill_clip_ubo(entity.display_info);
    style    := fill_pl_style_ubo(vertex_style.color, vertex_style.color_mode, used_clip, wave);

    bindings := SDL_GPUBufferBinding.[
        .{buffer=g_sdlgpu.unit_quad_pt_buf,             offset=0},
        .{buffer=entity.render_info_gpu.positions_buf,  offset=0},
        .{buffer=entity.render_info_gpu.positions_buf,  offset=NP_bytes},
    ];
    SDL_BindGPUGraphicsPipeline(pass, g_sdlgpu.pso_sized_points);
    SDL_BindGPUVertexBuffers(pass, 0, bindings.data, 3);
    SDL_PushGPUVertexUniformData(cmd, 0, *vert_ubo, size_of(Sized_Prim_Vert_UBO));
    SDL_PushGPUFragmentUniformData(cmd, 0, *clip_ubo, size_of(Clip_UBO));
    SDL_PushGPUFragmentUniformData(cmd, 1, *style,    size_of(PL_Style_UBO));
    SDL_DrawGPUPrimitives(pass, 6, cast(u32) pos_count, 0, 0);
}

// Phase B: draw calls inside a render pass.  No copy passes here.
sdlgpu_draw_entity :: (entity : *Entity, entity_index : int, pass : *SDL_GPURenderPass, cmd : *SDL_GPUCommandBuffer) {
    entity.display_info.clip_radius_mode                = entity_in_clip_radius_mode(entity_index);
    entity.display_info.clip_radius_mode_show_wireframe = mouse_set_clip_radius() && array_find(app.clipping_sphere_mode_last_entity_index_set, entity_index);

    sdlgpu_render_mesh_triangles       (entity, pass, cmd);
    sdlgpu_render_mesh_triangle_normals(entity, pass, cmd);
    sdlgpu_render_mesh_segments_thick  (entity, pass, cmd); // Phase 5: thick via quads
    sdlgpu_render_mesh_segment_normals (entity, pass, cmd);
    sdlgpu_render_mesh_points_sized    (entity, pass, cmd); // Phase 5: sized via quads
    sdlgpu_render_mesh_point_normals   (entity, pass, cmd);
    sdlgpu_render_mesh_positions_sized (entity, pass, cmd); // Phase 5: sized via quads
    if entity.display_info.aabb_visible {
        sdlgpu_render_aabb(entity.render_info.bounding_aabb, entity.mesh.world_from_model, pass, cmd);
    }
}

render_entities_gpu :: (pass : *SDL_GPURenderPass, cmd : *SDL_GPUCommandBuffer) {
    for :VisibleOpaque      app.entities  sdlgpu_draw_entity(it, it_index, pass, cmd);
    for :VisibleTransparent app.entities  sdlgpu_draw_entity(it, it_index, pass, cmd);
    if app.template_display_info.aabb_visible {
        sdlgpu_render_aabb(app.template_aabb_world, Matrix4_Identity, pass, cmd);
    }
    for :VisibleHovered     app.entities  sdlgpu_draw_entity(it, it_index, pass, cmd);
}

render_selections_gpu :: (pass : *SDL_GPURenderPass, cmd : *SDL_GPUCommandBuffer) {
    entity := *app.select_tool.entity;
    if !entity.display_info.is_visible return;

    entity.display_info.clip_radius_mode                = false;
    entity.display_info.clip_radius_mode_show_wireframe = false;

    sdlgpu_render_mesh_positions_sized (entity, pass, cmd);
    sdlgpu_render_mesh_points_sized    (entity, pass, cmd);
    sdlgpu_render_mesh_point_normals   (entity, pass, cmd);
    sdlgpu_render_mesh_segments_thick  (entity, pass, cmd);
    sdlgpu_render_mesh_segment_normals (entity, pass, cmd);
    sdlgpu_render_mesh_triangles       (entity, pass, cmd);
    sdlgpu_render_mesh_triangle_normals(entity, pass, cmd);
}
