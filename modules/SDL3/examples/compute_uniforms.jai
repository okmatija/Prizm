#scope_file

gradient_pipeline: *SDL_GPUComputePipeline;
gradient_render_texture: *SDL_GPUTexture;

GradientUniforms :: struct {
    time: float;
}

gradient_uniform_values: GradientUniforms;

init :: () -> int {
    if !common_init(0) {
        return -1;
    }

    gradient_pipeline = create_compute_pipeline_from_shader(
        context.device,
        "GradientTexture.comp",
        *(SDL_GPUComputePipelineCreateInfo.{
            num_readwrite_storage_textures = 1,
            num_uniform_buffers = 1,
            threadcount_x = 8,
            threadcount_y = 8,
            threadcount_z = 1,
        }));

    w, h: s32;
    SDL_GetWindowSizeInPixels(context.window, *w, *h);

    gradient_render_texture = SDL_CreateGPUTexture(context.device, *(SDL_GPUTextureCreateInfo.{
        format = .SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
        type = .SDL_GPU_TEXTURETYPE_2D,
        width = xx w,
        height = xx h,
        layer_count_or_depth = 1,
        num_levels = 1,
        usage = SDL_GPU_TEXTUREUSAGE_SAMPLER | SDL_GPU_TEXTUREUSAGE_COMPUTE_STORAGE_WRITE
    }));
	
    gradient_uniform_values.time = 0;
    
    return 0;
}

update :: () -> int {
    gradient_uniform_values.time += 0.01;
    return 0;
}

draw :: () -> int {
    cmd_buf := SDL_AcquireGPUCommandBuffer(context.device);
    if !cmd_buf {
        log("AcquireGPUCommandBuffer failed: %", SDL_GetError());
        return -1;
    }

    swapchain_texture: *SDL_GPUTexture;
    w, h: u32;
    if !SDL_WaitAndAcquireGPUSwapchainTexture(cmd_buf, context.window, *swapchain_texture, *w, *h) {
        log("WaitAndAcquireGPUSwapchainTexture failed: %", SDL_GetError());
        return -1;
    }

    if  swapchain_texture {
        compute_pass := SDL_BeginGPUComputePass(
            cmd_buf,
            SDL_GPUStorageTextureReadWriteBinding.[{
                texture = gradient_render_texture,
                cycle = true
            }].data,
            1,
            null,
            0
        );

        SDL_BindGPUComputePipeline(compute_pass, gradient_pipeline);
        SDL_PushGPUComputeUniformData(cmd_buf, 0, *gradient_uniform_values, size_of(type_of(gradient_uniform_values)));
        SDL_DispatchGPUCompute(compute_pass, w / 8 , h / 8 , 1);

        SDL_EndGPUComputePass(compute_pass);

        SDL_BlitGPUTexture(
            cmd_buf,
            *(SDL_GPUBlitInfo.{
                source.texture = gradient_render_texture,
                source.w = w,
                source.h = h,
                destination.texture = swapchain_texture,
                destination.w = w,
                destination.h = h,
                load_op = .SDL_GPU_LOADOP_DONT_CARE,
                filter = .SDL_GPU_FILTER_LINEAR
            })
        );
    }

    SDL_SubmitGPUCommandBuffer(cmd_buf);

    return 0;
}

quit :: () -> int {
    SDL_ReleaseGPUComputePipeline(context.device, gradient_pipeline);
    SDL_ReleaseGPUTexture(context.device, gradient_render_texture);

    common_quit();

    return 0;
}

#scope_export

compute_uniforms_example := SDLExample.{ "ComputeUniforms", init, update, draw, quit };
