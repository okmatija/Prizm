#scope_file

fill_pipeline: *SDL_GPUGraphicsPipeline;
line_pipeline: *SDL_GPUGraphicsPipeline;
small_viewport := SDL_GPUViewport.{160, 120, 320, 240, 0.1, 1.0};
scissor_rect := SDL_Rect.{320, 240, 320, 240};

use_wireframe_mode := false;
use_small_viewport := false;
use_scissor_rect := false;

init ::() -> int {
    result := common_init(0);
    if !result {
	return -1;
    }

    vertex_shader := load_shader(context.device, "RawTriangle.vert");
    if !vertex_shader {
	log("Failed to create vertex shader");
	return -1;
    }

    defer SDL_ReleaseGPUShader(context.device, vertex_shader);
    
    fragment_shader := load_shader(context.device, "SolidColor.frag");
    if !fragment_shader {
	log("Failed to create vertex shader");
	return -1;
    }

    defer SDL_ReleaseGPUShader(context.device, fragment_shader);

    swapchain_texture_format := SDL_GetGPUSwapchainTextureFormat(context.device, context.window);
    color_target_descriptions_array := SDL_GPUColorTargetDescription.[.{
	format = swapchain_texture_format
    }];
    
    pipeline_create_info := SDL_GPUGraphicsPipelineCreateInfo.{
	    target_info = .{
		num_color_targets = 1,
		color_target_descriptions = color_target_descriptions_array.data,
	    },
	    primitive_type = .SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
	    vertex_shader = vertex_shader,
	    fragment_shader = fragment_shader
    };

    pipeline_create_info.rasterizer_state.fill_mode = .SDL_GPU_FILLMODE_FILL;
    fill_pipeline = SDL_CreateGPUGraphicsPipeline(context.device, *pipeline_create_info);
    if !fill_pipeline {
	log("Failed to create graphics pipeline");
	return -1;
    }

    pipeline_create_info.rasterizer_state.fill_mode = .SDL_GPU_FILLMODE_LINE;
    line_pipeline =  SDL_CreateGPUGraphicsPipeline(context.device, *pipeline_create_info);
    if !line_pipeline {
	log("Failed to create graphics pipeline");
	return -1;
    }

    log("Press left to toggle wireframe mode");
    log("Press down to toggle small viewport");
    log("Press right to toggle scissor rect");

    return 0;	
}

quit :: () -> int {
    SDL_ReleaseGPUGraphicsPipeline(context.device, fill_pipeline);
    SDL_ReleaseGPUGraphicsPipeline(context.device, line_pipeline);

    common_quit();

    return 0;
}

update :: () -> int {
    if context.left_pressed {
	use_wireframe_mode = !use_wireframe_mode;
    }

    if context.down_pressed {
	use_small_viewport = !use_small_viewport;
    }

    if context.right_pressed {
	use_scissor_rect = !use_scissor_rect;
    }
    
    return 0;
}

draw :: () -> int {
    command_buffer := SDL_AcquireGPUCommandBuffer(context.device);
    if !command_buffer {
	log("Failed to acquire command buffer: %", SDL_GetError());
	return -1;
    }

    swapchain_texture: *SDL_GPUTexture;
    if !SDL_WaitAndAcquireGPUSwapchainTexture(command_buffer, context.window, *swapchain_texture, null, null) {
	log("Failed to acquire swapchain texture: %", SDL_GetError());
	return -1;
    }

    color_target_info: SDL_GPUColorTargetInfo;
    color_target_info.texture = swapchain_texture;
    color_target_info.clear_color = .{0, 0, 0, 1};
    color_target_info.load_op = .SDL_GPU_LOADOP_CLEAR;
    color_target_info.store_op = .SDL_GPU_STOREOP_STORE;

    render_pass := SDL_BeginGPURenderPass(command_buffer, *color_target_info, 1, null);
    pipeline := ifx use_wireframe_mode then line_pipeline else fill_pipeline;
    
    SDL_BindGPUGraphicsPipeline(render_pass, pipeline);

    if use_small_viewport {
	SDL_SetGPUViewport(render_pass, *small_viewport);
    }

    if use_scissor_rect {
	SDL_SetGPUScissor(render_pass, *scissor_rect);
    }

    SDL_DrawGPUPrimitives(render_pass, 3,1,0,0);
    SDL_EndGPURenderPass(render_pass);

    SDL_SubmitGPUCommandBuffer(command_buffer);

    return 0;
}

#scope_export

basic_triangle_example := SDLExample.{
	name = "BasicTriangle",
	init = init,
	quit = quit,
	update = update,
	draw = draw
};
