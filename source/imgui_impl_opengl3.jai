// dear imgui: Renderer Backend for modern OpenGL with shaders / programmatic pipeline
// Ported to Jai from imgui_impl_opengl3.cpp (imgui 1.92.7)
// - Desktop GL: 2.x 3.x 4.x

// Implemented features:
//  [X] Renderer: User texture binding. Use 'GLuint' OpenGL texture identifier as ImTextureID.
//  [x] Renderer: Desktop GL only: Support for large meshes (64k+ vertices) with 16-bit indices.
//  [X] Renderer: Texture updates support for dynamic font atlas (ImGuiBackendFlags_RendererHasTextures).

IMGUI_IMPL_OPENGL_USE_VERTEX_ARRAY       :: true;
IMGUI_IMPL_HAS_POLYGON_MODE              :: true;
IMGUI_IMPL_OPENGL_MAY_HAVE_VTX_OFFSET   :: true;
IMGUI_IMPL_OPENGL_MAY_HAVE_BIND_SAMPLER :: true;
IMGUI_IMPL_OPENGL_MAY_HAVE_PRIMITIVE_RESTART :: true;
IMGUI_IMPL_OPENGL_MAY_HAVE_EXTENSIONS   :: true;

// OpenGL Data
ImGui_ImplOpenGL3_Data :: struct
{
    GlVersion :              GLuint;  // e.g. 320 for GL 3.2
    GlslVersionString :      string;
    ShaderHandle :           GLuint;
    AttribLocationTex :      GLint;
    AttribLocationProjMtx :  GLint;
    AttribLocationVtxPos :   GLuint;
    AttribLocationVtxUV :    GLuint;
    AttribLocationVtxColor : GLuint;
    VboHandle, ElementsHandle : u32;
    HasClipOrigin :          bool;
    MaxTextureSize :         GLint;
};

#scope_file

ImGui_ImplOpenGL3_GetBackendData :: () -> *ImGui_ImplOpenGL3_Data
{
    return ifx ImGui.GetCurrentContext() then cast(*ImGui_ImplOpenGL3_Data)ImGui.GetIO().BackendRendererUserData else null;
}

#scope_export

ImGui_ImplOpenGL3_Init :: (glsl_version : *u8 = null) -> bool
{
    io := ImGui.GetIO();
    assert(io.BackendRendererUserData == null); // Already initialized a renderer backend!

    bd := New(ImGui_ImplOpenGL3_Data);
    io.BackendRendererUserData = cast(*void)bd;
    io.BackendRendererName = "imgui_impl_opengl3";

    // Query GL version
    major : GLint = 0;
    minor : GLint = 0;
    glGetIntegerv(GL_MAJOR_VERSION, *major);
    glGetIntegerv(GL_MINOR_VERSION, *minor);
    assert((major == 0 && minor == 0) == false);
    bd.GlVersion = cast(GLuint)(major * 100 + minor * 10);

    // Query max texture size and register with platform_io
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, *bd.MaxTextureSize);
    platform_io := ImGui.GetPlatformIO();
    platform_io.Renderer_TextureMaxWidth  = bd.MaxTextureSize;
    platform_io.Renderer_TextureMaxHeight = bd.MaxTextureSize;

#if IMGUI_IMPL_OPENGL_MAY_HAVE_VTX_OFFSET {
    if (bd.GlVersion >= 320)
        io.BackendFlags_ |= ImGui.BackendFlags.RendererHasVtxOffset;
}
    // Signal that we handle dynamic font atlas texture creation/update/destroy
    io.BackendFlags_ |= ImGui.BackendFlags.RendererHasTextures;

    if (glsl_version == "")
        glsl_version = "#version 130";
    bd.GlslVersionString = to_string(glsl_version);
    assert(bd.GlslVersionString == "#version 130", "Jai port only includes glsl version 130 shader");

    current_texture : GLint;
    glGetIntegerv(GL_TEXTURE_BINDING_2D, *current_texture);

    bd.HasClipOrigin = (bd.GlVersion >= 450);
#if IMGUI_IMPL_OPENGL_MAY_HAVE_EXTENSIONS {
    num_extensions : GLint = 0;
    glGetIntegerv(GL_NUM_EXTENSIONS, *num_extensions);
    for i : 0..num_extensions-1
    {
        extension : *u8 = cast(*u8) glGetStringi(GL_EXTENSIONS, xx i);
        if extension != null {
            extension_string := to_string(extension);
            if extension_string == "GL_ARB_clip_control"
                bd.HasClipOrigin = true;
        }
    }
}

    return true;
}

ImGui_ImplOpenGL3_Shutdown :: ()
{
    bd := ImGui_ImplOpenGL3_GetBackendData();
    assert(bd != null);
    io := ImGui.GetIO();

    ImGui_ImplOpenGL3_DestroyDeviceObjects();
    io.BackendRendererName = null;
    io.BackendRendererUserData = null;
    io.BackendFlags_ &= ~(ImGui.BackendFlags.RendererHasVtxOffset | ImGui.BackendFlags.RendererHasTextures);
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

// Update (create/update/destroy) a single texture managed by imgui's dynamic font atlas.
ImGui_ImplOpenGL3_UpdateTexture :: (tex : *ImGui.ImTextureData)
{
    if tex.Status == {
    case .WantCreate;
        // Create and upload new texture to graphics system
        assert(tex.TexID == ImGui.ImTextureID_Invalid && tex.BackendUserData == null);
        assert(tex.Format == .RGBA32);
        pixels := tex.Pixels;

        last_texture : GLint;
        glGetIntegerv(GL_TEXTURE_BINDING_2D, *last_texture);

        gl_texture_id : GLuint;
        glGenTextures(1, *gl_texture_id);
        glBindTexture(GL_TEXTURE_2D, gl_texture_id);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, xx tex.Width, xx tex.Height, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);

        tex.TexID = xx gl_texture_id;
        tex.Status = .OK;

        glBindTexture(GL_TEXTURE_2D, xx last_texture);

    case .WantUpdates;
        last_texture : GLint;
        glGetIntegerv(GL_TEXTURE_BINDING_2D, *last_texture);

        gl_tex_id := cast(GLuint) xx tex.TexID;
        glBindTexture(GL_TEXTURE_2D, gl_tex_id);
        // Upload updated regions
        glPixelStorei(GL_UNPACK_ROW_LENGTH, xx tex.Width);
        for i : 0..tex.Updates.Size-1 {
            r := tex.Updates.Data[i];
            glTexSubImage2D(GL_TEXTURE_2D, 0, xx r.x, xx r.y, xx r.w, xx r.h, GL_RGBA, GL_UNSIGNED_BYTE, tex.Pixels + (r.x + r.y * tex.Width) * tex.BytesPerPixel);
        }
        glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
        tex.Status = .OK;

        glBindTexture(GL_TEXTURE_2D, xx last_texture);

    case .WantDestroy;
        if tex.TexID != ImGui.ImTextureID_Invalid {
            gl_tex_id := cast(GLuint) xx tex.TexID;
            glDeleteTextures(1, *gl_tex_id);
        }
        tex.TexID = ImGui.ImTextureID_Invalid;
        tex.Status = .Destroyed;
    }
}

ImGui_ImplOpenGL3_SetupRenderState :: (draw_data : *ImGui.ImDrawData, fb_width : s32, fb_height : s32, vertex_array_object : GLuint)
{
    bd := ImGui_ImplOpenGL3_GetBackendData();

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

    glViewport(0, 0, cast(GLsizei)fb_width, cast(GLsizei)fb_height);
    L : float = draw_data.DisplayPos.x;
    R : float = draw_data.DisplayPos.x + draw_data.DisplaySize.x;
    T : float = draw_data.DisplayPos.y;
    B : float = draw_data.DisplayPos.y + draw_data.DisplaySize.y;
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
        glBindSampler(0, 0);
}

#if IMGUI_IMPL_OPENGL_USE_VERTEX_ARRAY {
    glBindVertexArray(vertex_array_object);
}

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

ImGui_ImplOpenGL3_RenderDrawData :: (draw_data : *ImGui.ImDrawData)
{
    fb_width : s32 = xx (draw_data.DisplaySize.x * draw_data.FramebufferScale.x);
    fb_height : s32 = xx (draw_data.DisplaySize.y * draw_data.FramebufferScale.y);
    if (fb_width <= 0 || fb_height <= 0)
        return;

    bd := ImGui_ImplOpenGL3_GetBackendData();

    // Process texture create/update/destroy requests from the dynamic font atlas.
    if draw_data.Textures != null {
        for i : 0..draw_data.Textures.Size-1 {
            tex := draw_data.Textures.Data[i];
            if tex.Status != .OK
                ImGui_ImplOpenGL3_UpdateTexture(tex);
        }
    }

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

    vertex_array_object : GLuint;
#if IMGUI_IMPL_OPENGL_USE_VERTEX_ARRAY {
    glGenVertexArrays(1, *vertex_array_object);
}
    ImGui_ImplOpenGL3_SetupRenderState(draw_data, fb_width, fb_height, vertex_array_object);

    clip_off := draw_data.DisplayPos;
    clip_scale := draw_data.FramebufferScale;

    push_context {
    for n : 0..draw_data.CmdListsCount - 1 {
        cmd_list := draw_data.CmdLists.Data[n];

        glBufferData(GL_ARRAY_BUFFER,         cast(GLsizeiptr)cmd_list.VtxBuffer.Size * size_of(ImGui.ImDrawVert), xx cmd_list.VtxBuffer.Data, GL_STREAM_DRAW);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, cast(GLsizeiptr)cmd_list.IdxBuffer.Size * size_of(ImGui.ImDrawIdx),  xx cmd_list.IdxBuffer.Data, GL_STREAM_DRAW);

        for cmd_i : 0..cmd_list.CmdBuffer.Size - 1 {
            pcmd := *cmd_list.CmdBuffer.Data[cmd_i];
            if pcmd.UserCallback != null
            {
                pcmd.UserCallback(cmd_list, pcmd);
            }
            else
            {
                clip_min := ImGui.ImVec2.{(pcmd.ClipRect.x - clip_off.x) * clip_scale.x, (pcmd.ClipRect.y - clip_off.y) * clip_scale.y};
                clip_max := ImGui.ImVec2.{(pcmd.ClipRect.z - clip_off.x) * clip_scale.x, (pcmd.ClipRect.w - clip_off.y) * clip_scale.y};
                if (clip_max.x < clip_min.x || clip_max.y < clip_min.y)
                    continue;

                glScissor(xx clip_min.x, xx (fb_height - clip_max.y), xx (clip_max.x - clip_min.x), xx (clip_max.y - clip_min.y));

                // Resolve the texture ID from the draw command's TexRef.
                tex_id : ImGui.ImTextureID = ifx pcmd.TexRef._TexData then pcmd.TexRef._TexData.TexID else pcmd.TexRef._TexID;
                glBindTexture(GL_TEXTURE_2D, xx tex_id);

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

#if IMGUI_IMPL_OPENGL_USE_VERTEX_ARRAY {
    glDeleteVertexArrays(1, *vertex_array_object);
}

    // Restore GL state
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

#scope_file

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

    vert_handle := glCreateShader(GL_VERTEX_SHADER);
    _glShaderSource(vert_handle, vertex_shader);
    glCompileShader(vert_handle);
    CheckShader(vert_handle, "vertex shader");

    frag_handle := glCreateShader(GL_FRAGMENT_SHADER);
    _glShaderSource(frag_handle, fragment_shader);
    glCompileShader(frag_handle);
    CheckShader(frag_handle, "fragment shader");

    bd.ShaderHandle = glCreateProgram();
    glAttachShader(bd.ShaderHandle, vert_handle);
    glAttachShader(bd.ShaderHandle, frag_handle);
    glLinkProgram(bd.ShaderHandle);
    CheckProgram(bd.ShaderHandle, "shader program");

    glDetachShader(bd.ShaderHandle, vert_handle);
    glDetachShader(bd.ShaderHandle, frag_handle);
    glDeleteShader(vert_handle);
    glDeleteShader(frag_handle);

    bd.AttribLocationTex      = glGetUniformLocation(bd.ShaderHandle, "Texture");
    bd.AttribLocationProjMtx  = glGetUniformLocation(bd.ShaderHandle, "ProjMtx");
    bd.AttribLocationVtxPos   = xx glGetAttribLocation(bd.ShaderHandle, "Position");
    bd.AttribLocationVtxUV    = xx glGetAttribLocation(bd.ShaderHandle, "UV");
    bd.AttribLocationVtxColor = xx glGetAttribLocation(bd.ShaderHandle, "Color");

    glGenBuffers(1, *bd.VboHandle);
    glGenBuffers(1, *bd.ElementsHandle);

    // Restore GL state
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
}


#scope_file

ImGui :: #import "ImGui";
#import "GL";
