// GPU texture wrapper for the SDL3 GPU renderer.
// @TODO remove Texture_Filter, Texture_Wrap, and Pixel_Format once all callers are updated.

Texture :: struct {
    gpu_handle : *SDL_GPUTexture;
    width  : s32;
    height : s32;
    format : Pixel_Format;
    wrap   : Texture_Wrap;
    filter : Texture_Filter;
}

Texture_Filter :: enum {
    NEAREST;
    NEAREST_MIPMAP;
    LINEAR;
    LINEAR_MIPMAP;
}

Texture_Wrap :: enum {
    REPEAT;
    MIRRORED_REPEAT;
    CLAMP_TO_EDGE;
    CLAMP_TO_BORDER;
}

Pixel_Format :: enum {
    R8; R16; R16F; R32F;
    RG8; RG16; RG16F; RG32F;
    RGB8; RGB16; RGB16F; RGB32F;
    RGBA8; RGBA16; RGBA16F; RGBA32F;
    Depth;
};

// Upload RGBA image bytes to a new SDL_GPUTexture (SAMPLER usage).
// Creates its own command buffer, submits, and waits -- fine for startup-time icon loading.
load_texture_gpu :: (rgba_data : *u8, width : s32, height : s32) -> *SDL_GPUTexture {
    gpu := app.gpu_device;
    byte_count := cast(u32)(width * height * 4);

    tex_info := SDL_GPUTextureCreateInfo.{
        type                 = .SDL_GPU_TEXTURETYPE_2D,
        format               = .R8G8B8A8_UNORM,
        usage                = SDL_GPU_TEXTUREUSAGE_SAMPLER,
        width                = cast(u32) width,
        height               = cast(u32) height,
        layer_count_or_depth = 1,
        num_levels           = 1,
        sample_count         = .SDL_GPU_SAMPLECOUNT_1,
    };
    tex := SDL_CreateGPUTexture(gpu, *tex_info);
    if !tex { print("load_texture_gpu: SDL_CreateGPUTexture failed: %\n", to_string(SDL_GetError())); return null; }

    tbuf_info := SDL_GPUTransferBufferCreateInfo.{ usage = .UPLOAD, size = byte_count };
    tbuf := SDL_CreateGPUTransferBuffer(gpu, *tbuf_info);
    ptr  := SDL_MapGPUTransferBuffer(gpu, tbuf, false);
    memcpy(ptr, rgba_data, byte_count);
    SDL_UnmapGPUTransferBuffer(gpu, tbuf);

    cmd  := SDL_AcquireGPUCommandBuffer(gpu);
    copy := SDL_BeginGPUCopyPass(cmd);
    src  := SDL_GPUTextureTransferInfo.{ transfer_buffer = tbuf, pixels_per_row = cast(u32) width, rows_per_layer = cast(u32) height };
    dst  := SDL_GPUTextureRegion.{ texture = tex, w = cast(u32) width, h = cast(u32) height, d = 1 };
    SDL_UploadToGPUTexture(copy, *src, *dst, false);
    SDL_EndGPUCopyPass(copy);
    SDL_SubmitGPUCommandBuffer(cmd);
    SDL_WaitForGPUIdle(gpu);
    SDL_ReleaseGPUTransferBuffer(gpu, tbuf);

    return tex;
}

// Decode a compressed image buffer and upload to the GPU.
load_texture_from_memory_gpu :: (buffer : []u8) -> Texture, bool {
    texture : Texture;
    channels : s32;
    data := stbi_load_from_memory(buffer.data, cast(s32) buffer.count, *texture.width, *texture.height, *channels, 4);
    if !data return texture, false;
    defer stbi_image_free(data);

    texture.gpu_handle = load_texture_gpu(data, texture.width, texture.height);
    return texture, texture.gpu_handle != null;
}
