// dear imgui: Renderer Backend for modern OpenGL with shaders / programmatic pipeline
// - Desktop GL: 2.x 3.x 4.x
// - Embedded GL: ES 2.0 (WebGL 1.0), ES 3.0 (WebGL 2.0)
// This needs to be used along with a Platform Backend (e.g. GLFW, SDL, Win32, custom..)

// OpenGL Data
g_GlVersion :              GLuint = 0;   // Extracted at runtime using GL_MAJOR_VERSION, GL_MINOR_VERSION queries (e.g. 320 for GL 3.2)
g_GlslVersionString :      string = "";  // Specified by user or detected based on compile time GL settings.
g_FontTexture :            GLuint = 0;
g_ShaderHandle :           GLuint = 0;
g_VertHandle :             GLuint = 0;
g_FragHandle :             GLuint = 0;
g_AttribLocationTex :      GLint = 0;
g_AttribLocationProjMtx :  GLint = 0;
g_AttribLocationVtxPos :   GLuint = 0;
g_AttribLocationVtxUV :    GLuint = 0;
g_AttribLocationVtxColor : GLuint = 0;
g_VboHandle :              u32 = 0;
g_ElementsHandle :         u32 = 0;
g_HasClipOrigin :          bool = false;

ImGui_ImplOpenGL3_Init :: (glsl_version : *u8) -> bool {
    // Query for GL version (e.g. 320 for GL 3.2)
    major : GLint = 0;
    minor : GLint = 0;
    glGetIntegerv(GL_MAJOR_VERSION, *major);
    glGetIntegerv(GL_MINOR_VERSION, *minor);
    assert(major != 0);
    // if (major == 0 && minor == 0) {
    //     // Query GL_VERSION in desktop GL 2.x, the string will start with "<major>.<minor>"
    //     gl_version : *GLubyte = glGetString(GL_VERSION);
    //     sscanf(gl_version, "%d.%d", &major, &minor);
    // }
    g_GlVersion = cast(GLuint)(major * 100 + minor * 10);
    // print("g_GlVersion = %\n", g_GlVersion);

    // Setup backend capabilities flags
    io := ImGui.GetIO();
    io.BackendRendererName = "imgui_impl_opengl3";
    if (g_GlVersion >= 320)
        io.BackendFlags_ |= .RendererHasVtxOffset;  // We can honor the ImDrawCmd::VtxOffset field, allowing for large meshes.
    io.BackendFlags_ |= .RendererHasViewports;  // We can create multi-viewports on the Renderer side (optional)

    // Store GLSL version string so we can refer to it later in case we recreate shaders.
    // Note: GLSL version is NOT the same as GL version. Leave this to NULL if unsure.
    if glsl_version == "" glsl_version = "#version 130";
    g_GlslVersionString = to_string(glsl_version);

    // Make an arbitrary GL call (we don't actually need the result)
    // IF YOU GET A CRASH HERE: it probably means that you haven't initialized the OpenGL function loader used by this code.
    // Desktop OpenGL 3/4 need a function loader. See the IMGUI_IMPL_OPENGL_LOADER_xxx explanation above.
    current_texture : GLint;
    glGetIntegerv(GL_TEXTURE_BINDING_2D, *current_texture);

    // Detect extensions we support
    g_HasClipOrigin = (g_GlVersion >= 450);

    if (io.ConfigFlags_ & .ViewportsEnable)
        ImGui_ImplOpenGL3_InitPlatformInterface();

    return true;
}

ImGui_ImplOpenGL3_Shutdown :: () {
    ImGui_ImplOpenGL3_ShutdownPlatformInterface();
    ImGui_ImplOpenGL3_DestroyDeviceObjects();
}

ImGui_ImplOpenGL3_NewFrame :: () {
    if (!g_ShaderHandle)
        ImGui_ImplOpenGL3_CreateDeviceObjects();
}

ImGui_ImplOpenGL3_SetupRenderState :: (draw_data : *ImGui.ImDrawData, fb_width : s32, fb_height : s32, vertex_array_object : GLuint) {
    // Setup render state: alpha-blending enabled, no face culling, no depth testing, scissor enabled, polygon fill
    glEnable(GL_BLEND);
    glBlendEquation(GL_FUNC_ADD);
    glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glDisable(GL_CULL_FACE);
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_STENCIL_TEST);
    glEnable(GL_SCISSOR_TEST);
    if (g_GlVersion >= 310)
        glDisable(GL_PRIMITIVE_RESTART);
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

    // Setup viewport, orthographic projection matrix
    // Our visible imgui space lies from draw_data->DisplayPos (top left) to draw_data->DisplayPos+data_data->DisplaySize (bottom right). DisplayPos is (0,0) for single viewport apps.
    glViewport(0, 0, cast(GLsizei)fb_width, cast(GLsizei)fb_height);
    L := draw_data.DisplayPos.x;
    R := draw_data.DisplayPos.x + draw_data.DisplaySize.x;
    T := draw_data.DisplayPos.y;
    B := draw_data.DisplayPos.y + draw_data.DisplaySize.y;
    ortho_projection := orthographic_projection_matrix(L, R, B, T, 0, 1);
    ortho_projection = transpose(ortho_projection);

    glUseProgram(g_ShaderHandle);
    glUniform1i(g_AttribLocationTex, 0);
    glUniformMatrix4fv(g_AttribLocationProjMtx, 1, GL_FALSE, xx *ortho_projection);

    if (g_GlVersion >= 330)
        glBindSampler(0, 0); // We use combined texture/sampler state. Applications using GL 3.3 may set that otherwise.

    glBindVertexArray(vertex_array_object);

    // Bind vertex/index buffers and setup attributes for ImDrawVert
    glBindBuffer(GL_ARRAY_BUFFER, g_VboHandle);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, g_ElementsHandle);
    glEnableVertexAttribArray(g_AttribLocationVtxPos);
    glEnableVertexAttribArray(g_AttribLocationVtxUV);
    glEnableVertexAttribArray(g_AttribLocationVtxColor);
    glVertexAttribPointer(g_AttribLocationVtxPos, 2, GL_FLOAT, GL_FALSE, size_of(ImGui.ImDrawVert), xx 0);
    glVertexAttribPointer(g_AttribLocationVtxUV, 2, GL_FLOAT, GL_FALSE, size_of(ImGui.ImDrawVert), xx 8);
    glVertexAttribPointer(g_AttribLocationVtxColor, 4, GL_UNSIGNED_BYTE, GL_TRUE, size_of(ImGui.ImDrawVert), xx 16);
}

// OpenGL3 Render function.
// Note that this implementation is little overcomplicated because we are saving/setting up/restoring every OpenGL state explicitly.
// This is in order to be able to run within an OpenGL engine that doesn't do so.
ImGui_ImplOpenGL3_RenderDrawData :: (draw_data : *ImGui.ImDrawData) {
    // Avoid rendering when minimized, scale coordinates for retina displays (screen coordinates != framebuffer coordinates)
    io := ImGui.GetIO();
    fb_width : s32 = xx (io.DisplaySize.x * io.DisplayFramebufferScale.x);
    fb_height : s32 = xx (io.DisplaySize.y * io.DisplayFramebufferScale.y);
    if fb_width <= 0 || fb_height <= 0
        return;

    // Backup GL state
    last_active_texture : GLenum;       glGetIntegerv(GL_ACTIVE_TEXTURE, xx *last_active_texture);
    glActiveTexture(GL_TEXTURE0);
    last_program : GLuint;              glGetIntegerv(GL_CURRENT_PROGRAM, xx *last_program);
    last_texture : GLuint;              glGetIntegerv(GL_TEXTURE_BINDING_2D, xx *last_texture);
    last_sampler : GLuint;              if (g_GlVersion >= 330) glGetIntegerv(GL_SAMPLER_BINDING, xx *last_sampler);
    last_array_buffer : GLuint;         glGetIntegerv(GL_ARRAY_BUFFER_BINDING, xx *last_array_buffer);
    last_vertex_array_object : GLuint;  glGetIntegerv(GL_VERTEX_ARRAY_BINDING, xx *last_vertex_array_object);
    last_polygon_mode : [2]GLint;       glGetIntegerv(GL_POLYGON_MODE, last_polygon_mode.data);
    last_viewport : [4]GLint;           glGetIntegerv(GL_VIEWPORT, last_viewport.data);
    last_scissor_box : [4]GLint ;       glGetIntegerv(GL_SCISSOR_BOX, last_scissor_box.data);
    last_blend_src_rgb : GLenum;        glGetIntegerv(GL_BLEND_SRC_RGB, xx *last_blend_src_rgb);
    last_blend_dst_rgb : GLenum;        glGetIntegerv(GL_BLEND_DST_RGB, xx *last_blend_dst_rgb);
    last_blend_src_alpha : GLenum;      glGetIntegerv(GL_BLEND_SRC_ALPHA, xx *last_blend_src_alpha);
    last_blend_dst_alpha : GLenum;      glGetIntegerv(GL_BLEND_DST_ALPHA, xx *last_blend_dst_alpha);
    last_blend_equation_rgb : GLenum;   glGetIntegerv(GL_BLEND_EQUATION_RGB, xx *last_blend_equation_rgb);
    last_blend_equation_alpha : GLenum; glGetIntegerv(GL_BLEND_EQUATION_ALPHA, xx *last_blend_equation_alpha);
    last_enable_blend := glIsEnabled(GL_BLEND);
    last_enable_cull_face := glIsEnabled(GL_CULL_FACE);
    last_enable_depth_test := glIsEnabled(GL_DEPTH_TEST);
    last_enable_stencil_test := glIsEnabled(GL_STENCIL_TEST);
    last_enable_scissor_test := glIsEnabled(GL_SCISSOR_TEST);
    last_enable_primitive_restart : GLboolean; if (g_GlVersion >= 310) last_enable_primitive_restart = glIsEnabled(GL_PRIMITIVE_RESTART);

    // Setup desired GL state
    // Recreate the VAO every time (this is to easily allow multiple GL contexts to be rendered to. VAO are not shared among GL contexts)
    // The renderer would actually work without any VAO bound, but then our VertexAttrib calls would overwrite the default one currently bound.
    vertex_array_object : GLuint;
    glGenVertexArrays(1, *vertex_array_object);
    ImGui_ImplOpenGL3_SetupRenderState(draw_data, fb_width, fb_height, vertex_array_object);

    // Will project scissor/clipping rectangles into framebuffer space
    clip_off := draw_data.DisplayPos;         // (0,0) unless using multi-viewports
    clip_scale := draw_data.FramebufferScale; // (1,1) unless using retina display which are often (2,2)

    new_context : Context;
    push_context new_context {
    // Render command lists
    for n : 0..draw_data.CmdListsCount - 1 {
        cmd_list := draw_data.CmdLists[n];

        // Upload vertex/index buffers
        glBufferData(GL_ARRAY_BUFFER, cast(GLsizeiptr)cmd_list.VtxBuffer.Size * size_of(ImGui.ImDrawVert), xx cmd_list.VtxBuffer.Data, GL_STREAM_DRAW);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, cast(GLsizeiptr)cmd_list.IdxBuffer.Size * size_of(ImGui.ImDrawIdx), xx cmd_list.IdxBuffer.Data, GL_STREAM_DRAW);

        for cmd_i : 0..cmd_list.CmdBuffer.Size - 1 {
            pcmd := *cmd_list.CmdBuffer.Data[cmd_i];
            if pcmd.UserCallback {
                // @@
                // User callback, registered via ImDrawList::AddCallback()
                // (ImDrawCallback_ResetRenderState is a special callback value used by the user to request the renderer to reset render state.)
                // if pcmd.UserCallback == ImDrawCallback_ResetRenderState)
                //     ImGui_ImplOpenGL3_SetupRenderState(draw_data, fb_width, fb_height, vertex_array_object);
                // else
                    pcmd.UserCallback(cmd_list, pcmd);
            } else {
                // Project scissor/clipping rectangles into framebuffer space
                clip_rect : ImGui.ImVec4;
                clip_rect.x = (pcmd.ClipRect.x - clip_off.x) * clip_scale.x;
                clip_rect.y = (pcmd.ClipRect.y - clip_off.y) * clip_scale.y;
                clip_rect.z = (pcmd.ClipRect.z - clip_off.x) * clip_scale.x;
                clip_rect.w = (pcmd.ClipRect.w - clip_off.y) * clip_scale.y;

                if (clip_rect.x < xx fb_width && clip_rect.y < xx fb_height && clip_rect.z >= 0.0 && clip_rect.w >= 0.0) {
                    // Apply scissor/clipping rectangle
                    glScissor(xx clip_rect.x, xx (fb_height - clip_rect.w), xx (clip_rect.z - clip_rect.x), xx (clip_rect.w - clip_rect.y));

                    // Bind texture, Draw
                    glBindTexture(GL_TEXTURE_2D, xx pcmd.TextureId);
                    // glBindTexture(GL_TEXTURE_2D, xx io.Fonts.TexID);
                    if (g_GlVersion >= 320) {
                        itype : GLenum = GL_UNSIGNED_INT;
                        if size_of(ImGui.ImDrawIdx) == 2 itype = GL_UNSIGNED_SHORT;

                        glDrawElementsBaseVertex(GL_TRIANGLES, xx pcmd.ElemCount, itype, xx (pcmd.IdxOffset * size_of(ImGui.ImDrawIdx)), xx pcmd.VtxOffset);
                    } else {
                        itype : GLenum = GL_UNSIGNED_INT;
                        if size_of(ImGui.ImDrawIdx) == 2 itype = GL_UNSIGNED_SHORT;

                        glDrawElements(GL_TRIANGLES, xx pcmd.ElemCount, itype, xx (pcmd.IdxOffset * size_of(ImGui.ImDrawIdx)));
                    }
                }
            }
        }
    }
    }

    // Destroy the temporary VAO
    glDeleteVertexArrays(1, *vertex_array_object);

    // Restore modified GL state
    glUseProgram(last_program);
    glBindTexture(GL_TEXTURE_2D, last_texture);
    if (g_GlVersion >= 330)
        glBindSampler(0, last_sampler);
    glActiveTexture(last_active_texture);
    glBindVertexArray(last_vertex_array_object);
    glBindBuffer(GL_ARRAY_BUFFER, last_array_buffer);
    glBlendEquationSeparate(last_blend_equation_rgb, last_blend_equation_alpha);
    glBlendFuncSeparate(last_blend_src_rgb, last_blend_dst_rgb, last_blend_src_alpha, last_blend_dst_alpha);
    if last_enable_blend        glEnable(GL_BLEND);        else glDisable(GL_BLEND);
    if last_enable_cull_face    glEnable(GL_CULL_FACE);    else glDisable(GL_CULL_FACE);
    if last_enable_depth_test   glEnable(GL_DEPTH_TEST);   else glDisable(GL_DEPTH_TEST);
    if last_enable_stencil_test glEnable(GL_STENCIL_TEST); else glDisable(GL_STENCIL_TEST);
    if last_enable_scissor_test glEnable(GL_SCISSOR_TEST); else glDisable(GL_SCISSOR_TEST);
    if g_GlVersion >= 310 { if last_enable_primitive_restart glEnable(GL_PRIMITIVE_RESTART); else glDisable(GL_PRIMITIVE_RESTART); }
    glPolygonMode(GL_FRONT_AND_BACK, xx last_polygon_mode[0]);
    glViewport(last_viewport[0], last_viewport[1], xx last_viewport[2], xx last_viewport[3]);
    glScissor(last_scissor_box[0], last_scissor_box[1], xx last_scissor_box[2], xx last_scissor_box[3]);
}

ImGui_ImplOpenGL3_CreateFontsTexture :: () -> bool{
    // Build texture atlas
    io := ImGui.GetIO();
    assert(io != null);
    assert(io.Fonts != null);

    pixels : *u8 = null;
    width, height : s32;

    io.Fonts.GetTexDataAsAlpha8(io.Fonts, *pixels, *width, *height);
    // io.Fonts.GetTexDataAsRGBA32(io.Fonts, *pixels, *width, *height);
    assert(pixels != null);
    assert(width > 0);
    assert(height > 0);
    // io.Fonts.GetTexDataAsRGBA32(pixels, *width, *height);   // Load as RGBA 32-bit (75% of the memory is wasted, but default font is so small) because it is more likely to be compatible with user's existing shaders. If your ImTextureId represent a higher-level concept than just a GL texture id, consider calling GetTexDataAsAlpha8() instead to save on GPU memory.

    // Upload texture to graphics system
    last_texture : GLuint;
    glGetIntegerv(GL_TEXTURE_BINDING_2D, xx *last_texture);
    glGenTextures(1, *g_FontTexture);
    glBindTexture(GL_TEXTURE_2D, g_FontTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    // glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, xx width, xx height, 0, GL_RED, GL_UNSIGNED_BYTE, pixels);
    // glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, xx width, xx height, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);

    // Store our identifier
    io.Fonts.TexID = xx g_FontTexture;

    // Restore state
    glBindTexture(GL_TEXTURE_2D, last_texture);

    return true;
}

ImGui_ImplOpenGL3_DestroyFontsTexture :: () {
    if (g_FontTexture) {
        io := ImGui.GetIO();
        glDeleteTextures(1, *g_FontTexture);
        io.Fonts.TexID = null;
        g_FontTexture = 0;
    }
}

// If you get an error please report on github. You may try different GL context version or GLSL version. See GL<>GLSL version table at the top of this file.
CheckShader :: (handle : GLuint, desc : string) -> bool {
    status, log_length : GLint;
    glGetShaderiv(handle, GL_COMPILE_STATUS, *status);
    glGetShaderiv(handle, GL_INFO_LOG_LENGTH, *log_length);
    if xx status == GL_FALSE
        print("ERROR: ImGui_ImplOpenGL3_CreateDeviceObjects: failed to compile %!\n", desc);
    // if (log_length > 1) {
    //     ImVector<char> buf;
    //     buf.resize((int)(log_length + 1));
    //     glGetShaderInfoLog(handle, log_length, NULL, (GLchar*)buf.begin());
    //     fprintf(stderr, "%s\n", buf.begin());
    // }
    return xx status == GL_TRUE;
}

// If you get an error please report on GitHub. You may try different GL context version or GLSL version.
CheckProgram :: (handle : GLuint, desc : string) -> bool {
    status, log_length : GLint;
    glGetProgramiv(handle, GL_LINK_STATUS, *status);
    glGetProgramiv(handle, GL_INFO_LOG_LENGTH, *log_length);
    if xx status == GL_FALSE
        print("ERROR: ImGui_ImplOpenGL3_CreateDeviceObjects: failed to link %! (with GLSL '%')\n", desc, g_GlslVersionString);
    // if (log_length > 1) {
    //     ImVector<char> buf;
    //     buf.resize((int)(log_length + 1));
    //     glGetProgramInfoLog(handle, log_length, NULL, (GLchar*)buf.begin());
    //     fprintf(stderr, "%s\n", buf.begin());
    // }
    return xx status == GL_TRUE;
}

ImGui_ImplOpenGL3_CreateDeviceObjects :: () -> bool {
    // Backup GL state
    last_texture, last_array_buffer, last_vertex_array : GLint;
    glGetIntegerv(GL_TEXTURE_BINDING_2D, *last_texture);
    glGetIntegerv(GL_ARRAY_BUFFER_BINDING, *last_array_buffer);
    glGetIntegerv(GL_VERTEX_ARRAY_BINDING, *last_vertex_array);

    vertex_shader := tprint(#string END
        #version 330
        uniform mat4 ProjMtx;
        in vec2 Position;
        in vec2 UV;
        in vec4 Color;
        out vec2 Frag_UV;
        out vec4 Frag_Color;
        void main() {
           Frag_UV = UV;
           // By default, the binaries shipped with jai-imgui are built with IMGUI_USE_BGRA_PACKED_COLOR.
           // This is more efficient in D3D11, but in opengl there's no way to specify the input buffers
           // format to be BGRA, so we just do the swizzle here if our module parameter, also named
           // IMGUI_USE_BGRA_PACKED_COLOR, is true.
           Frag_Color = Color.%;
           gl_Position = ProjMtx * vec4(Position.xy,0,1);
        }
    END,
        ifx ImGui.IMGUI_USE_BGRA_PACKED_COLOR then "bgra" else "rgba");

    fragment_shader := #string END
        #version 330
        uniform sampler2D Texture;
        in vec2 Frag_UV;
        in vec4 Frag_Color;
        out vec4 Out_Color;
        void main() {
           Out_Color = Frag_Color * texture( Texture, Frag_UV.st).r;
        }
    END

    // Create shaders
    g_VertHandle = glCreateShader(GL_VERTEX_SHADER);
    _glShaderSource(g_VertHandle, vertex_shader);
    glCompileShader(g_VertHandle);
    CheckShader(g_VertHandle, "vertex shader");

    g_FragHandle = glCreateShader(GL_FRAGMENT_SHADER);
    _glShaderSource(g_FragHandle, fragment_shader);
    glCompileShader(g_FragHandle);
    CheckShader(g_FragHandle, "fragment shader");

    g_ShaderHandle = glCreateProgram();
    glAttachShader(g_ShaderHandle, g_VertHandle);
    glAttachShader(g_ShaderHandle, g_FragHandle);
    glLinkProgram(g_ShaderHandle);
    CheckProgram(g_ShaderHandle, "shader program");

    g_AttribLocationTex = glGetUniformLocation(g_ShaderHandle, "Texture");
    g_AttribLocationProjMtx = glGetUniformLocation(g_ShaderHandle, "ProjMtx");
    g_AttribLocationVtxPos = xx glGetAttribLocation(g_ShaderHandle, "Position");
    g_AttribLocationVtxUV = xx glGetAttribLocation(g_ShaderHandle, "UV");
    g_AttribLocationVtxColor = xx glGetAttribLocation(g_ShaderHandle, "Color");

    // Create buffers
    glGenBuffers(1, *g_VboHandle);
    glGenBuffers(1, *g_ElementsHandle);

    ImGui_ImplOpenGL3_CreateFontsTexture();

    // Restore modified GL state
    glBindTexture(GL_TEXTURE_2D, xx last_texture);
    glBindBuffer(GL_ARRAY_BUFFER, xx last_array_buffer);
    glBindVertexArray(xx last_vertex_array);

    return true;
}

ImGui_ImplOpenGL3_DestroyDeviceObjects :: () {
    if (g_VboHandle)        { glDeleteBuffers(1, *g_VboHandle); g_VboHandle = 0; }
    if (g_ElementsHandle)   { glDeleteBuffers(1, *g_ElementsHandle); g_ElementsHandle = 0; }
    if (g_ShaderHandle && g_VertHandle) { glDetachShader(g_ShaderHandle, g_VertHandle); }
    if (g_ShaderHandle && g_FragHandle) { glDetachShader(g_ShaderHandle, g_FragHandle); }
    if (g_VertHandle)       { glDeleteShader(g_VertHandle); g_VertHandle = 0; }
    if (g_FragHandle)       { glDeleteShader(g_FragHandle); g_FragHandle = 0; }
    if (g_ShaderHandle)     { glDeleteProgram(g_ShaderHandle); g_ShaderHandle = 0; }

    ImGui_ImplOpenGL3_DestroyFontsTexture();
}

//--------------------------------------------------------------------------------------------------------
// MULTI-VIEWPORT / PLATFORM INTERFACE SUPPORT
// This is an _advanced_ and _optional_ feature, allowing the backend to create and handle multiple viewports simultaneously.
// If you are new to dear imgui or creating a new binding for dear imgui, it is recommended that you completely ignore this section first..
//--------------------------------------------------------------------------------------------------------

ImGui_ImplOpenGL3_RenderWindow :: (viewport : *ImGui.Viewport, data : *void) #c_call{
    new_context : Context;
    push_context new_context {
        if (!(viewport.Flags & .NoRendererClear)) {
            clear_color :: ImGui.ImVec4.{0.0, 0.0, 0.0, 1.0};
            glClearColor(clear_color.x, clear_color.y, clear_color.z, clear_color.w);
            glClear(GL_COLOR_BUFFER_BIT);
        }
        ImGui_ImplOpenGL3_RenderDrawData(viewport.DrawData);
    }
}

ImGui_ImplOpenGL3_InitPlatformInterface :: () {
    platform_io := ImGui.GetPlatformIO();
    platform_io.Renderer_RenderWindow = ImGui_ImplOpenGL3_RenderWindow;
}

ImGui_ImplOpenGL3_ShutdownPlatformInterface :: () {
    ImGui.DestroyPlatformWindows();
}

#scope_file

ImGui :: #import "jai-imgui"(LINK_STATIC=true);
#import "GL";