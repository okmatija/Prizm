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

//
// ---- Pipeline inventory ----
//

SDLGPU_Render_State :: struct {
    pso_triangles      : *SDL_GPUGraphicsPipeline; // FILL, depth on/write on, alpha blend
    pso_triangles_line : *SDL_GPUGraphicsPipeline; // LINE fill, depth on, no blend (degenerate tri edges)
    pso_lines          : *SDL_GPUGraphicsPipeline; // LINELIST, depth on, alpha blend
    pso_points         : *SDL_GPUGraphicsPipeline; // POINTLIST, depth on, alpha blend
}

g_sdlgpu : SDLGPU_Render_State;

// Compiled SPIR-V (embedded at build time)
SDLGPU_VERT_TRI,  _V1 :: #run read_entire_file(".build/shaders/sdlgpu_triangles.vert.spv");     #assert(_V1);
SDLGPU_FRAG_TRI,  _V2 :: #run read_entire_file(".build/shaders/sdlgpu_triangles.frag.spv");     #assert(_V2);
SDLGPU_VERT_PL,   _V3 :: #run read_entire_file(".build/shaders/sdlgpu_points_lines.vert.spv");  #assert(_V3);
SDLGPU_FRAG_PL,   _V4 :: #run read_entire_file(".build/shaders/sdlgpu_points_lines.frag.spv");  #assert(_V4);

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
}

deinit_rendering_gpu :: () {
    gpu := app.gpu_device;
    if g_sdlgpu.pso_triangles       SDL_ReleaseGPUGraphicsPipeline(gpu, g_sdlgpu.pso_triangles);
    if g_sdlgpu.pso_triangles_line  SDL_ReleaseGPUGraphicsPipeline(gpu, g_sdlgpu.pso_triangles_line);
    if g_sdlgpu.pso_lines           SDL_ReleaseGPUGraphicsPipeline(gpu, g_sdlgpu.pso_lines);
    if g_sdlgpu.pso_points          SDL_ReleaseGPUGraphicsPipeline(gpu, g_sdlgpu.pso_points);
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
}

// Phase B: draw calls inside a render pass.  No copy passes here.
sdlgpu_draw_entity :: (entity : *Entity, entity_index : int, pass : *SDL_GPURenderPass, cmd : *SDL_GPUCommandBuffer) {
    entity.display_info.clip_radius_mode                = entity_in_clip_radius_mode(entity_index);
    entity.display_info.clip_radius_mode_show_wireframe = mouse_set_clip_radius() && array_find(app.clipping_sphere_mode_last_entity_index_set, entity_index);

    sdlgpu_render_mesh_triangles(entity, pass, cmd);
    sdlgpu_render_mesh_segments (entity, pass, cmd);
    sdlgpu_render_mesh_points   (entity, pass, cmd);
    sdlgpu_render_mesh_positions(entity, pass, cmd);
    // Normals and AABB: Phase 4
}

render_entities_gpu :: (pass : *SDL_GPURenderPass, cmd : *SDL_GPUCommandBuffer) {
    for :VisibleOpaque      app.entities  sdlgpu_draw_entity(it, it_index, pass, cmd);
    for :VisibleTransparent app.entities  sdlgpu_draw_entity(it, it_index, pass, cmd);
    for :VisibleHovered     app.entities  sdlgpu_draw_entity(it, it_index, pass, cmd);
}

render_selections_gpu :: (pass : *SDL_GPURenderPass, cmd : *SDL_GPUCommandBuffer) {
    entity := *app.select_tool.entity;
    if !entity.display_info.is_visible return;

    entity.display_info.clip_radius_mode                = false;
    entity.display_info.clip_radius_mode_show_wireframe = false;

    sdlgpu_render_mesh_positions(entity, pass, cmd);
    sdlgpu_render_mesh_points   (entity, pass, cmd);
    sdlgpu_render_mesh_segments (entity, pass, cmd);
    sdlgpu_render_mesh_triangles(entity, pass, cmd);
}
