// Feature documentation: Tracy frame images — captures a 320x180 RGBA8 thumbnail of each
// rendered frame and emits it to the Tracy profiler before FrameMark. The frame bar in Tracy
// then shows a preview image when hovering over each frame.
//
// SDL GPU swapchain textures are write-only, so rendering goes to an intermediate RGBA8
// offscreen texture (g_tracy_offscreen_tex) instead of directly to the swapchain. After all
// render passes, two blits execute in the same command buffer:
//   1. offscreen -> swapchain  (display, full resolution)
//   2. offscreen -> thumbnail  (320x180, for Tracy)
// A copy pass then downloads the thumbnail to a persistent transfer buffer. After the command
// buffer is submitted, SDL_WaitForGPUIdle stalls until the download completes, then the
// pixel data is mapped and emitted to Tracy.
//
// This file is only loaded when USE_TRACY is true (see prizm.jai).

TRACY_THUMB_W :: 320;
TRACY_THUMB_H :: 180;

g_tracy_offscreen_tex : *SDL_GPUTexture;
g_tracy_offscreen_w   : u32;
g_tracy_offscreen_h   : u32;
g_tracy_thumb_tex     : *SDL_GPUTexture;
g_tracy_thumb_tbuf    : *SDL_GPUTransferBuffer;

init_tracy_frame_image :: () {
    gpu := app.gpu_device;

    thumb_info := SDL_GPUTextureCreateInfo.{
        type                 = .SDL_GPU_TEXTURETYPE_2D,
        format               = .R8G8B8A8_UNORM,
        usage                = SDL_GPU_TEXTUREUSAGE_COLOR_TARGET,
        width                = TRACY_THUMB_W,
        height               = TRACY_THUMB_H,
        layer_count_or_depth = 1,
        num_levels           = 1,
        sample_count         = .SDL_GPU_SAMPLECOUNT_1,
    };
    g_tracy_thumb_tex = SDL_CreateGPUTexture(gpu, *thumb_info);
    assert(g_tracy_thumb_tex != null, "Tracy: failed to create thumbnail texture");

    tbuf_info := SDL_GPUTransferBufferCreateInfo.{
        usage = .DOWNLOAD,
        size  = TRACY_THUMB_W * TRACY_THUMB_H * 4,
    };
    g_tracy_thumb_tbuf = SDL_CreateGPUTransferBuffer(gpu, *tbuf_info);
    assert(g_tracy_thumb_tbuf != null, "Tracy: failed to create thumbnail transfer buffer");
}

deinit_tracy_frame_image :: () {
    gpu := app.gpu_device;
    if g_tracy_offscreen_tex  SDL_ReleaseGPUTexture(gpu, g_tracy_offscreen_tex);
    if g_tracy_thumb_tex      SDL_ReleaseGPUTexture(gpu, g_tracy_thumb_tex);
    if g_tracy_thumb_tbuf     SDL_ReleaseGPUTransferBuffer(gpu, g_tracy_thumb_tbuf);
}

// Ensures the full-resolution offscreen texture matches the current window size; returns it.
// Called once per frame before rendering. Recreates on window resize.
tracy_ensure_offscreen :: (w: u32, h: u32) -> *SDL_GPUTexture {
    if g_tracy_offscreen_w == w && g_tracy_offscreen_h == h  return g_tracy_offscreen_tex;

    gpu := app.gpu_device;
    if g_tracy_offscreen_tex {
        SDL_WaitForGPUIdle(gpu);
        SDL_ReleaseGPUTexture(gpu, g_tracy_offscreen_tex);
    }

    info := SDL_GPUTextureCreateInfo.{
        type                 = .SDL_GPU_TEXTURETYPE_2D,
        format               = .R8G8B8A8_UNORM,
        usage                = SDL_GPU_TEXTUREUSAGE_COLOR_TARGET | SDL_GPU_TEXTUREUSAGE_SAMPLER,
        width                = w,
        height               = h,
        layer_count_or_depth = 1,
        num_levels           = 1,
        sample_count         = .SDL_GPU_SAMPLECOUNT_1,
    };
    g_tracy_offscreen_tex = SDL_CreateGPUTexture(gpu, *info);
    assert(g_tracy_offscreen_tex != null, "Tracy: failed to create offscreen texture (%x%)", w, h);
    g_tracy_offscreen_w = w;
    g_tracy_offscreen_h = h;
    return g_tracy_offscreen_tex;
}

// Called inside the command buffer after all render passes, before submit.
// Blits offscreen->swapchain (display) and offscreen->thumbnail, then enqueues the download.
tracy_blit_and_enqueue_download :: (cmd: *SDL_GPUCommandBuffer, swapchain_tex: *SDL_GPUTexture) {
    w := g_tracy_offscreen_w;
    h := g_tracy_offscreen_h;

    SDL_BlitGPUTexture(cmd, *(SDL_GPUBlitInfo.{
        source.texture      = g_tracy_offscreen_tex,
        source.w            = w,
        source.h            = h,
        destination.texture = swapchain_tex,
        destination.w       = w,
        destination.h       = h,
        load_op             = .DONT_CARE,
        filter              = .LINEAR,
    }));

    SDL_BlitGPUTexture(cmd, *(SDL_GPUBlitInfo.{
        source.texture      = g_tracy_offscreen_tex,
        source.w            = w,
        source.h            = h,
        destination.texture = g_tracy_thumb_tex,
        destination.w       = TRACY_THUMB_W,
        destination.h       = TRACY_THUMB_H,
        load_op             = .DONT_CARE,
        filter              = .LINEAR,
    }));

    copy_pass := SDL_BeginGPUCopyPass(cmd);
    SDL_DownloadFromGPUTexture(copy_pass,
        *(SDL_GPUTextureRegion.{texture = g_tracy_thumb_tex, w = TRACY_THUMB_W, h = TRACY_THUMB_H, d = 1}),
        *(SDL_GPUTextureTransferInfo.{transfer_buffer = g_tracy_thumb_tbuf, pixels_per_row = TRACY_THUMB_W, rows_per_layer = TRACY_THUMB_H}));
    SDL_EndGPUCopyPass(copy_pass);
}

// Called after SDL_SubmitGPUCommandBuffer. Stalls until the download completes, maps the
// transfer buffer, and emits the thumbnail to Tracy. Must be called before FrameMark.
tracy_emit_frame_image :: () {
    SDL_WaitForGPUIdle(app.gpu_device);
    ptr := SDL_MapGPUTransferBuffer(app.gpu_device, g_tracy_thumb_tbuf, false);
    context._Tracy.FrameImage(ptr, TRACY_THUMB_W, TRACY_THUMB_H);
    SDL_UnmapGPUTransferBuffer(app.gpu_device, g_tracy_thumb_tbuf);
}
