// Screenshot module: pass --screenshot [filename.bmp] on the command line to
// capture a framebuffer image 5 seconds after startup, then exit.
//
// Call sites in the rest of the program:
//   app.jai           : #load "screenshot.jai"
//   prizm.jai (init)  : init_screenshot()
//   prizm.jai (loop)  : screenshot_maybe_capture(draw_data)
//
// The render passes are fully self-contained here; no other render code
// is changed. The offscreen texture is R8G8B8A8_UNORM so the byte order
// is unambiguous regardless of the swapchain format.

SCREENSHOT_DELAY_S :: 5.0;

g_screenshot_mode       := false;
g_screenshot_path       : string;
g_screenshot_done       := false;
g_screenshot_ticks      : u64;   // SDL_GetTicks() at init time
g_screenshot_skip_index := -1;   // index of the filename token after --screenshot (skip in load_from_command_line)

screenshot_check_args :: (args : []string) {
    for i : 0..args.count-1 {
        arg := args[i];
        if arg == "--screenshot" {
            g_screenshot_mode = true;
            if i+1 < args.count && !starts_with(args[i+1], "--") {
                g_screenshot_path       = args[i+1];
                g_screenshot_skip_index = i+1;
            } else {
                g_screenshot_path = "screenshot.bmp";
            }
        } else if starts_with(arg, "--screenshot=") {
            g_screenshot_mode = true;
            g_screenshot_path = slice(arg, "--screenshot=".count, arg.count);
        }
    }
}

init_screenshot :: () {
    g_screenshot_ticks = SDL_GetTicks();
}

// Returns true if the screenshot was taken (caller should skip normal render and continue).
screenshot_maybe_capture :: (draw_data : *ImDrawData) -> bool {
    if !g_screenshot_mode  return false;
    if g_screenshot_done   return false;

    elapsed := cast(float)(SDL_GetTicks() - g_screenshot_ticks) / 1000.0;
    if elapsed < SCREENSHOT_DELAY_S  return false;

    g_screenshot_done = true;
    print("[screenshot] capturing '%' ...\n", g_screenshot_path);

    gpu := app.gpu_device;
    w   := cast(u32) app.window_size.width;
    h   := cast(u32) app.window_size.height;

    // ---- Offscreen colour texture (R8G8B8A8_UNORM for unambiguous byte order) ----
    offtex_info := SDL_GPUTextureCreateInfo.{
        type                 = .SDL_GPU_TEXTURETYPE_2D,
        format               = .R8G8B8A8_UNORM,
        usage                = SDL_GPU_TEXTUREUSAGE_COLOR_TARGET | SDL_GPU_TEXTUREUSAGE_SAMPLER,
        width                = w,
        height               = h,
        layer_count_or_depth = 1,
        num_levels           = 1,
        sample_count         = .SDL_GPU_SAMPLECOUNT_1,
    };
    offtex := SDL_CreateGPUTexture(gpu, *offtex_info);
    assert(offtex != null, "screenshot: failed to create offscreen texture: %", to_string(SDL_GetError()));

    // ---- Depth texture (same format as the main depth texture) ----
    dep_info := SDL_GPUTextureCreateInfo.{
        type                 = .SDL_GPU_TEXTURETYPE_2D,
        format               = depth_format,
        usage                = SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET,
        width                = w,
        height               = h,
        layer_count_or_depth = 1,
        num_levels           = 1,
        sample_count         = .SDL_GPU_SAMPLECOUNT_1,
    };
    dep := SDL_CreateGPUTexture(gpu, *dep_info);
    assert(dep != null, "screenshot: failed to create depth texture: %", to_string(SDL_GetError()));

    // ---- Render scene into the offscreen texture ----
    cmd := SDL_AcquireGPUCommandBuffer(gpu);
    assert(cmd != null);

    upload_entity_buffers_gpu(cmd);            // no-op (dirty=false); safe to call
    ImplSDLGPU3_PrepareDrawData(draw_data, cmd);

    bg := app.background_solid_color;
    bg_clear := SDL_FColor.{r=bg.x, g=bg.y, b=bg.z, a=1};

    // Pass A: background + geometry
    {
        color_a := SDL_GPUColorTargetInfo.{
            texture     = offtex,
            clear_color = bg_clear,
            load_op     = .CLEAR,
            store_op    = .STORE,
        };
        depth_a := SDL_GPUDepthStencilTargetInfo.{
            texture     = dep,
            load_op     = .CLEAR,
            store_op    = .DONT_CARE,
            clear_depth = 1.0,
            cycle       = false,
        };
        pass_a := SDL_BeginGPURenderPass(cmd, *color_a, 1, *depth_a);
        render_background(pass_a, cmd);
        render_selections_gpu(pass_a, cmd);
        render_entities_gpu(pass_a, cmd);
        SDL_EndGPURenderPass(pass_a);
    }

    // Pass B: axes triad + ImGui (depth cleared, colour preserved)
    {
        color_b := SDL_GPUColorTargetInfo.{
            texture  = offtex,
            load_op  = .LOAD,
            store_op = .STORE,
        };
        depth_b := SDL_GPUDepthStencilTargetInfo.{
            texture     = dep,
            load_op     = .CLEAR,
            store_op    = .DONT_CARE,
            clear_depth = 1.0,
            cycle       = false,
        };
        pass_b := SDL_BeginGPURenderPass(cmd, *color_b, 1, *depth_b);
        render_axes_triad_gpu(pass_b, cmd);
        ImplSDLGPU3_RenderDrawData(draw_data, cmd, pass_b);
        SDL_EndGPURenderPass(pass_b);
    }

    SDL_SubmitGPUCommandBuffer(cmd);
    SDL_WaitForGPUIdle(gpu);

    // ---- Download texture to CPU ----
    total_bytes := w * h * 4;  // RGBA8, 4 bytes per pixel

    tbuf_info := SDL_GPUTransferBufferCreateInfo.{
        usage = .DOWNLOAD,
        size  = total_bytes,
    };
    tbuf := SDL_CreateGPUTransferBuffer(gpu, *tbuf_info);
    assert(tbuf != null);

    dl_cmd := SDL_AcquireGPUCommandBuffer(gpu);
    assert(dl_cmd != null);

    copy_pass := SDL_BeginGPUCopyPass(dl_cmd);
    src_region := SDL_GPUTextureRegion.{
        texture = offtex,
        w = w, h = h, d = 1,
    };
    dst_info := SDL_GPUTextureTransferInfo.{
        transfer_buffer = tbuf,
        offset          = 0,
        pixels_per_row  = w,
        rows_per_layer  = h,
    };
    SDL_DownloadFromGPUTexture(copy_pass, *src_region, *dst_info);
    SDL_EndGPUCopyPass(copy_pass);
    SDL_SubmitGPUCommandBuffer(dl_cmd);
    SDL_WaitForGPUIdle(gpu);

    // ---- Map, write BMP, unmap ----
    ptr := SDL_MapGPUTransferBuffer(gpu, tbuf, false);
    assert(ptr != null);
    rgba : []u8;
    rgba.data  = cast(*u8) ptr;
    rgba.count = cast(int) total_bytes;
    ok := bmp_write_rgba(g_screenshot_path, cast(s32) w, cast(s32) h, rgba);
    SDL_UnmapGPUTransferBuffer(gpu, tbuf);
    if ok  print("[screenshot] saved '%'  (%*%)\n", g_screenshot_path, w, h);
    else   print("[screenshot] ERROR: could not write '%'\n",   g_screenshot_path);

    // ---- Cleanup ----
    SDL_ReleaseGPUTransferBuffer(gpu, tbuf);
    SDL_ReleaseGPUTexture(gpu, offtex);
    SDL_ReleaseGPUTexture(gpu, dep);

    app.closing_application = true;
    return true;
}

//
// ---- Minimal 24-bit BMP writer (no external dependencies) ----
//
// Writes an RGB BMP from RGBA source data. BMP stores rows bottom-up by default;
// negative biHeight makes it top-down so row order matches the GPU download.
//

#scope_file

bmp_write_rgba :: (path : string, w : s32, h : s32, rgba : []u8) -> bool {
    // Each row is padded to a multiple of 4 bytes (24-bit RGB = 3 bytes/pixel)
    row_bytes   := (w * 3 + 3) / 4 * 4;
    pixel_bytes := row_bytes * h;
    file_bytes  := 14 + 40 + pixel_bytes;

    buf := NewArray(file_bytes, u8,, temp);

    put_u16 :: (b : []u8, off : int, v : u16) #expand {
        b[off+0] = cast,no_check(u8)(v);
        b[off+1] = cast,no_check(u8)(v >> 8);
    }
    put_u32 :: (b : []u8, off : int, v : u32) #expand {
        b[off+0] = cast,no_check(u8)(v);
        b[off+1] = cast,no_check(u8)(v >>  8);
        b[off+2] = cast,no_check(u8)(v >> 16);
        b[off+3] = cast,no_check(u8)(v >> 24);
    }
    put_s32 :: (b : []u8, off : int, v : s32) #expand { put_u32(b, off, cast,no_check(u32) v); }

    // File header (14 bytes)
    buf[0] = #char "B"; buf[1] = #char "M";
    put_u32(buf,  2, cast(u32) file_bytes);
    put_u32(buf,  6, 0);   // reserved
    put_u32(buf, 10, 54);  // pixel data offset = 14+40

    // BITMAPINFOHEADER (40 bytes, offset 14)
    put_u32(buf, 14, 40);          // header size
    put_s32(buf, 18, w);
    put_s32(buf, 22, -h);          // negative = top-down
    put_u16(buf, 26, 1);           // colour planes
    put_u16(buf, 28, 24);          // bits per pixel
    put_u32(buf, 30, 0);           // BI_RGB compression
    put_u32(buf, 34, cast(u32) pixel_bytes);
    put_s32(buf, 38, 2835);        // 72 DPI
    put_s32(buf, 42, 2835);
    // bytes 46-53 are zero (colours used / important)

    // Pixel data: RGBA source -> BGR destination
    for y : 0..h-1 {
        for x : 0..w-1 {
            s := (y * w + x) * 4;      // RGBA source index
            d := 54 + y * row_bytes + x * 3;
            buf[d+0] = rgba[s+2]; // B
            buf[d+1] = rgba[s+1]; // G
            buf[d+2] = rgba[s+0]; // R
        }
    }

    return write_entire_file(path, .{count=file_bytes, data=buf.data});
}
