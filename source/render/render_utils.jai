// _space is model or world but it could be whatever else
to_screen_position :: (point_space : Vector3, projection_from_space : Matrix4) -> Tuple2i {
    result : Tuple2i = ---;

    // [-1, 1]x[-1,1] -> [0, window_size.width]x[0, window_size.height]
    transformed : Vector3 = transform_point(projection_from_space, point_space);
    result.x = xx (app.window_size.width *  (transformed.x + 1) / 2);
    result.y = xx (app.window_size.height * (transformed.y + 1) / 2);

    return result;
}


resize_textures :: () {
    w, h : u32 = cast(u32)app.window_size.width, cast(u32)app.window_size.height;

    {
        // texture_init(app.gbuffer_position_texture, w, h);
        // texture_init(app.gbuffer_normal_texture, w, h);

        // // position color buffer
        // glBindTexture(GL_TEXTURE_2D, app.gbuffer_position_texture);
        // glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA16F, w, h, 0, GL_RGBA, GL_FLOAT, null); // @Cleanup 32F? also, with 16 is should be GL_HALF_FLOAT
        // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        // glBindTexture(GL_TEXTURE_2D, 0);

        // // normal color buffer
        // glBindTexture(GL_TEXTURE_2D, app.gbuffer_normal_texture);
        // glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA16F, w, h, 0, GL_RGBA, GL_FLOAT, null); // @Cleanup 32F? also, with 16 is should be GL_HALF_FLOAT
        // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        // //glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_2D, app.gbuffer_normal_texture, 0);
        // glBindTexture(GL_TEXTURE_2D, 0);

        // @Cleanup Add depth buffer/texture here!
    }

    /*
    {
    glBindTexture(GL_TEXTURE_2D, app.ssao_color_texture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
    glBindTexture(GL_TEXTURE_2D, 0);

    // @Think See this depth peeling implementation here:
    // https://github.com/tsherif/webgl2examples/blob/da1153a15ebc09bb13498e5f732ef2036507740c/oit-dual-depth-peeling.html#L400-L408
    glBindTexture(GL_TEXTURE_2D, app.ssao_blur_texture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT, w, h, 0, GL_DEPTH_COMPONENT, GL_FLOAT, null);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);
    }
    */
}

init_rendering :: () {
    DebugScopeGLGroup("init_rendering");

    w, h : u32 = cast(u32)app.window_size.width, cast(u32)app.window_size.height;

    //
    // Init Framebuffers
    //

    init_geometry_pass();
    init_ssao_pass();
    init_ssao_blur_pass();
    init_lighting_pass();

    //
    // Init Shaders
    //

    // @Cleanup We read the same shader files multiple times which sucks.

    init_shader(*app.render_info.shader_geometry);
    init_shader(*app.render_info.shader_ssao);
    init_shader(*app.render_info.shader_ssao_blur);
    init_shader(*app.render_info.shader_lighting);

    init_shader(*app.render_info.shader_aabb);
    init_shader(*app.render_info.shader_background);

    init_shader(*app.render_info.shader_triangles);
    init_shader(*app.render_info.shader_points_lines);
    init_shader(*app.render_info.shader_triangle_normal_vectors);
    init_shader(*app.render_info.shader_segment_normal_vectors);
    init_shader(*app.render_info.shader_point_normal_vectors);

    glGenVertexArrays(1, *app.render_info.quad_vao);

    {
        VERT, VERT_OK :: #run read_entire_file("source/render/quad.vert"); #assert(VERT_OK);
        FRAG, FRAG_OK :: #run read_entire_file("source/render/debug_deferred.frag"); #assert(FRAG_OK);
        app.render_info.blit_program = get_shader_program(VERT, FRAG);
    }
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


/*
init_shader :: (shader : *$T/Shader, $vertex_shader_text : string, $fragment_shader_text : string, $geometry_shader_text : string) {
    shader.program = get_shader_program(vertex_shader_text, fragment_shader_text, geometry_shader_text);
    cache_uniform_locations(shader.program, "", *shader.uniforms, type_info(type_of(shader.uniforms)));
}

// :CacheUniformLocationsWithCodeNotReflection
// Perhaps its better for debugging/understandablity to rewrite this as code generation to make functions
// call glGetUniformLocation.  Also, this trades compile-time for easier debugging and I guess allows the
// option to manually overwrite functions
cache_uniform_locations :: (program : GLuint, name : string, data : *void, info : *Type_Info, flatten : bool = false) {

    if info.type == .INTEGER { // Base case

        info_integer := cast(*Type_Info_Integer)info;

        assert(info_integer.runtime_size == size_of(GLuint));

        loc : GLint = glGetUniformLocation(program, temp_c_string(name));
        if loc <  0 then log_error("Unknown parameter: '%'", name);
        if loc >= 0 then (cast(*GLuint)data).* = cast(GLuint)loc;

        // Useful for debugging
        //print_vars(loc, name, data);

    } else if info.type == .STRUCT { // Recursive case

        info_struct := cast(*Type_Info_Struct)info;

        // The UseNameAsPrefix note is useful when a application struct contains uniforms that are used different shader stages of the same program
        for member : info_struct.members {
            join := ifx flatten then "_" else ".";
            ext_name := ifx member.flags & .USING then "" else member.name;
            new_name := ifx name then tprint("%1%2%3", name, join, ext_name) else ext_name;
            cache_uniform_locations(program, new_name, data + member.offset_in_bytes, member.type, array_find(member.notes, "UseNameAsPrefix"));
        }

    } else if info.type == .ARRAY { // Recursive case

        info_array := cast(*Type_Info_Array)info;

        array_count, array_data := get_array_count_and_data(data, info_array);
        element_size := info_array.element_type.runtime_size;

        for 0..array_count-1 {
            new_name := tprint("%[%]", name, it);
            cache_uniform_locations(program, new_name, array_data + it * element_size, info_array.element_type);
        }
    }
}
*/




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

Blit_Channel :: enum {
    GBUFFER_BASE_COLOR :: 0;
    GBUFFER_NORMAL :: 1;
    GBUFFER_POSITION :: 2;
    SSAO_COLOR :: 3;
    SSAO_COLOR_BLURRED :: 4;
    DEFAULT_LIT :: 5;
}

blit_texture :: () {
    //glBindFramebuffer(GL_READ_FRAMEBUFFER, app.gbuffer_framebuffer);
    //glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0); // write to default framebuffer
    //// blit to default framebuffer. Note that this may or may not work as the internal formats of both the FBO and default framebuffer have to match.
    //// the internal formats are implementation defined. This works on all of my systems, but if it doesn't on yours you'll likely have to write to the 		
    //// depth buffer in another shader stage (or somehow see to match the default framebuffer's internal format with the FBO's internal format).
    //w, h := app.window_size.width, app.window_size.height;
    //glBlitFramebuffer(0, 0, w, h, 0, 0, w, h, GL_COLOR_BUFFER_BIT, GL_NEAREST);
    //glBindFramebuffer(GL_FRAMEBUFFER, 0);

    using app.render_info;

    glBindFramebuffer(GL_FRAMEBUFFER, 0); // back to default
    glClearColor(0., 0., 0., 1.); 
    glClear(GL_COLOR_BUFFER_BIT);

    glUseProgram(blit_program);  
    //assert(glIsProgram(blit_program) == GL_TRUE); // @Speed This call is very slow!

    glBindVertexArray(quad_vao);
    glDisable(GL_DEPTH_TEST);

    screen_texture_loc := glGetUniformLocation(blit_program, "screen_texture");
    if #complete blit_channel == {
    case .GBUFFER_BASE_COLOR;

        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, geometry_pass.base_color.gl_handle);
        glUniform1i(screen_texture_loc, 2);// Texture unit 2

    case .GBUFFER_NORMAL;

        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, geometry_pass.normal.gl_handle);
        glUniform1i(screen_texture_loc, 1);

    case .GBUFFER_POSITION;

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, geometry_pass.position.gl_handle);
        glUniform1i(screen_texture_loc, 0);

    case .SSAO_COLOR;

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, ssao_pass.ssao_color.gl_handle);
        glUniform1i(screen_texture_loc, 0);

    case .SSAO_COLOR_BLURRED;

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, ssao_blur_pass.ssao_blurred.gl_handle);
        glUniform1i(screen_texture_loc, 0);

    case .DEFAULT_LIT;

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, lighting_pass.lit.gl_handle);
        glUniform1i(screen_texture_loc, 0);

    }

    channel_loc := glGetUniformLocation(blit_program, "channel");
    glUniform1i(channel_loc, xx blit_channel);

    glDrawArrays(GL_TRIANGLES, 0, 6);  
}


// Wrapper around the different ways to label objects.
// Based on GL.jai/gl_label_object, but removes is_debug_context, which we can't set since we load the GL context with SDL
debug_label_object :: (identifier: GLenum, name: GLuint, label: string) {
    #if DEBUG_OPENGL {
        if label {
            if GL_VERSION_4_3           glObjectLabel(identifier, name, xx label.count, label.data);
            else if GL_KHR_debug        glObjectLabelKHR(identifier, name, xx label.count, label.data);
            else if GL_EXT_debug_label  glLabelObjectEXT(identifier, name, xx label.count, label.data);
        }
    }
}

DebugScopeGLGroup :: (message: string) #expand {
    if DEBUG_OPENGL        glPushDebugGroup(GL_DEBUG_SOURCE_APPLICATION, 0, xx message.count, message.data);
    `defer if DEBUG_OPENGL glPopDebugGroup();
}


print_errors :: (loc := #caller_location) {
    DumpGLErrors("context %", #location());

    {
        error := glGetError();
        if (error != GL_NO_ERROR) {
            print("error:%:%,%: code % (0x%)\n", loc.fully_pathed_filename, loc.line_number, loc.character_number, error, formatInt(error, base=16));
            print("stack trace\n");
            for pack_stack_trace() {
                print_stack_trace(*it);
            }
            exit(-1);
        }
    }
}