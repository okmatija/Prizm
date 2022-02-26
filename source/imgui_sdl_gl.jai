
#import "Basic";
ImGui :: #import "ImGui";
#import "SDL";
#import "Math";
#import "GL";

// Data
g_Time: u64 = 0;
g_MousePressed := bool.[false, false, false];
g_MouseWheel: float = 0.0;
g_FontTexture: GLuint = 0;
g_ShaderHandle: GLuint = 0;
g_VertHandle: GLuint = 0;
g_FragHandle: GLuint = 0;
g_AttribLocationTex: GLint = 0;
g_AttribLocationProjMtx: GLint = 0;
g_AttribLocationPosition: GLuint = 0;
g_AttribLocationUV: GLuint = 0;
g_AttribLocationColor: GLuint = 0;
g_VboHandle: GLuint = 0;
g_VaoHandle: GLuint = 0;
g_ElementsHandle: GLuint = 0;

cursor_arrow: *SDL_Cursor;
cursor_text_input: *SDL_Cursor;
cursor_move: *SDL_Cursor;
cursor_resize_ns: *SDL_Cursor;
cursor_resize_ew: *SDL_Cursor;
cursor_resize_nesw: *SDL_Cursor;
cursor_resize_nwse: *SDL_Cursor;


// This is the main rendering function that you have to implement and provide to ImGui (via setting up 'RenderDrawListsFn' in the ImGuiIO structure)
// Note that this implementation is little overcomplicated because we are saving/setting up/restoring every OpenGL state explicitly, in order to be able to run within any OpenGL engine that doesn't do so. 
// If text or lines are blurry when integrating ImGui in your engine: in your Render function, try translating your projection matrix by (0.5f,0.5f) or (0.375f,0.375f)
ImGui_ImplSdl_RenderDrawLists :: (draw_data: *ImGui.ImDrawData) #c_call {
    // @@ Watch out, we don't have a context here!

    // Avoid rendering when minimized, scale coordinates for retina displays (screen coordinates != framebuffer coordinates)
    io := ImGui.GetIO();
    fb_width := (io.DisplaySize.x * io.DisplayFramebufferScale.x);
    fb_height := (io.DisplaySize.y * io.DisplayFramebufferScale.y);
    if fb_width == 0 || fb_height == 0 return;
    draw_data.ScaleClipRects(draw_data, *io.DisplayFramebufferScale);

    // Backup GL state
    last_active_texture: GLenum;        glGetIntegerv(GL_ACTIVE_TEXTURE, xx *last_active_texture);
    last_program: GLuint;               glGetIntegerv(GL_CURRENT_PROGRAM, xx *last_program);
    last_texture: GLuint;               glGetIntegerv(GL_TEXTURE_BINDING_2D, xx *last_texture);
    last_sampler: GLuint;               glGetIntegerv(GL_SAMPLER_BINDING, xx *last_sampler);
    last_array_buffer: GLuint;          glGetIntegerv(GL_ARRAY_BUFFER_BINDING, xx *last_array_buffer);
    last_element_array_buffer: GLuint;  glGetIntegerv(GL_ELEMENT_ARRAY_BUFFER_BINDING, xx *last_element_array_buffer);
    last_vertex_array: GLuint;          glGetIntegerv(GL_VERTEX_ARRAY_BINDING, xx *last_vertex_array);
    last_polygon_mode: [2]GLuint;       glGetIntegerv(GL_POLYGON_MODE, xx last_polygon_mode.data);
    last_viewport: [4]GLint;            glGetIntegerv(GL_VIEWPORT, last_viewport.data);
    last_scissor_box : [4]GLint;        glGetIntegerv(GL_SCISSOR_BOX, last_scissor_box.data);
    last_blend_src_rgb: GLenum;         glGetIntegerv(GL_BLEND_SRC_RGB, xx *last_blend_src_rgb);
    last_blend_dst_rgb: GLenum;         glGetIntegerv(GL_BLEND_DST_RGB, xx *last_blend_dst_rgb);
    last_blend_src_alpha: GLenum;       glGetIntegerv(GL_BLEND_SRC_ALPHA, xx *last_blend_src_alpha);
    last_blend_dst_alpha: GLenum;       glGetIntegerv(GL_BLEND_DST_ALPHA, xx *last_blend_dst_alpha);
    last_blend_equation_rgb: GLenum;    glGetIntegerv(GL_BLEND_EQUATION_RGB, xx *last_blend_equation_rgb);
    last_blend_equation_alpha: GLenum;  glGetIntegerv(GL_BLEND_EQUATION_ALPHA, xx *last_blend_equation_alpha);
    last_enable_blend :=                glIsEnabled(GL_BLEND);
    last_enable_cull_face :=            glIsEnabled(GL_CULL_FACE);
    last_enable_depth_test :=           glIsEnabled(GL_DEPTH_TEST);
    last_enable_scissor_test :=         glIsEnabled(GL_SCISSOR_TEST);

    // Setup render state: alpha-blending enabled, no face culling, no depth testing, scissor enabled, polygon fill
    glActiveTexture(GL_TEXTURE0);
    glEnable(GL_BLEND);
    glBlendEquation(GL_FUNC_ADD);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glDisable(GL_CULL_FACE);
    glDisable(GL_DEPTH_TEST);
    glEnable(GL_SCISSOR_TEST);
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

    // Setup viewport, orthographic projection matrix
    glViewport(0, 0, xx fb_width, xx fb_height);

    new_context: Context;
    push_context new_context {
        ortho_projection := orthographic_projection_matrix(0, io.DisplaySize.x, io.DisplaySize.y, 0, 0, 1);
        ortho_projection = transpose(ortho_projection);

        glUseProgram(g_ShaderHandle);
        glUniform1i(g_AttribLocationTex, 0);
        glUniformMatrix4fv(g_AttribLocationProjMtx, 1, GL_FALSE, xx *ortho_projection);
        glBindVertexArray(g_VaoHandle);
        glBindSampler(0, 0); // Rely on combined texture/sampler state.

        // Render command lists
        for n: 0..draw_data.CmdListsCount-1 {
            cmd_list := draw_data.CmdLists[n];
            idx_buffer_offset : *ImGui.ImDrawIdx;

            glBindBuffer(GL_ARRAY_BUFFER, g_VboHandle);
            glBufferData(GL_ARRAY_BUFFER, cmd_list.VtxBuffer.Size * size_of(ImGui.ImDrawVert), cmd_list.VtxBuffer.Data, GL_STREAM_DRAW);

            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, g_ElementsHandle);
            glBufferData(GL_ELEMENT_ARRAY_BUFFER, cmd_list.IdxBuffer.Size * size_of(ImGui.ImDrawIdx), cmd_list.IdxBuffer.Data, GL_STREAM_DRAW);

            for cmd_i: 0..cmd_list.CmdBuffer.Size-1 {
                pcmd := *cmd_list.CmdBuffer.Data[cmd_i];
                if pcmd.UserCallback {
                    pcmd.UserCallback(cmd_list, pcmd);
                }
                else {
                    glBindTexture(GL_TEXTURE_2D, xx pcmd.TextureId);
                    glScissor(xx pcmd.ClipRect.x, xx (fb_height - pcmd.ClipRect.w), xx (pcmd.ClipRect.z - pcmd.ClipRect.x), xx (pcmd.ClipRect.w - pcmd.ClipRect.y));
                    
                    glDrawElements(GL_TRIANGLES, pcmd.ElemCount, GL_UNSIGNED_SHORT, idx_buffer_offset);
                }
                idx_buffer_offset += pcmd.ElemCount;
            }
        }

        // Restore modified GL state
        glUseProgram(last_program);
        glBindTexture(GL_TEXTURE_2D, last_texture);
        glBindSampler(0, last_sampler);
        glActiveTexture(last_active_texture);
        glBindVertexArray(last_vertex_array);
        glBindBuffer(GL_ARRAY_BUFFER, last_array_buffer);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, last_element_array_buffer);
        glBlendEquationSeparate(last_blend_equation_rgb, last_blend_equation_alpha);
        glBlendFuncSeparate(last_blend_src_rgb, last_blend_dst_rgb, last_blend_src_alpha, last_blend_dst_alpha);
        if last_enable_blend        glEnable(GL_BLEND);         else glDisable(GL_BLEND);
        if last_enable_cull_face    glEnable(GL_CULL_FACE);     else glDisable(GL_CULL_FACE);
        if last_enable_depth_test   glEnable(GL_DEPTH_TEST);    else glDisable(GL_DEPTH_TEST);
        if last_enable_scissor_test glEnable(GL_SCISSOR_TEST);  else glDisable(GL_SCISSOR_TEST);
        glPolygonMode(GL_FRONT_AND_BACK, last_polygon_mode[0]);
        glViewport(last_viewport[0], last_viewport[1], xx last_viewport[2], xx last_viewport[3]);
        glScissor(last_scissor_box[0], last_scissor_box[1], xx last_scissor_box[2], xx last_scissor_box[3]);
    }
}

ImGui_ImplSdl_GetClipboardText :: (data: *void) -> *u8 #c_call {
    return SDL_GetClipboardText();
}

ImGui_ImplSdl_SetClipboardText :: (data: *void, text: *u8) #c_call {
    SDL_SetClipboardText(text);
}

// You can read the io.WantCaptureMouse, io.WantCaptureKeyboard flags to tell if dear imgui wants to use your inputs.
// - When io.WantCaptureMouse is true, do not dispatch mouse input data to your main application.
// - When io.WantCaptureKeyboard is true, do not dispatch keyboard input data to your main application.
// Generally you may always pass all inputs to dear imgui, and hide them from your application based on those two flags.
ImGui_ImplSdl_ProcessEvent :: (event: *SDL_Event) -> bool {
    io := ImGui.GetIO();
    if event.type == {
        case SDL_MOUSEWHEEL;
            if event.wheel.y > 0 g_MouseWheel = 1;
            if event.wheel.y < 0 g_MouseWheel = -1;
            return true;
        case SDL_MOUSEBUTTONDOWN;
            if event.button.button == SDL_BUTTON_LEFT   g_MousePressed[0] = true;
            if event.button.button == SDL_BUTTON_RIGHT  g_MousePressed[1] = true;
            if event.button.button == SDL_BUTTON_MIDDLE g_MousePressed[2] = true;
            return true;
        case SDL_TEXTINPUT;
            io.AddInputCharactersUTF8(io, xx event.text.text.data);
            return true;
        case SDL_KEYDOWN; #through;
        case SDL_KEYUP;
            //@@key := event.key.keysym.sym & ~SDLK_SCANCODE_MASK;
            key := event.key.keysym.sym & (xx ~(1<<30));
            io.KeysDown[key] = (event.type == SDL_KEYDOWN);
            kmod := SDL_GetModState();
            io.KeyShift = ((kmod & KMOD_SHIFT) != 0);
            io.KeyCtrl = ((kmod & KMOD_CTRL) != 0);
            io.KeyAlt = ((kmod & KMOD_ALT) != 0);
            io.KeySuper = ((kmod & KMOD_GUI) != 0);
            return true;
    }
    return false;
}

ImGui_ImplSdl_CreateFontsTexture :: () -> bool {
    // Build texture atlas
    io := ImGui.GetIO();
    pixels: *u8;
    width, height: s32;
    bpp: s32;
    io.Fonts.GetTexDataAsAlpha8(io.Fonts, *pixels, *width, *height, *bpp);
    //io.Fonts.GetTexDataAsRGBA32(io.Fonts, *pixels, *width, *height);

    // Upload texture to graphics system
    last_texture: GLuint;
    glGetIntegerv(GL_TEXTURE_BINDING_2D, xx *last_texture);

    glGenTextures(1, *g_FontTexture);
    glBindTexture(GL_TEXTURE_2D, g_FontTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    //glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, xx width, xx height, 0, GL_RED, GL_UNSIGNED_BYTE, pixels);
    //glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, xx width, xx height, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);

    // Store our identifier
    io.Fonts.TexID = xx g_FontTexture;

    // Restore state
    glBindTexture(GL_TEXTURE_2D, last_texture);

    return true;
}

ImGui_ImplSdl_CreateDeviceObjects ::() -> bool {
    // Backup GL state
    last_texture, last_array_buffer, last_vertex_array: GLuint;
    glGetIntegerv(GL_TEXTURE_BINDING_2D, xx *last_texture);
    glGetIntegerv(GL_ARRAY_BUFFER_BINDING, xx *last_array_buffer);
    glGetIntegerv(GL_VERTEX_ARRAY_BINDING, xx *last_vertex_array);

    vertex_shader := #string END
        #version 330
        uniform mat4 ProjMtx;
        in vec2 Position;
        in vec2 UV;
        in vec4 Color;
        out vec2 Frag_UV;
        out vec4 Frag_Color;
        void main() {
           Frag_UV = UV;
           Frag_Color = Color;
           gl_Position = ProjMtx * vec4(Position.xy,0,1);
        }
    END

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

    g_ShaderHandle = glCreateProgram();
    g_VertHandle = glCreateShader(GL_VERTEX_SHADER);
    g_FragHandle = glCreateShader(GL_FRAGMENT_SHADER);
    _glShaderSource(g_VertHandle, vertex_shader);
    _glShaderSource(g_FragHandle, fragment_shader);
    glCompileShader(g_VertHandle);
    glCompileShader(g_FragHandle);
    glAttachShader(g_ShaderHandle, g_VertHandle);
    glAttachShader(g_ShaderHandle, g_FragHandle);
    glLinkProgram(g_ShaderHandle);

    g_AttribLocationTex = glGetUniformLocation(g_ShaderHandle, "Texture");
    g_AttribLocationProjMtx = glGetUniformLocation(g_ShaderHandle, "ProjMtx");
    g_AttribLocationPosition = xx glGetAttribLocation(g_ShaderHandle, "Position");
    g_AttribLocationUV = xx glGetAttribLocation(g_ShaderHandle, "UV");
    g_AttribLocationColor = xx glGetAttribLocation(g_ShaderHandle, "Color");

    glGenBuffers(1, *g_VboHandle);
    glGenBuffers(1, *g_ElementsHandle);

    glGenVertexArrays(1, *g_VaoHandle);
    glBindVertexArray(g_VaoHandle);
    glBindBuffer(GL_ARRAY_BUFFER, g_VboHandle);
    glEnableVertexAttribArray(g_AttribLocationPosition);
    glEnableVertexAttribArray(xx g_AttribLocationUV);
    glEnableVertexAttribArray(xx g_AttribLocationColor);

    // @@ Is there a function to easily get the offset of a member?
    //ImDrawVert :: struct {
    //   pos: ImVec2;       // 0
    //   uv: ImVec2;        // 8
    //   col: s32;          // 16
    //}
    glVertexAttribPointer(g_AttribLocationPosition, 2, GL_FLOAT, GL_FALSE, size_of(ImGui.ImDrawVert), xx 0);
    glVertexAttribPointer(g_AttribLocationUV, 2, GL_FLOAT, GL_FALSE, size_of(ImGui.ImDrawVert), xx 8);
    glVertexAttribPointer(g_AttribLocationColor, 4, GL_UNSIGNED_BYTE, GL_TRUE, size_of(ImGui.ImDrawVert), xx 16);

    ImGui_ImplSdl_CreateFontsTexture();

    // Restore modified GL state
    glBindTexture(GL_TEXTURE_2D, last_texture);
    glBindBuffer(GL_ARRAY_BUFFER, last_array_buffer);
    glBindVertexArray(last_vertex_array);

    return true;
}


ImGui_ImplSdl_InvalidateDeviceObjects :: () {
    if g_FontTexture {
        glDeleteTextures(1, *g_FontTexture);
        ImGui.GetIO().Fonts.TexID = null;
        g_FontTexture = 0;
    }
}

ImGui_ImplSdl_Init :: (window: *SDL_Window) -> bool {
    io := ImGui.GetIO();
    io.KeyMap[ImGui.Key.Tab] = xx SDLK_TAB;                     // Keyboard mapping. ImGui will use those indices to peek into the io.KeyDown[] array.
    io.KeyMap[ImGui.Key.LeftArrow] = xx SDL_SCANCODE_LEFT;
    io.KeyMap[ImGui.Key.RightArrow] = xx SDL_SCANCODE_RIGHT;
    io.KeyMap[ImGui.Key.UpArrow] = xx SDL_SCANCODE_UP;
    io.KeyMap[ImGui.Key.DownArrow] = xx SDL_SCANCODE_DOWN;
    io.KeyMap[ImGui.Key.PageUp] = xx SDL_SCANCODE_PAGEUP;
    io.KeyMap[ImGui.Key.PageDown] = xx SDL_SCANCODE_PAGEDOWN;
    io.KeyMap[ImGui.Key.Home] = xx SDL_SCANCODE_HOME;
    io.KeyMap[ImGui.Key.End] = xx SDL_SCANCODE_END;
    io.KeyMap[ImGui.Key.Delete] = xx SDLK_DELETE;
    io.KeyMap[ImGui.Key.Backspace] = xx SDLK_BACKSPACE;
    io.KeyMap[ImGui.Key.Enter] = xx SDLK_RETURN;
    io.KeyMap[ImGui.Key.Escape] = xx SDLK_ESCAPE;
    io.KeyMap[ImGui.Key.A] = xx SDLK_a;
    io.KeyMap[ImGui.Key.C] = xx SDLK_c;
    io.KeyMap[ImGui.Key.V] = xx SDLK_v;
    io.KeyMap[ImGui.Key.X] = xx SDLK_x;
    io.KeyMap[ImGui.Key.Y] = xx SDLK_y;
    io.KeyMap[ImGui.Key.Z] = xx SDLK_z;

    io.SetClipboardTextFn = ImGui_ImplSdl_SetClipboardText;
    io.GetClipboardTextFn = ImGui_ImplSdl_GetClipboardText;
    io.ClipboardUserData = null;

    #if OS == .WINDOWS {
        wmInfo: SDL_SysWMinfo ;
        SDL_VERSION(*wmInfo.version);
        SDL_GetWindowWMInfo(window, *wmInfo);
        io.ImeWindowHandle = wmInfo.info.win.window;
    }

    cursor_arrow = SDL_CreateSystemCursor(.ARROW);
    cursor_text_input = SDL_CreateSystemCursor(.IBEAM);
    cursor_move = SDL_CreateSystemCursor(.HAND);
    cursor_resize_ns = SDL_CreateSystemCursor(.SIZENS);
    cursor_resize_ew = SDL_CreateSystemCursor(.SIZEWE);
    cursor_resize_nesw = SDL_CreateSystemCursor(.SIZENESW);
    cursor_resize_nwse = SDL_CreateSystemCursor(.SIZENWSE);

    return true;
}

ImGui_ImplSdl_Shutdown :: () {
    ImGui_ImplSdl_InvalidateDeviceObjects();
}

ImGui_ImplSdl_NewFrame :: (window: *SDL_Window) {
    if !g_FontTexture ImGui_ImplSdl_CreateDeviceObjects();

    io := ImGui.GetIO();

    // Setup display size (every frame to accommodate for window resizing)
    w, h: s32;
    display_w, display_h: s32;
    SDL_GetWindowSize(window, *w, *h);
    SDL_GL_GetDrawableSize(window, *display_w, *display_h);
    io.DisplaySize = make_vector2(xx w, xx h);
    io.DisplayFramebufferScale = make_vector2(cast(float) display_w / w, cast(float) display_h / h);

    // Setup time step
    frequency := SDL_GetPerformanceFrequency();
    current_time := SDL_GetPerformanceCounter();
    if g_Time > 0 {
        io.DeltaTime = cast(float)((cast(float64)(current_time - g_Time)) / frequency);
    } else {
        io.DeltaTime = (1.0/60.0);
    }
    // if (io.DeltaTime <= 0.0) {
    //     io.DeltaTime = (1.0/60.0);
    // }
    g_Time = current_time;

    // Setup inputs
    // (we already got mouse wheel, keyboard keys & characters from SDL_PollEvent())
    mx, my: s32;
    mouseMask := SDL_GetMouseState(*mx, *my);
    if (SDL_GetWindowFlags(window) & SDL_WINDOW_MOUSE_FOCUS) io.MousePos = make_vector2(xx mx, xx my);   // Mouse position, in pixels (set to -1,-1 if no mouse / on another screen, etc.)
    else 
        io.MousePos = make_vector2(-FLOAT32_MAX,-FLOAT32_MAX);

    io.MouseDown[0] = (g_MousePressed[0] || (mouseMask & SDL_BUTTON(SDL_BUTTON_LEFT)) != 0);      // If a mouse press event came, always pass it as "mouse held this frame", so we don't miss click-release events that are shorter than 1 frame.
    io.MouseDown[1] = (g_MousePressed[1] || (mouseMask & SDL_BUTTON(SDL_BUTTON_RIGHT)) != 0);
    io.MouseDown[2] = (g_MousePressed[2] || (mouseMask & SDL_BUTTON(SDL_BUTTON_MIDDLE)) != 0);
    g_MousePressed[0], g_MousePressed[1], g_MousePressed[2] = false, false, false;

    io.MouseWheel = g_MouseWheel;
    g_MouseWheel = 0.0;

    // Hide OS mouse cursor if ImGui is drawing it
    SDL_ShowCursor(xx (io.MouseDrawCursor == false));
}
