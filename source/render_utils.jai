// _space is model or world but it could be whatever else
to_screen_position :: (point_space : Vector3, projection_from_space : Matrix4) -> Tuple2i {
    result : Tuple2i = ---;

    // [-1, 1]x[-1,1] -> [0, window_size.width]x[0, window_size.height]
    transformed : Vector3 = transform_point(projection_from_space, point_space);
    result.x = xx (app.window_size.width *  (transformed.x + 1) / 2);
    result.y = xx (app.window_size.height * (transformed.y + 1) / 2);

    return result;
}


init_shaders :: () {
    {
        VERT, VERT_OK :: #run read_entire_file("source/shaders/points_lines.vert"); #assert(VERT_OK);
        FRAG, FRAG_OK :: #run read_entire_file("source/shaders/points_lines.frag"); #assert(FRAG_OK);
        app.points_lines_program = get_shader_program(VERT, FRAG);
    }

    {
        VERT, VERT_OK :: #run read_entire_file("source/shaders/triangles.vert"); #assert(VERT_OK);
        GEOM, GEOM_OK :: #run read_entire_file("source/shaders/triangles.geom"); #assert(GEOM_OK);
        FRAG, FRAG_OK :: #run read_entire_file("source/shaders/triangles.frag"); #assert(FRAG_OK);
        app.triangles_program = get_shader_program(VERT, FRAG, GEOM);
    }

    {
        VERT, VERT_OK :: #run read_entire_file("source/shaders/normals.vert"); #assert(VERT_OK);
        GEOM, GEOM_OK :: #run read_entire_file("source/shaders/normals_triangles.geom"); #assert(GEOM_OK);
        FRAG, FRAG_OK :: #run read_entire_file("source/shaders/normals.frag"); #assert(FRAG_OK);
        app.triangles_normal_program = get_shader_program(VERT, FRAG, GEOM);
    }

    {
        VERT, VERT_OK :: #run read_entire_file("source/shaders/normals.vert"); #assert(VERT_OK);
        GEOM, GEOM_OK :: #run read_entire_file("source/shaders/normals_segments.geom"); #assert(GEOM_OK);
        FRAG, FRAG_OK :: #run read_entire_file("source/shaders/normals.frag"); #assert(FRAG_OK);
        app.segments_normal_program = get_shader_program(VERT, FRAG, GEOM);
    }

    {
        VERT, VERT_OK :: #run read_entire_file("source/shaders/normals.vert"); #assert(VERT_OK);
        GEOM, GEOM_OK :: #run read_entire_file("source/shaders/normals_points.geom"); #assert(GEOM_OK);
        FRAG, FRAG_OK :: #run read_entire_file("source/shaders/normals.frag"); #assert(FRAG_OK);
        app.points_normal_program = get_shader_program(VERT, FRAG, GEOM);
    }

    {
        VERT, VERT_OK :: #run read_entire_file("source/shaders/aabb.vert"); #assert(VERT_OK);
        FRAG, FRAG_OK :: #run read_entire_file("source/shaders/aabb.frag"); #assert(FRAG_OK);
        app.aabb_program = get_shader_program(VERT, FRAG);
    }

    {
        // We may want to hot-load this file in future to allow the user to customize the background
        VERT, VERT_OK :: #run read_entire_file("source/shaders/background.vert"); #assert(VERT_OK);
        FRAG, FRAG_OK :: #run read_entire_file("source/shaders/background.frag"); #assert(FRAG_OK);
        app.background_program = get_shader_program(VERT, FRAG);
        glGenVertexArrays(1, *app.background_vao);
    }
}

get_shader_program :: (shader_vertex : string, shader_fragment : string, shader_geometry : string = "") -> GLuint {

    make_shader_object :: (shader : string, shader_type : GLenum) -> GLuint {
        shader_object := glCreateShader(shader_type);

        //shader_str := temp_c_string(shader);
		length : GLint = xx shader.count;
        glShaderSource(shader_object, 1, *shader.data, *length);

        glCompileShader(shader_object);

        success : GLint;
        glGetShaderiv(shader_object, GL_COMPILE_STATUS, *success);

        if !success then {
            log : [512] u8;
            glGetShaderInfoLog(shader_object, 512, null, log.data);
            print("[Shader] %\n", to_string(log.data));
            exit(1); // Hard-exit for now.
        }

        return shader_object;
    }

    program := glCreateProgram();

    shader_v := make_shader_object(shader_vertex, GL_VERTEX_SHADER);
    glAttachShader(program, shader_v);

    shader_g : GLuint;
    if shader_geometry.count {
        shader_g = make_shader_object(shader_geometry, GL_GEOMETRY_SHADER);
        glAttachShader(program, shader_g);
    }

    shader_f := make_shader_object(shader_fragment, GL_FRAGMENT_SHADER);
    glAttachShader(program, shader_f);

    glLinkProgram(program);

    success : GLint = 0;
    glGetProgramiv(program, GL_LINK_STATUS, *success);

    if !success then {
        BUFFER_SIZE_LOG :: 512;
        log : [BUFFER_SIZE_LOG] u8;
        glGetProgramInfoLog(program, BUFFER_SIZE_LOG, null, log.data);
        print("[Shader] %\n", to_string(log.data));
        exit(1); // Hard-exit for now.
    }

    glDeleteShader(shader_v);
    glDeleteShader(shader_f);
    if shader_geometry.count {
        glDeleteShader(shader_g);
    }

    return program;
}

// This function was added so that we could use Simp *when it was using the same context as the rest of the
// application*, we don't do this anymore so it's not really needed but rather than moving it from the call
// sites where it was needed I just commented the implementation. Anyway, the reason it was needed is because
// of the way Simp.immediate_set_shader works (when called from Simp.set_shader_for_color, tracking the state
// of the currently set shader separately to opengl) we can break it by getting opengl out of sync.  This
// happens when we set the shader program in gl, without simp/ knowing about it, so it doesn't know it needs
// to set the shader program again. Here, just to be safe/general, we set a bunch of other opengl state, too.
ScopeGlState :: () #expand {
    /*
    // Backup GL state
    last_active_texture : GLenum; glGetIntegerv(GL_ACTIVE_TEXTURE, xx *last_active_texture);
    glActiveTexture(GL_TEXTURE0);
    last_program : GLuint; glGetIntegerv(GL_CURRENT_PROGRAM, xx *last_program);
    last_texture : GLuint; glGetIntegerv(GL_TEXTURE_BINDING_2D, xx *last_texture);
    last_array_buffer : GLuint; glGetIntegerv(GL_ARRAY_BUFFER_BINDING, xx *last_array_buffer);
    last_vertex_array_object : GLuint; glGetIntegerv(GL_VERTEX_ARRAY_BINDING, xx *last_vertex_array_object);
    last_viewport : [4]GLint; glGetIntegerv(GL_VIEWPORT, last_viewport.data);
    last_scissor_box : [4]GLint; glGetIntegerv(GL_SCISSOR_BOX, last_scissor_box.data);
    last_blend_src_rgb : GLenum; glGetIntegerv(GL_BLEND_SRC_RGB, xx *last_blend_src_rgb);
    last_blend_dst_rgb : GLenum; glGetIntegerv(GL_BLEND_DST_RGB, xx *last_blend_dst_rgb);
    last_blend_src_alpha : GLenum; glGetIntegerv(GL_BLEND_SRC_ALPHA, xx *last_blend_src_alpha);
    last_blend_dst_alpha : GLenum; glGetIntegerv(GL_BLEND_DST_ALPHA, xx *last_blend_dst_alpha);
    last_blend_equation_rgb : GLenum; glGetIntegerv(GL_BLEND_EQUATION_RGB, xx *last_blend_equation_rgb);
    last_blend_equation_alpha : GLenum; glGetIntegerv(GL_BLEND_EQUATION_ALPHA, xx *last_blend_equation_alpha);
    last_enable_blend := glIsEnabled(GL_BLEND);
    last_enable_cull_face := glIsEnabled(GL_CULL_FACE);
    last_enable_depth_test := glIsEnabled(GL_DEPTH_TEST);
    last_enable_stencil_test := glIsEnabled(GL_STENCIL_TEST);
    last_enable_scissor_test := glIsEnabled(GL_SCISSOR_TEST);

    // @Incomplete Get and set relevant/all float variables too e.g., :
    last_line_width : GLfloat; glGetFloatv(GL_LINE_WIDTH, xx *last_line_width);

    `defer {
        // Restore modified GL state
        glUseProgram(last_program);
        glBindTexture(GL_TEXTURE_2D, last_texture);
        glActiveTexture(last_active_texture);
        glBindVertexArray(last_vertex_array_object);
        glBindBuffer(GL_ARRAY_BUFFER, last_array_buffer);
        glBlendEquationSeparate(last_blend_equation_rgb, last_blend_equation_alpha);
        glBlendFuncSeparate(last_blend_src_rgb, last_blend_dst_rgb, last_blend_src_alpha, last_blend_dst_alpha);
        if (last_enable_blend)        glEnable(GL_BLEND);        else glDisable(GL_BLEND);
        if (last_enable_cull_face)    glEnable(GL_CULL_FACE);    else glDisable(GL_CULL_FACE);
        if (last_enable_depth_test)   glEnable(GL_DEPTH_TEST);   else glDisable(GL_DEPTH_TEST);
        if (last_enable_stencil_test) glEnable(GL_STENCIL_TEST); else glDisable(GL_STENCIL_TEST);
        if (last_enable_scissor_test) glEnable(GL_SCISSOR_TEST); else glDisable(GL_SCISSOR_TEST);
        glViewport(last_viewport[0], last_viewport[1], xx last_viewport[2], xx last_viewport[3]);
        glScissor(last_scissor_box[0], last_scissor_box[1], xx last_scissor_box[2], xx last_scissor_box[3]);
    }
    */
}

debug_text_at_cursor :: (text : string, color : Vector4 = .{0, 0, 0, 1}, font : *ImGui.ImFont = null) {

    if !ImGui.IsAnyMouseDown() return;

    if font {
        ImGui.PushFont(font);
    }

    // window_position := Vector2.{io().MousePos.x, app.window_size.height - io().MousePos.y};
    window_position := io().MousePos;
    window_size := ImGui.CalcTextSize(text);

    LabelWindow2 :: (window_position : Vector2, window_size : Vector2) #expand {
        label_window_flags :: ImGui.WindowFlags.NoTitleBar|.NoResize|.NoMove|.NoScrollbar|.NoSavedSettings|.NoInputs|.NoMouseInputs|.NoBackground;

        window_position_index := cast(int)(window_position.x + app.window_size.width * window_position.y);

        // @Hack :LabelWindowSize The factor of 2 multiplying the window_size is a bit too much, but this
        // should probably be SetNextWindowContentSize anyway but using that adds a frame delay causing
        // horrible flickering. We need to figure fix this factor of 2 in order to be able to frame the
        // labels with a box about the right size
        ImGui.SetNextWindowSize(.{65, 50});
        ImGui.SetNextWindowPos(window_position - .{-3, window_size.y} + app.settings.labelling_offset); // Center the label by shifting up by window_size.y
        ImGui.SetNextWindowBgAlpha(0.);
        old_window_border_size := ImGui.GetStyle().WindowBorderSize;
        // ImGui.GetStyle().WindowBorderSize = 0;
        // `defer ImGui.GetStyle().WindowBorderSize = old_window_border_size;

        ImGui.Begin(imgui_label("Labels", xx window_position_index), flags=label_window_flags);
        `defer ImGui.End();
    }

    LabelWindow2(window_position, window_size);

    ImGui.TextColored(color, "%", text);

    if font {
        ImGui.PopFont();
    }
}

debug_print_active_uniforms :: (program : GLuint, loc := #caller_location) {

    max_length: GLint;
    glGetProgramiv(program, GL_ACTIVE_UNIFORM_MAX_LENGTH, *max_length);
    name := alloc_string(max_length);
    defer free(name);
    // print("GL_ACTIVE_UNIFORM_MAX_LENGTH = %\n", max_length);

    count : s32;
    glGetProgramiv(program, GL_ACTIVE_UNIFORMS, *count);
    print("[debug %:%] Program % has % active uniforms:\n", loc.fully_pathed_filename, loc.line_number, program, count);
    for 0..count-1 {
        size: GLint;
        type: GLenum;
        length: GLsizei;

        glGetActiveUniform(program, cast(GLuint) it, xx max_length, *length, *size, *type, name.data);
        name.count = xx length;
        print("Uniform #% Type: 0x% Size: % Name: %\n", it, formatInt(type, base=16), size, name);
    }
}

print_errors :: (loc := #caller_location) {
    DumpGLErrors("context %", #location());

    {
        error := glGetError();
        if (error != GL_NO_ERROR) {
            print("error:%:%,%: code % (%)\n", loc.fully_pathed_filename, loc.line_number, loc.character_number, error, formatInt(error, base=16));
            print("stack trace\n");
            for pack_stack_trace() {
                print_stack_trace(*it);
            }
            exit(-1);
        }
    }
}