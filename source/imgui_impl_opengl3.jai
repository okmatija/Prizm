// dear imgui: Renderer Backend for modern OpenGL with shaders / programmatic pipeline
// - Desktop GL: 2.x 3.x 4.x
// - Embedded GL: ES 2.0 (WebGL 1.0), ES 3.0 (WebGL 2.0)
// This needs to be used along with a Platform Backend (e.g. GLFW, SDL, Win32, custom..)

// Implemented features:
//  [X] Renderer: User texture binding. Use 'GLuint' OpenGL texture identifier as void*/ImTextureID. Read the FAQ about ImTextureID!
//  [x] Renderer: Desktop GL only: Support for large meshes (64k+ vertices) with 16-bit indices.

// You can use unmodified imgui_impl_* files in your project. See examples/ folder for examples of using this.
// Prefer including the entire imgui/ repository into your project (either as a copy or as a submodule), and only build the backends you need.
// If you are new to Dear ImGui, read documentation from the docs/ folder + read the top of imgui.cpp.
// Read online: https://github.com/ocornut/imgui/tree/master/docs

// CHANGELOG
// (minor and older changes stripped away, please see git history for details)
//  2021-08-23: OpenGL: Fixed ES 3.0 shader ("#version 300 es") use normal precision floats to avoid wobbly rendering at HD resolutions.
//  2021-08-19: OpenGL: Embed and use our own minimal GL loader (imgui_impl_opengl3_loader.h), removing requirement and support for third-party loader.
//  2021-06-29: Reorganized backend to pull data from a single structure to facilitate usage with multiple-contexts (all g_XXXX access changed to bd->XXXX).
//  2021-06-25: OpenGL: Use OES_vertex_array extension on Emscripten + backup/restore current state.
//  2021-06-21: OpenGL: Destroy individual vertex/fragment shader objects right after they are linked into the main shader.
//  2021-05-24: OpenGL: Access GL_CLIP_ORIGIN when "GL_ARB_clip_control" extension is detected, inside of just OpenGL 4.5 version.
//  2021-05-19: OpenGL: Replaced direct access to ImDrawCmd::TextureId with a call to ImDrawCmd::GetTexID(). (will become a requirement)
//  2021-04-06: OpenGL: Don't try to read GL_CLIP_ORIGIN unless we're OpenGL 4.5 or greater.
//  2021-02-18: OpenGL: Change blending equation to preserve alpha in output buffer.
//  2021-01-03: OpenGL: Backup, setup and restore GL_STENCIL_TEST state.
//  2020-10-23: OpenGL: Backup, setup and restore GL_PRIMITIVE_RESTART state.
//  2020-10-15: OpenGL: Use glGetString(GL_VERSION) instead of glGetIntegerv(GL_MAJOR_VERSION, ...) when the later returns zero (e.g. Desktop GL 2.x)
//  2020-09-17: OpenGL: Fix to avoid compiling/calling glBindSampler() on ES or pre 3.3 context which have the defines set by a loader.
//  2020-07-10: OpenGL: Added support for glad2 OpenGL loader.
//  2020-05-08: OpenGL: Made default GLSL version 150 (instead of 130) on OSX.
//  2020-04-21: OpenGL: Fixed handling of glClipControl(GL_UPPER_LEFT) by inverting projection matrix.
//  2020-04-12: OpenGL: Fixed context version check mistakenly testing for 4.0+ instead of 3.2+ to enable ImGuiBackendFlags_RendererHasVtxOffset.
//  2020-03-24: OpenGL: Added support for glbinding 2.x OpenGL loader.
//  2020-01-07: OpenGL: Added support for glbinding 3.x OpenGL loader.
//  2019-10-25: OpenGL: Using a combination of GL define and runtime GL version to decide whether to use glDrawElementsBaseVertex(). Fix building with pre-3.2 GL loaders.
//  2019-09-22: OpenGL: Detect default GL loader using __has_include compiler facility.
//  2019-09-16: OpenGL: Tweak initialization code to allow application calling ImGui_ImplOpenGL3_CreateFontsTexture() before the first NewFrame() call.
//  2019-05-29: OpenGL: Desktop GL only: Added support for large mesh (64K+ vertices), enable ImGuiBackendFlags_RendererHasVtxOffset flag.
//  2019-04-30: OpenGL: Added support for special ImDrawCallback_ResetRenderState callback to reset render state.
//  2019-03-29: OpenGL: Not calling glBindBuffer more than necessary in the render loop.
//  2019-03-15: OpenGL: Added a GL call + comments in ImGui_ImplOpenGL3_Init() to detect uninitialized GL function loaders early.
//  2019-03-03: OpenGL: Fix support for ES 2.0 (WebGL 1.0).
//  2019-02-20: OpenGL: Fix for OSX not supporting OpenGL 4.5, we don't try to read GL_CLIP_ORIGIN even if defined by the headers/loader.
//  2019-02-11: OpenGL: Projecting clipping rectangles correctly using draw_data->FramebufferScale to allow multi-viewports for retina display.
//  2019-02-01: OpenGL: Using GLSL 410 shaders for any version over 410 (e.g. 430, 450).
//  2018-11-30: Misc: Setting up io.BackendRendererName so it can be displayed in the About Window.
//  2018-11-13: OpenGL: Support for GL 4.5's glClipControl(GL_UPPER_LEFT) / GL_CLIP_ORIGIN.
//  2018-08-29: OpenGL: Added support for more OpenGL loaders: glew and glad, with comments indicative that any loader can be used.
//  2018-08-09: OpenGL: Default to OpenGL ES 3 on iOS and Android. GLSL version default to "#version 300 ES".
//  2018-07-30: OpenGL: Support for GLSL 300 ES and 410 core. Fixes for Emscripten compilation.
//  2018-07-10: OpenGL: Support for more GLSL versions (based on the GLSL version string). Added error output when shaders fail to compile/link.
//  2018-06-08: Misc: Extracted imgui_impl_opengl3.cpp/.h away from the old combined GLFW/SDL+OpenGL3 examples.
//  2018-06-08: OpenGL: Use draw_data->DisplayPos and draw_data->DisplaySize to setup projection matrix and clipping rectangle.
//  2018-05-25: OpenGL: Removed unnecessary backup/restore of GL_ELEMENT_ARRAY_BUFFER_BINDING since this is part of the VAO state.
//  2018-05-14: OpenGL: Making the call to glBindSampler() optional so 3.2 context won't fail if the function is a NULL pointer.
//  2018-03-06: OpenGL: Added const char* glsl_version parameter to ImGui_ImplOpenGL3_Init() so user can override the GLSL version e.g. "#version 150".
//  2018-02-23: OpenGL: Create the VAO in the render function so the setup can more easily be used with multiple shared GL context.
//  2018-02-16: Misc: Obsoleted the io.RenderDrawListsFn callback and exposed ImGui_ImplSdlGL3_RenderDrawData() in the .h file so you can call it yourself.
//  2018-01-07: OpenGL: Changed GLSL shader version from 330 to 150.
//  2017-09-01: OpenGL: Save and restore current bound sampler. Save and restore current polygon mode.
//  2017-05-01: OpenGL: Fixed save and restore of current blend func state.
//  2017-05-01: OpenGL: Fixed save and restore of current GL_ACTIVE_TEXTURE.
//  2016-09-05: OpenGL: Fixed save and restore of current scissor rectangle.
//  2016-07-29: OpenGL: Explicitly setting GL_UNPACK_ROW_LENGTH to reduce issues because SDL changes it. (#752)

//----------------------------------------
// OpenGL    GLSL      GLSL
// version   version   string
//----------------------------------------
//  2.0       110       "#version 110"
//  2.1       120       "#version 120"
//  3.0       130       "#version 130"
//  3.1       140       "#version 140"
//  3.2       150       "#version 150"
//  3.3       330       "#version 330 core"
//  4.0       400       "#version 400 core"
//  4.1       410       "#version 410 core"
//  4.2       420       "#version 410 core"
//  4.3       430       "#version 430 core"
//  ES 2.0    100       "#version 100"      = WebGL 1.0
//  ES 3.0    300       "#version 300 es"   = WebGL 2.0
//----------------------------------------

// Vertex arrays are not supported on ES2/WebGL1 unless Emscripten which uses an extension
IMGUI_IMPL_OPENGL_USE_VERTEX_ARRAY :: true;

// Desktop GL 2.0+ has glPolygonMode() which GL ES and WebGL don't have.
IMGUI_IMPL_HAS_POLYGON_MODE :: true;

// Desktop GL 3.2+ has glDrawElementsBaseVertex() which GL ES and WebGL don't have.
IMGUI_IMPL_OPENGL_MAY_HAVE_VTX_OFFSET :: true;

// Desktop GL 3.3+ has glBindSampler()
IMGUI_IMPL_OPENGL_MAY_HAVE_BIND_SAMPLER :: true;

// Desktop GL 3.1+ has GL_PRIMITIVE_RESTART state
IMGUI_IMPL_OPENGL_MAY_HAVE_PRIMITIVE_RESTART :: true;

// Desktop GL use extension detection
IMGUI_IMPL_OPENGL_MAY_HAVE_EXTENSIONS :: true;

// OpenGL Data
ImGui_ImplOpenGL3_Data :: struct
{
    GlVersion :                 GLuint; // Extracted at runtime using GL_MAJOR_VERSION, GL_MINOR_VERSION queries (e.g. 320 for GL 3.2)
    GlslVersionString :         string; // Specified by user or detected based on compile time GL settings.
    FontTexture :               GLuint;
    ShaderHandle :              GLuint;
    AttribLocationTex :         GLint;  // Uniforms location
    AttribLocationProjMtx :     GLint;
    AttribLocationVtxPos :      GLuint; // Vertex attributes location
    AttribLocationVtxUV :       GLuint;
    AttribLocationVtxColor :    GLuint;
    VboHandle, ElementsHandle : u32;
    HasClipOrigin :             bool;
};

#scope_file

// Backend data stored in io.BackendRendererUserData to allow support for multiple Dear ImGui contexts
// It is STRONGLY preferred that you use docking branch with multi-viewports (== single Dear ImGui context + multiple windows) instead of multiple Dear ImGui contexts.
ImGui_ImplOpenGL3_GetBackendData :: () -> *ImGui_ImplOpenGL3_Data 
{
    return ifx ImGui.GetCurrentContext() then cast(*ImGui_ImplOpenGL3_Data)ImGui.GetIO().BackendRendererUserData else null;
}

#scope_export

// Functions
ImGui_ImplOpenGL3_Init :: (glsl_version : *u8 = null) -> bool
{
    io := ImGui.GetIO();
    assert(io.BackendRendererUserData == null); // Already initialized a renderer backend!

    // Setup backend capabilities flags
    bd := New(ImGui_ImplOpenGL3_Data);
    io.BackendRendererUserData = cast(*void)bd;
    io.BackendRendererName = "imgui_impl_opengl3";

    // Query for GL version (e.g. 320 for GL 3.2)
    major : GLint = 0;
    minor : GLint = 0;
    glGetIntegerv(GL_MAJOR_VERSION, *major);
    glGetIntegerv(GL_MINOR_VERSION, *minor);
    assert((major == 0 && minor == 0) == false);
    // @Incomplete Jai port doesn't support GL 2.x
    // if (major == 0 && minor == 0)
    // {
    //     // Query GL_VERSION in desktop GL 2.x, the string will start with "<major>.<minor>"
    //     const char* gl_version = (const char*)glGetString(GL_VERSION);
    //     sscanf(gl_version, "%d.%d", &major, &minor);
    // }
    bd.GlVersion = cast(GLuint)(major * 100 + minor * 10);

#if IMGUI_IMPL_OPENGL_MAY_HAVE_VTX_OFFSET {
    if (bd.GlVersion >= 320)
        io.BackendFlags_ |= ImGui.BackendFlags.RendererHasVtxOffset;  // We can honor the ImDrawCmd::VtxOffset field, allowing for large meshes.
}

    // Store GLSL version string so we can refer to it later in case we recreate shaders.
    // Note: GLSL version is NOT the same as GL version. Leave this to NULL if unsure.
    if (glsl_version == "")
    {
        glsl_version = "#version 130";
    }
    bd.GlslVersionString = to_string(glsl_version);
    assert(bd.GlslVersionString == "#version 130", "Jai port only includes glsl version 130 shader"); // @Incomplete Jai port only includes glsl version 130 shader

    // Make an arbitrary GL call (we don't actually need the result)
    // IF YOU GET A CRASH HERE: it probably means the OpenGL function loader didn't do its job. Let us know!
    current_texture : GLint;
    glGetIntegerv(GL_TEXTURE_BINDING_2D, *current_texture);

    // Detect extensions we support
    bd.HasClipOrigin = (bd.GlVersion >= 450);
#if IMGUI_IMPL_OPENGL_MAY_HAVE_EXTENSIONS {
    num_extensions : GLint = 0;
    glGetIntegerv(GL_NUM_EXTENSIONS, *num_extensions);
    for i : 0..num_extensions-1
    {
        extension : *u8 = cast(*u8) glGetStringi(GL_EXTENSIONS, xx i);
        if extension != null {
            extension_string := to_string(extension);
            if extension_string == "GL_ARB_clip_control" {
                bd.HasClipOrigin = true;
            }
        }
    }
}

    return true;
}

ImGui_ImplOpenGL3_Shutdown :: ()
{
    bd := ImGui_ImplOpenGL3_GetBackendData();
    assert(bd != null); // No renderer backend to shutdown, or already shutdown?
    io := ImGui.GetIO();

    ImGui_ImplOpenGL3_DestroyDeviceObjects();
    io.BackendRendererName = null;
    io.BackendRendererUserData = null;
    free(bd);
}

ImGui_ImplOpenGL3_NewFrame :: ()
{
    bd := ImGui_ImplOpenGL3_GetBackendData();
    assert(bd != null); // Did you call ImGui_ImplOpenGL3_Init()?

    if (!bd.ShaderHandle)
        ImGui_ImplOpenGL3_CreateDeviceObjects();
}

#scope_file

ImGui_ImplOpenGL3_SetupRenderState :: (draw_data : *ImGui.ImDrawData, fb_width : s32, fb_height : s32, vertex_array_object : GLuint)
{
    bd := ImGui_ImplOpenGL3_GetBackendData();

    // Setup render state: alpha-blending enabled, no face culling, no depth testing, scissor enabled, polygon fill
    glEnable(GL_BLEND);
    glBlendEquation(GL_FUNC_ADD);
    glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glDisable(GL_CULL_FACE);
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_STENCIL_TEST);
    glEnable(GL_SCISSOR_TEST);
#if IMGUI_IMPL_OPENGL_MAY_HAVE_PRIMITIVE_RESTART {
    if (bd.GlVersion >= 310)
        glDisable(GL_PRIMITIVE_RESTART);
}
#if IMGUI_IMPL_HAS_POLYGON_MODE {
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
}

    // Support for GL 4.5 rarely used glClipControl(GL_UPPER_LEFT)
    // @Incomplete Jai port omits this code
// #if defined(GL_CLIP_ORIGIN)
//     bool clip_origin_lower_left = true;
//     if (bd->HasClipOrigin)
//     {
//         GLenum current_clip_origin = 0; glGetIntegerv(GL_CLIP_ORIGIN, (GLint*)&current_clip_origin);
//         if (current_clip_origin == GL_UPPER_LEFT)
//             clip_origin_lower_left = false;
//     }
// #endif

    // Setup viewport, orthographic projection matrix
    // Our visible imgui space lies from draw_data->DisplayPos (top left) to draw_data->DisplayPos+data_data->DisplaySize (bottom right). DisplayPos is (0,0) for single viewport apps.
    glViewport(0, 0, cast(GLsizei)fb_width, cast(GLsizei)fb_height);
    L : float = draw_data.DisplayPos.x;
    R : float = draw_data.DisplayPos.x + draw_data.DisplaySize.x;
    T : float = draw_data.DisplayPos.y;
    B : float = draw_data.DisplayPos.y + draw_data.DisplaySize.y;
    // @Incomplete Jai port omits this code
// #if defined(GL_CLIP_ORIGIN)
//     if (!clip_origin_lower_left) { float tmp = T; T = B; B = tmp; } // Swap top and bottom if origin is upper left
// #endif
    ortho_projection : Matrix4;
    ortho_projection._11 = 2./(R-L);
    ortho_projection._22 = 2./(T-B);
    ortho_projection._33 = -1.;
    ortho_projection._44 =  1.;
    ortho_projection._41 = (R+L)/(L-R);
    ortho_projection._42 = (T+B)/(B-T);
    glUseProgram(bd.ShaderHandle);
    glUniform1i(bd.AttribLocationTex, 0);
    glUniformMatrix4fv(bd.AttribLocationProjMtx, 1, GL_FALSE, *ortho_projection._11);

#if IMGUI_IMPL_OPENGL_MAY_HAVE_BIND_SAMPLER {
    if (bd.GlVersion >= 330)
        glBindSampler(0, 0); // We use combined texture/sampler state. Applications using GL 3.3 may set that otherwise.
}

#if IMGUI_IMPL_OPENGL_USE_VERTEX_ARRAY {
    glBindVertexArray(vertex_array_object);
}

    // Bind vertex/index buffers and setup attributes for ImDrawVert
    glBindBuffer(GL_ARRAY_BUFFER, bd.VboHandle);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, bd.ElementsHandle);
    glEnableVertexAttribArray(bd.AttribLocationVtxPos);
    glEnableVertexAttribArray(bd.AttribLocationVtxUV);
    glEnableVertexAttribArray(bd.AttribLocationVtxColor);
    glVertexAttribPointer(bd.AttribLocationVtxPos,   2, GL_FLOAT,         GL_FALSE, size_of(ImGui.ImDrawVert), xx 0);
    glVertexAttribPointer(bd.AttribLocationVtxUV,    2, GL_FLOAT,         GL_FALSE, size_of(ImGui.ImDrawVert), xx 8);
    glVertexAttribPointer(bd.AttribLocationVtxColor, 4, GL_UNSIGNED_BYTE, GL_TRUE,  size_of(ImGui.ImDrawVert), xx 16);
}

#scope_export

// OpenGL3 Render function.
// Note that this implementation is little overcomplicated because we are saving/setting up/restoring every OpenGL state explicitly.
// This is in order to be able to run within an OpenGL engine that doesn't do so.
ImGui_ImplOpenGL3_RenderDrawData :: (draw_data : *ImGui.ImDrawData)
{
    // Avoid rendering when minimized, scale coordinates for retina displays (screen coordinates != framebuffer coordinates)
    fb_width : s32 = xx (draw_data.DisplaySize.x * draw_data.FramebufferScale.x);
    fb_height : s32 = xx (draw_data.DisplaySize.y * draw_data.FramebufferScale.y);
    if (fb_width <= 0 || fb_height <= 0)
        return;

    bd := ImGui_ImplOpenGL3_GetBackendData();

    // Backup GL state
    last_active_texture : GLenum; glGetIntegerv(GL_ACTIVE_TEXTURE, xx *last_active_texture);
    glActiveTexture(GL_TEXTURE0);
    last_program : GLuint; glGetIntegerv(GL_CURRENT_PROGRAM, xx *last_program);
    last_texture : GLuint; glGetIntegerv(GL_TEXTURE_BINDING_2D, xx *last_texture);
#if IMGUI_IMPL_OPENGL_MAY_HAVE_BIND_SAMPLER {
    last_sampler : GLuint; if (bd.GlVersion >= 330) { glGetIntegerv(GL_SAMPLER_BINDING, xx *last_sampler); } else { last_sampler = 0; }
}
    last_array_buffer : GLuint; glGetIntegerv(GL_ARRAY_BUFFER_BINDING, xx *last_array_buffer);
#if IMGUI_IMPL_OPENGL_USE_VERTEX_ARRAY {
    last_vertex_array_object : GLuint; glGetIntegerv(GL_VERTEX_ARRAY_BINDING, xx *last_vertex_array_object);
}
#if IMGUI_IMPL_HAS_POLYGON_MODE {
    last_polygon_mode : [2]GLint; glGetIntegerv(GL_POLYGON_MODE, last_polygon_mode.data);
}
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
#if IMGUI_IMPL_OPENGL_MAY_HAVE_PRIMITIVE_RESTART {
    last_enable_primitive_restart := ifx bd.GlVersion >= 310 then glIsEnabled(GL_PRIMITIVE_RESTART) else GL_FALSE;
}

    // Setup desired GL state
    // Recreate the VAO every time (this is to easily allow multiple GL contexts to be rendered to. VAO are not shared among GL contexts)
    // The renderer would actually work without any VAO bound, but then our VertexAttrib calls would overwrite the default one currently bound.
    vertex_array_object : GLuint;
#if IMGUI_IMPL_OPENGL_USE_VERTEX_ARRAY {
    glGenVertexArrays(1, *vertex_array_object);
}
    ImGui_ImplOpenGL3_SetupRenderState(draw_data, fb_width, fb_height, vertex_array_object);

    // Will project scissor/clipping rectangles into framebuffer space
    clip_off := draw_data.DisplayPos;         // (0,0) unless using multi-viewports
    clip_scale := draw_data.FramebufferScale; // (1,1) unless using retina display which are often (2,2)

    new_context : #Context;
    push_context new_context {
    // Render command lists
    for n : 0..draw_data.CmdListsCount - 1 {
        cmd_list := draw_data.CmdLists[n];

        // Upload vertex/index buffers
        glBufferData(GL_ARRAY_BUFFER, cast(GLsizeiptr)cmd_list.VtxBuffer.Size * size_of(ImGui.ImDrawVert), xx cmd_list.VtxBuffer.Data, GL_STREAM_DRAW);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, cast(GLsizeiptr)cmd_list.IdxBuffer.Size * size_of(ImGui.ImDrawIdx), xx cmd_list.IdxBuffer.Data, GL_STREAM_DRAW);

        for cmd_i : 0..cmd_list.CmdBuffer.Size - 1 {
            pcmd := *cmd_list.CmdBuffer.Data[cmd_i];
            if pcmd.UserCallback != null
            {
                // User callback, registered via ImDrawList::AddCallback()
                // (ImDrawCallback_ResetRenderState is a special callback value used by the user to request the renderer to reset render state.)
                // @Incomplete Jai port omits this code
                // if (pcmd.UserCallback == ImDrawCallback_ResetRenderState)
                //     ImGui_ImplOpenGL3_SetupRenderState(draw_data, fb_width, fb_height, vertex_array_object);
                // else
                    pcmd.UserCallback(cmd_list, pcmd);
            }
            else
            {
                // Project scissor/clipping rectangles into framebuffer space
                clip_min := ImGui.ImVec2.{(pcmd.ClipRect.x - clip_off.x) * clip_scale.x, (pcmd.ClipRect.y - clip_off.y) * clip_scale.y};
                clip_max := ImGui.ImVec2.{(pcmd.ClipRect.z - clip_off.x) * clip_scale.x, (pcmd.ClipRect.w - clip_off.y) * clip_scale.y};
                if (clip_max.x < clip_min.x || clip_max.y < clip_min.y)
                    continue;

                // Apply scissor/clipping rectangle (Y is inverted in OpenGL)
                glScissor(xx clip_min.x, xx (fb_height - clip_max.y), xx (clip_max.x - clip_min.x), xx (clip_max.y - clip_min.y));

                // Bind texture, Draw
                glBindTexture(GL_TEXTURE_2D, xx pcmd.TextureId);
#if IMGUI_IMPL_OPENGL_MAY_HAVE_VTX_OFFSET {
                if (bd.GlVersion >= 320) {
                    itype : GLenum = GL_UNSIGNED_INT;
                    if size_of(ImGui.ImDrawIdx) == 2 itype = GL_UNSIGNED_SHORT;

                    glDrawElementsBaseVertex(GL_TRIANGLES, xx pcmd.ElemCount, itype, xx (pcmd.IdxOffset * size_of(ImGui.ImDrawIdx)), xx pcmd.VtxOffset);
                } else {
                    itype : GLenum = GL_UNSIGNED_INT;
                    if size_of(ImGui.ImDrawIdx) == 2 itype = GL_UNSIGNED_SHORT;

                    glDrawElements(GL_TRIANGLES, xx pcmd.ElemCount, itype, xx (pcmd.IdxOffset * size_of(ImGui.ImDrawIdx)));
                }
} else {
                itype : GLenum = GL_UNSIGNED_INT;
                if size_of(ImGui.ImDrawIdx) == 2 itype = GL_UNSIGNED_SHORT;
                glDrawElements(GL_TRIANGLES, xx pcmd.ElemCount, itype, xx (pcmd.IdxOffset * size_of(ImGui.ImDrawIdx)));
}
            }
        }
    }
    }

    // Destroy the temporary VAO
#if IMGUI_IMPL_OPENGL_USE_VERTEX_ARRAY {
    glDeleteVertexArrays(1, *vertex_array_object);
}

    // Restore modified GL state
    glUseProgram(last_program);
    glBindTexture(GL_TEXTURE_2D, last_texture);
#if IMGUI_IMPL_OPENGL_MAY_HAVE_BIND_SAMPLER {
    if (bd.GlVersion >= 330)
        glBindSampler(0, last_sampler);
}
    glActiveTexture(last_active_texture);
#if IMGUI_IMPL_OPENGL_USE_VERTEX_ARRAY {
    glBindVertexArray(last_vertex_array_object);
}
    glBindBuffer(GL_ARRAY_BUFFER, last_array_buffer);
    glBlendEquationSeparate(last_blend_equation_rgb, last_blend_equation_alpha);
    glBlendFuncSeparate(last_blend_src_rgb, last_blend_dst_rgb, last_blend_src_alpha, last_blend_dst_alpha);
    if (last_enable_blend)        glEnable(GL_BLEND);        else glDisable(GL_BLEND);
    if (last_enable_cull_face)    glEnable(GL_CULL_FACE);    else glDisable(GL_CULL_FACE);
    if (last_enable_depth_test)   glEnable(GL_DEPTH_TEST);   else glDisable(GL_DEPTH_TEST);
    if (last_enable_stencil_test) glEnable(GL_STENCIL_TEST); else glDisable(GL_STENCIL_TEST);
    if (last_enable_scissor_test) glEnable(GL_SCISSOR_TEST); else glDisable(GL_SCISSOR_TEST);
#if IMGUI_IMPL_OPENGL_MAY_HAVE_PRIMITIVE_RESTART {
    if (bd.GlVersion >= 310) { if (last_enable_primitive_restart) glEnable(GL_PRIMITIVE_RESTART); else glDisable(GL_PRIMITIVE_RESTART); }
}

#if IMGUI_IMPL_HAS_POLYGON_MODE {
    glPolygonMode(GL_FRONT_AND_BACK, xx last_polygon_mode[0]);
}
    glViewport(last_viewport[0], last_viewport[1], xx last_viewport[2], xx last_viewport[3]);
    glScissor(last_scissor_box[0], last_scissor_box[1], xx last_scissor_box[2], xx last_scissor_box[3]);
}

ImGui_ImplOpenGL3_CreateFontsTexture :: () -> bool
{
    io := ImGui.GetIO();
    bd := ImGui_ImplOpenGL3_GetBackendData();

    // Build texture atlas
    pixels : *u8;
    width, height : s32;
    io.Fonts.GetTexDataAsRGBA32(io.Fonts, *pixels, *width, *height);   // Load as RGBA 32-bit (75% of the memory is wasted, but default font is so small) because it is more likely to be compatible with user's existing shaders. If your ImTextureId represent a higher-level concept than just a GL texture id, consider calling GetTexDataAsAlpha8() instead to save on GPU memory.

    // Upload texture to graphics system
    last_texture : GLint;
    glGetIntegerv(GL_TEXTURE_BINDING_2D, xx *last_texture);
    glGenTextures(1, *bd.FontTexture);
    glBindTexture(GL_TEXTURE_2D, bd.FontTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    // glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);  // Not on WebGL/ES
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, xx width, xx height, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);

    // Store our identifier
    io.Fonts.TexID = xx bd.FontTexture;

    // Restore state
    glBindTexture(GL_TEXTURE_2D, xx last_texture);

    return true;
}

ImGui_ImplOpenGL3_DestroyFontsTexture :: ()
{
    io := ImGui.GetIO();
    bd := ImGui_ImplOpenGL3_GetBackendData();
    if bd.FontTexture
    {
        glDeleteTextures(1, *bd.FontTexture);
        io.Fonts.TexID = null;
        bd.FontTexture = 0;
    }
}

#scope_file

// If you get an error please report on github. You may try different GL context version or GLSL version. See GL<>GLSL version table at the top of this file.
CheckShader :: (handle : GLuint, desc : *u8) -> bool
{
    bd := ImGui_ImplOpenGL3_GetBackendData();
    status, log_length : GLint;
    glGetShaderiv(handle, GL_COMPILE_STATUS, *status);
    glGetShaderiv(handle, GL_INFO_LOG_LENGTH, *log_length);
    if xx status == GL_FALSE
        print("ERROR: ImGui_ImplOpenGL3_CreateDeviceObjects: failed to compile %! With GLSL: %\n", to_string(desc), bd.GlslVersionString);
    if (log_length > 1)
    {
        buf : [..]u8;
        defer array_reset(*buf);
        array_resize(*buf, log_length + 1);
        glGetShaderInfoLog(handle, xx log_length, null, buf.data);
        print("%\n", cast(string)buf);
    }
    return xx status == GL_TRUE;
}

// If you get an error please report on GitHub. You may try different GL context version or GLSL version.
CheckProgram :: (handle : GLuint, desc : *u8) -> bool
{
    bd := ImGui_ImplOpenGL3_GetBackendData();
    status, log_length : GLint;
    glGetProgramiv(handle, GL_LINK_STATUS, *status);
    glGetProgramiv(handle, GL_INFO_LOG_LENGTH, *log_length);
    if xx status == GL_FALSE
        print("ERROR: ImGui_ImplOpenGL3_CreateDeviceObjects: failed to link %! With GLSL: %\n", to_string(desc), bd.GlslVersionString);
    if (log_length > 1)
    {
        buf : [..]u8;
        defer array_reset(*buf);
        array_resize(*buf, log_length + 1);
        glGetProgramInfoLog(handle, xx log_length, null, buf.data);
        print("%\n", cast(string)buf);
    }
    return xx status == GL_TRUE;
}

ImGui_ImplOpenGL3_CreateDeviceObjects :: () -> bool
{
    bd := ImGui_ImplOpenGL3_GetBackendData();

    // Backup GL state
    last_texture, last_array_buffer : GLint;
    glGetIntegerv(GL_TEXTURE_BINDING_2D, *last_texture);
    glGetIntegerv(GL_ARRAY_BUFFER_BINDING, *last_array_buffer);
#if IMGUI_IMPL_OPENGL_USE_VERTEX_ARRAY {
    last_vertex_array : GLint;
    glGetIntegerv(GL_VERTEX_ARRAY_BINDING, *last_vertex_array);
}

    vertex_shader :: #string __GLSL
#version 130
uniform mat4 ProjMtx;
in vec2 Position;
in vec2 UV;
in vec4 Color;
out vec2 Frag_UV;
out vec4 Frag_Color;
void main()
{
    Frag_UV = UV;
    Frag_Color = Color;
    gl_Position = ProjMtx * vec4(Position.xy,0,1);
}
__GLSL;

    fragment_shader :: #string __GLSL
#version 130
uniform sampler2D Texture;
in vec2 Frag_UV;
in vec4 Frag_Color;
out vec4 Out_Color;
void main()
{
    Out_Color = Frag_Color * texture(Texture, Frag_UV.st);
}
__GLSL;

    // Create shaders
    vert_handle := glCreateShader(GL_VERTEX_SHADER);
    _glShaderSource(vert_handle, vertex_shader);
    glCompileShader(vert_handle);
    CheckShader(vert_handle, "vertex shader");

    frag_handle := glCreateShader(GL_FRAGMENT_SHADER);
    _glShaderSource(frag_handle, fragment_shader);
    glCompileShader(frag_handle);
    CheckShader(frag_handle, "fragment shader");

    // Link
    bd.ShaderHandle = glCreateProgram();
    glAttachShader(bd.ShaderHandle, vert_handle);
    glAttachShader(bd.ShaderHandle, frag_handle);
    glLinkProgram(bd.ShaderHandle);
    CheckProgram(bd.ShaderHandle, "shader program");

    glDetachShader(bd.ShaderHandle, vert_handle);
    glDetachShader(bd.ShaderHandle, frag_handle);
    glDeleteShader(vert_handle);
    glDeleteShader(frag_handle);

    bd.AttribLocationTex = glGetUniformLocation(bd.ShaderHandle, "Texture");
    bd.AttribLocationProjMtx = glGetUniformLocation(bd.ShaderHandle, "ProjMtx");
    bd.AttribLocationVtxPos = xx glGetAttribLocation(bd.ShaderHandle, "Position");
    bd.AttribLocationVtxUV = xx glGetAttribLocation(bd.ShaderHandle, "UV");
    bd.AttribLocationVtxColor = xx glGetAttribLocation(bd.ShaderHandle, "Color");

    // Create buffers
    glGenBuffers(1, *bd.VboHandle);
    glGenBuffers(1, *bd.ElementsHandle);

    ImGui_ImplOpenGL3_CreateFontsTexture();

    // Restore modified GL state
    glBindTexture(GL_TEXTURE_2D, xx last_texture);
    glBindBuffer(GL_ARRAY_BUFFER, xx last_array_buffer);
#if IMGUI_IMPL_OPENGL_USE_VERTEX_ARRAY {
    glBindVertexArray(xx last_vertex_array);
}

    return true;
}

ImGui_ImplOpenGL3_DestroyDeviceObjects :: ()
{
    bd := ImGui_ImplOpenGL3_GetBackendData();
    if (bd.VboHandle)      { glDeleteBuffers(1, *bd.VboHandle); bd.VboHandle = 0; }
    if (bd.ElementsHandle) { glDeleteBuffers(1, *bd.ElementsHandle); bd.ElementsHandle = 0; }
    if (bd.ShaderHandle)   { glDeleteProgram(bd.ShaderHandle); bd.ShaderHandle = 0; }
    ImGui_ImplOpenGL3_DestroyFontsTexture();
}


#scope_file

ImGui :: #import "ImGui";
#import "GL";
