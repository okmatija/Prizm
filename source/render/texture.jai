//// Image: data stored in CPU memory (RAM)
//Image :: struct {
//    width : s32;
//    height : s32;
//    format : Pixel_Format;
//    data : *u8;
//}

// Texture: data stored in GPU memory (VRAM)
Texture :: struct {
    gl_handle : GLuint; // OpenGL texture id
    width : s32;
    height : s32;

    format : Pixel_Format;
    wrap : Texture_Wrap;
    filter : Texture_Filter;

    // @Cleanup Remove this when all KodaJai code is assimilated
    #place gl_handle;
    buffer : GLuint = ---;
}

texture_init :: (texture : *Texture, width : s32, height : s32, data : *void = null) {
    info : Pixel_Format_Info = get_pixel_format_info(texture.format);

    if !texture.gl_handle {
        glGenTextures(1, *texture.gl_handle);
    }

    glBindTexture(GL_TEXTURE_2D, texture.gl_handle);

    min_filter, mag_filter := get_gl_texture_filter(texture.filter);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, min_filter);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, mag_filter);

    wrap := get_gl_texture_wrap(texture.wrap);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, wrap);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, wrap);

    texture.width = width;
    texture.height = height;

    glTexImage2D(GL_TEXTURE_2D,
        0, // level
        info.gl_internal_format,
        cast(u32)texture.width,
        cast(u32)texture.height,
        0, // border
        info.gl_format,
        info.gl_type,
        data
    );

    //glBindTexture(GL_TEXTURE_2D, 0);
}

// TODOOOOO Refactor this to use a texture_init overload taking an image
make_opengl_texture :: (texture_data : *u8, texture_width : s32, texture_height : s32) -> GLuint {
    gl_handle : GLuint;

    // Create an OpenGL texture identifier
    glGenTextures(1, *gl_handle);
    glBindTexture(GL_TEXTURE_2D, gl_handle);

    // Setup filtering parameters for display
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); // This is required on WebGL for non power-of-two textures
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE); // Same

    // Upload pixels into texture
    //glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, cast(u32)texture_width, cast(u32)texture_height, 0, GL_RGBA, GL_UNSIGNED_BYTE, texture_data);

    return gl_handle;
}

load_texture_from_file :: (filename : string) -> Texture, bool {
    texture : Texture;

    // Load from file
    texture_data : *u8 = stbi_load(temp_c_string(filename), *texture.width, *texture.height, null, 4);
    defer stbi_image_free(texture_data);

    if texture_data == null {
        return texture, false;
    }

    texture.gl_handle = make_opengl_texture(texture_data, texture.width, texture.height);

    return texture, true;
}

load_texture_from_memory :: (buffer : []u8) -> Texture, bool {
    texture : Texture;

    channels : s32;

    texture_data : *u8 = stbi_load_from_memory(buffer.data, cast(s32)buffer.count, *texture.width, *texture.height, *channels, 4);

    texture.gl_handle = make_opengl_texture(texture_data, texture.width, texture.height);

    return texture, true;
}

get_gl_texture_filter :: (filter : Texture_Filter) -> (min : GLint, mag : GLint, is_mip_map : bool) {
    if #complete filter == {
    case .NEAREST;
        return GL_NEAREST, GL_NEAREST, false;
    case .NEAREST_MIPMAP;
        return GL_NEAREST_MIPMAP_LINEAR, GL_NEAREST, true;
    case .LINEAR;
        return GL_LINEAR, GL_LINEAR, false;
    case .LINEAR_MIPMAP;
        return GL_LINEAR_MIPMAP_LINEAR, GL_LINEAR, true;
    }
}

get_gl_texture_wrap :: (wrap : Texture_Wrap) -> GLint {
     if #complete wrap == {
    case .REPEAT;
        return GL_REPEAT;
    case .MIRRORED_REPEAT;
        return GL_MIRRORED_REPEAT;
    case .CLAMP_TO_EDGE;
        return GL_CLAMP_TO_EDGE;
    case .CLAMP_TO_BORDER;
        return GL_CLAMP_TO_BORDER;
    }
}

Texture_Filter :: enum {
    NEAREST; // OpenGL default?
    NEAREST_MIPMAP;
    LINEAR;
    LINEAR_MIPMAP;
}

Texture_Wrap :: enum {
    REPEAT; // OpenGL default?
    MIRRORED_REPEAT;
    CLAMP_TO_EDGE;
    CLAMP_TO_BORDER;
}

Pixel_Format :: enum {
    R8;
    R16;
    R16F;
    R32F;
    RG8;
    RG16;
    RG16F;
    RG32F;
    RGB8;
    RGB16;
    RGB16F;
    RGB32F;
    RGBA8;
    RGBA16;
    RGBA16F;
    RGBA32F;
    Depth;
    // DepthStencil;
};

Pixel_Format_Info :: struct {
    stride : int;
    component_count : int;
    flags : Flags;
    
    Flags :: enum_flags u8 {
        NONE  :: 0x0;
        FLOAT :: 0x1;
        //DEPTH :: 0x2; // Could be useful if we add more than one options for depth or add depth+stencil
    };

    // Specifies the data type of the pixel data (glTexImage2D)
    gl_type : GLenum;

    // Specifies the format of the pixel data (glTexImage2D)
    gl_format : GLenum;

    // Specifies the number of color components in the texture (glTexImage2D)
    gl_internal_format : GLint;
}

get_pixel_format_info :: (format : Pixel_Format) -> Pixel_Format_Info {
    using info : Pixel_Format_Info = ---;
    if #complete format == {
        case .R8;
            stride = 1;
            component_count = 1;
            gl_type = GL_UNSIGNED_BYTE;
            gl_format = GL_RED;
            gl_internal_format = GL_R8;

        case .R16;
            stride = 2;
            component_count = 1;
            gl_type = GL_UNSIGNED_SHORT;
            gl_format = GL_RED;
            gl_internal_format = GL_R16;

        case .R16F;
            stride = 2;
            component_count = 1;
            flags = Pixel_Format_Info.Flags.FLOAT;
            gl_type = GL_HALF_FLOAT;
            gl_format = GL_RED;
            gl_internal_format = GL_R16F;

        case .R32F;
            stride = 4;
            component_count = 1;
            flags = Pixel_Format_Info.Flags.FLOAT;
            gl_type = GL_FLOAT;
            gl_format = GL_RED;
            gl_internal_format = GL_R32F;

        case .RG8;
            stride = 2;
            component_count = 2;
            gl_type = GL_UNSIGNED_BYTE;
            gl_format = GL_RG;
            gl_internal_format = GL_RG8;

        case .RG16;
            stride = 4;
            component_count = 2;
            gl_type = GL_UNSIGNED_SHORT;
            gl_format = GL_RG;
            gl_internal_format = GL_RG16;

        case .RG16F;
            stride = 4;
            component_count = 2;
            flags = Pixel_Format_Info.Flags.FLOAT;
            gl_type = GL_HALF_FLOAT;
            gl_format = GL_RG;
            gl_internal_format = GL_RG16F;

        case .RG32F;
            stride = 8;
            component_count = 2;
            flags = Pixel_Format_Info.Flags.FLOAT;
            gl_type = GL_FLOAT;
            gl_format = GL_RG;
            gl_internal_format = GL_RG32F;

        case .RGB8;
            stride = 3;
            component_count = 3;
            gl_type = GL_UNSIGNED_BYTE;
            gl_format = GL_RGB;
            gl_internal_format = GL_RGB8;

        case .RGB16;
            stride = 6;
            component_count = 3;
            gl_type = GL_UNSIGNED_SHORT;
            gl_format = GL_RGB;
            gl_internal_format = GL_RGB16;

        case .RGB16F;
            stride = 6;
            component_count = 3;
            flags = Pixel_Format_Info.Flags.FLOAT;
            gl_type = GL_HALF_FLOAT;
            gl_format = GL_RGB;
            gl_internal_format = GL_RGB16F;

        case .RGB32F;
            stride = 12;
            component_count = 3;
            flags = Pixel_Format_Info.Flags.FLOAT;
            gl_type = GL_FLOAT;
            gl_format = GL_RGB;
            gl_internal_format = GL_RGB32F;

        case .RGBA8;
            stride = 4;
            component_count = 4;
            gl_type = GL_UNSIGNED_BYTE;
            gl_format = GL_RGBA;
            gl_internal_format = GL_RGBA8;

        case .RGBA16;
            stride = 8;
            component_count = 4;
            gl_type = GL_UNSIGNED_SHORT;
            gl_format = GL_RGBA;
            gl_internal_format = GL_RGBA16;

        case .RGBA16F;
            stride = 8;
            component_count = 4;
            flags = Pixel_Format_Info.Flags.FLOAT;
            gl_type = GL_HALF_FLOAT;
            gl_format = GL_RGBA;
            gl_internal_format = GL_RGBA16F;

        case .RGBA32F;
            stride = 16;
            component_count = 4;
            flags = Pixel_Format_Info.Flags.FLOAT;
            gl_type = GL_FLOAT;
            gl_format = GL_RGBA;
            gl_internal_format = GL_RGBA32F;

        case .Depth;
            stride = 4;
            component_count = 1;
            gl_type = GL_FLOAT;
            gl_format = GL_DEPTH_COMPONENT;
            gl_internal_format = GL_DEPTH_COMPONENT32F;

    }

    return info;
}


// From KodaJai Note: buffer == gl_handle in our code

/*

create_texture :: (bytes: [] u8, wrap: TextureWrap = .Clamp, interp: TextureInterp = .Linear, should_upload: bool = true) -> Texture {
    texture := load_data(bytes);
    texture.wrap = wrap;
    texture.interp = interp;

    if texture.data == null {
        print("Could not load texture.\n");
        return .{};
    }

    if should_upload {
        upload(*texture);
    }

    return texture;
}

create_texture :: (image: Image, wrap: TextureWrap = .Clamp, interp: TextureInterp = .Linear, should_upload: bool = true) -> Texture {
    if !image.pixels.data {
        print("Could not create texture.\n");
        return .{};
    }

    texture: Texture;
    texture.data = image.pixels.data;
    texture.width = xx image.width;
    texture.height = xx image.height;
    texture.format = image.format;
    texture.wrap = wrap;
    texture.interp = interp;

    if should_upload {
        upload(*texture);
    }

    return texture;
}

create_texture :: (width: int, height: int, format: PixelFormat = .RGBA8, wrap: TextureWrap = .Clamp, interp: TextureInterp = .Linear, shadow: bool = false, should_upload: bool = true) -> Texture {
    texture: Texture;
    texture.width = xx width;
    texture.height = xx height;
    texture.format = format;
    texture.wrap = wrap;
    texture.interp = interp;
    texture.shadow = shadow;

    if should_upload {
        upload(*texture);
    }

    return texture;
}

load_texture :: (path: string, wrap: TextureWrap = .Clamp, interp: TextureInterp = .Linear, should_upload: bool = true) -> Texture {
    file, success := read_entire_file(path, false);
    defer free(file);

    bytes: [] u8;
    bytes.data = file.data;
    bytes.count = file.count;

    return create_texture(bytes, wrap, interp, should_upload);
}

upload :: (texture: *Texture) {
    if texture.buffer {
        return;
    }
    
    wrap_format := get_gl_format(texture.wrap);
    interp_min_format := get_gl_min_format(texture.interp);
    interp_mag_format := get_gl_mag_format(texture.interp);
    has_mipmap := get_mipmap(texture.interp);

    texture_type: u32 = GL_TEXTURE_2D;
    if texture.multisample > 1 {
        texture_type = GL_TEXTURE_2D_MULTISAMPLE;
    }

    glGenTextures(1, *texture.buffer);
    glBindTexture(texture_type, texture.buffer);
    glTexParameteri(texture_type, GL_TEXTURE_WRAP_S, wrap_format);	
    glTexParameteri(texture_type, GL_TEXTURE_WRAP_T, wrap_format);
    glTexParameteri(texture_type, GL_TEXTURE_MIN_FILTER, interp_min_format);
    glTexParameteri(texture_type, GL_TEXTURE_MAG_FILTER, interp_mag_format);

    if texture.shadow {
        glTexParameteri(texture_type, GL_TEXTURE_COMPARE_MODE, GL_COMPARE_REF_TO_TEXTURE);
        glTexParameteri(texture_type, GL_TEXTURE_COMPARE_FUNC, GL_LEQUAL);
    }

    if texture.wrap == .Border {
        glTexParameterfv(texture_type, GL_TEXTURE_BORDER_COLOR, texture.border_color.component.data);
    }

    stride := get_stride(texture.format);

    four_divisible := (texture.width * stride) % 4 == 0;
    two_divisible := (texture.width * stride) % 2 == 0;
    pixel_store: s32;
    if four_divisible then pixel_store = 4;
    else if two_divisible then pixel_store = 2;
    else pixel_store = 1;

    glPixelStorei(GL_PACK_ALIGNMENT, pixel_store);
    glPixelStorei(GL_UNPACK_ALIGNMENT, pixel_store);

    gl_format := get_gl_format(texture.format);
    gl_internal_format := get_gl_internal_format(texture.format);
    gl_type := get_gl_type(texture.format);

    if texture.multisample > 1 {
        glTexImage2DMultisample(GL_TEXTURE_2D_MULTISAMPLE, cast(u32) texture.multisample, cast(u32) gl_internal_format, xx texture.width, xx texture.height, GL_TRUE);
    } else {
        glTexImage2D(GL_TEXTURE_2D, 0, gl_internal_format, xx texture.width, xx texture.height, 0, gl_format, gl_type, texture.data);
    }
    
    if has_mipmap {
        glGenerateMipmap(GL_TEXTURE_2D);
    }
}

unload :: (texture: *Texture) {
    if texture.buffer {
        glDeleteTextures(1, *texture.buffer);
        texture.buffer = 0;
    }
}

destroy :: (texture: Texture) {
    if texture.data {
        stbi_image_free(texture.data);
    }

    if texture.buffer {
        glDeleteTextures(1, *texture.buffer);
    }
}

TextureWrap :: enum {
    Clamp;
    Repeat;
    MirroredRepeat;
    Border;
}

get_gl_format :: (wrap: TextureWrap) -> s32 {
    if #complete wrap == {
        case .Clamp;
            return GL_CLAMP_TO_EDGE;
        case .Repeat;
            return GL_REPEAT;
        case .MirroredRepeat;
            return GL_MIRRORED_REPEAT;
        case .Border;
            return GL_CLAMP_TO_BORDER;
    }
}


TextureInterp :: enum {
    LinearMipmap;
    Linear;
    NearestMipmap;
    Nearest;
    // I don't think nearest mipmap makes sense
}

get_gl_min_format :: (interp: TextureInterp) -> s32 {
    if #complete interp == {
        case .LinearMipmap;
            return GL_LINEAR_MIPMAP_LINEAR;
        case .Linear;
            return GL_LINEAR;
        case .NearestMipmap;
            return GL_NEAREST_MIPMAP_LINEAR;
        case .Nearest;
            return GL_NEAREST;
    }
}

get_gl_mag_format :: (interp: TextureInterp) -> s32 {
    if #complete interp == {
        case .LinearMipmap;
            return GL_LINEAR;
        case .Linear;
            return GL_LINEAR;
        case .NearestMipmap;
            return GL_NEAREST;
        case .Nearest;
            return GL_NEAREST;
    }
}

get_mipmap :: (interp: TextureInterp) -> bool {
    if #complete interp == {
        case .LinearMipmap;
            return true;
        case .Linear;
            return false;
        case .NearestMipmap;
            return true;
        case .Nearest;
            return false;
    }
}



RenderTexture :: struct {
    using #as texture: Texture;
    framebuffer: u32;
    depth: Texture;
}

create_render_texture :: (width: int, height: int, format: PixelFormat) -> *RenderTexture {
    rt := New(RenderTexture);
    rt.texture.width = xx width;
    rt.texture.height = xx height;
    rt.texture.format = format;
    rt.depth.width = xx width;
    rt.depth.height = xx height;
    rt.depth.format = .Depth; // Was Depth32F

    gl_format := get_gl_format(format);

    glGenFramebuffers(1, *rt.framebuffer);
    glGenTextures(1, *rt.texture.buffer);
    // I could also `glGenRenderBuffers` for the depth buffer but idk what the difference is
    glGenTextures(1, *rt.depth.buffer);

    glBindFramebuffer(GL_FRAMEBUFFER, rt.framebuffer);

    glBindTexture(GL_TEXTURE_2D, rt.texture.buffer);
    glTexImage2D(GL_TEXTURE_2D, 0, xx gl_format, xx width, xx height, 0, gl_format, GL_UNSIGNED_BYTE, null);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, rt.texture.buffer, 0); 

    glBindTexture(GL_TEXTURE_2D, rt.depth.buffer);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT32F, xx width, xx height, 0, GL_DEPTH_COMPONENT, GL_FLOAT, null);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, rt.depth.buffer, 0);

    glClear(GL_DEPTH_BUFFER_BIT);

    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);

    return rt;
}

destroy :: (render_texture: *RenderTexture) {
    glDeleteFramebuffers(1, *render_texture.framebuffer);
    glDeleteTextures(1, *render_texture.texture.buffer);
    glDeleteTextures(1, *render_texture.depth.buffer);
    free(render_texture);
}

get_texture_and_free :: (render_texture: *RenderTexture) -> Texture {
    texture := render_texture.texture;
    glDeleteFramebuffers(1, *render_texture.framebuffer);
    glDeleteTextures(1, *render_texture.depth.buffer);
    free(render_texture);

    return texture;
}
*/
