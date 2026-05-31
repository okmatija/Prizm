// Phase 2 hello-triangle: proves GLSL→SPIR-V build pipeline and SDL_GPU pipeline creation.
// Renders a hardcoded RGB triangle before the ImGui pass. Deleted once Phase 3 geometry is wired.

HELLO_VERT_SPV, HELLO_VERT_OK :: #run read_entire_file(".build/shaders/hello_triangle.vert.spv"); #assert(HELLO_VERT_OK);
HELLO_FRAG_SPV, HELLO_FRAG_OK :: #run read_entire_file(".build/shaders/hello_triangle.frag.spv"); #assert(HELLO_FRAG_OK);

hello_triangle_pipeline : *SDL_GPUGraphicsPipeline;

init_hello_triangle :: () {
    gpu    := app.gpu_device;
    format := SDL_GetGPUSwapchainTextureFormat(gpu, app.window);

    vert_info := SDL_GPUShaderCreateInfo.{
        code_size        = cast(u64) HELLO_VERT_SPV.count,
        code             = HELLO_VERT_SPV.data,
        entrypoint       = "main",
        format           = SDL_GPU_SHADERFORMAT_SPIRV,
        stage            = .VERTEX,
        num_uniform_buffers = 0,
    };
    vert := SDL_CreateGPUShader(gpu, *vert_info);
    assert(vert != null, "hello_triangle: vertex shader creation failed: %", to_string(SDL_GetError()));

    frag_info := SDL_GPUShaderCreateInfo.{
        code_size        = cast(u64) HELLO_FRAG_SPV.count,
        code             = HELLO_FRAG_SPV.data,
        entrypoint       = "main",
        format           = SDL_GPU_SHADERFORMAT_SPIRV,
        stage            = .FRAGMENT,
        num_uniform_buffers = 0,
    };
    frag := SDL_CreateGPUShader(gpu, *frag_info);
    assert(frag != null, "hello_triangle: fragment shader creation failed: %", to_string(SDL_GetError()));

    color_desc := SDL_GPUColorTargetDescription.{ format = format };

    pipeline_info := SDL_GPUGraphicsPipelineCreateInfo.{
        vertex_shader   = vert,
        fragment_shader = frag,
        primitive_type  = .TRIANGLELIST,
        rasterizer_state = .{ fill_mode = .FILL, cull_mode = .NONE },
        target_info = .{
            color_target_descriptions = *color_desc,
            num_color_targets         = 1,
        },
    };
    hello_triangle_pipeline = SDL_CreateGPUGraphicsPipeline(gpu, *pipeline_info);
    assert(hello_triangle_pipeline != null, "hello_triangle: pipeline creation failed: %", to_string(SDL_GetError()));

    SDL_ReleaseGPUShader(gpu, vert);
    SDL_ReleaseGPUShader(gpu, frag);
}

render_hello_triangle :: (pass : *SDL_GPURenderPass) {
    SDL_BindGPUGraphicsPipeline(pass, hello_triangle_pipeline);
    SDL_DrawGPUPrimitives(pass, 3, 1, 0, 0);
}

deinit_hello_triangle :: () {
    SDL_ReleaseGPUGraphicsPipeline(app.gpu_device, hello_triangle_pipeline);
    hello_triangle_pipeline = null;
}
