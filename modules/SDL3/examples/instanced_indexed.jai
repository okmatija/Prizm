#scope_file

pipeline: *SDL_GPUGraphicsPipeline;
vertex_buffer: *SDL_GPUBuffer;
index_buffer: *SDL_GPUBuffer;

use_vertex_offset := false;
use_index_offset := false;
use_index_buffer := true;

init :: () -> int {
    if !common_init(0) { 
	return -1;
    }
    
    // Create the shaders
    vertex_shader := load_shader(context.device, "PositionColorInstanced.vert", 0, 0, 0, 0);
    if vertex_shader == null {
	log("Failed to create vertex shader!");
	return -1;
    }

    defer SDL_ReleaseGPUShader(context.device, vertex_shader);

    fragment_shader := load_shader(context.device, "SolidColor.frag", 0, 0, 0, 0);
    if fragment_shader == null{
	log("Failed to create fragment shader!");
	return -1;
    }

    defer SDL_ReleaseGPUShader(context.device, fragment_shader);
    
    // Create the pipeline
    pipeline_create_info := SDL_GPUGraphicsPipelineCreateInfo.{
	target_info = .{
	    num_color_targets = 1,
	    color_target_descriptions = SDL_GPUColorTargetDescription.[{
		format = SDL_GetGPUSwapchainTextureFormat(context.device, context.window)
	    }].data
	},
	// This is set up to match the vertex shader layout!
	vertex_input_state = SDL_GPUVertexInputState.{
	    num_vertex_buffers = 1,
	    vertex_buffer_descriptions = SDL_GPUVertexBufferDescription.[{
		slot = 0,
		input_rate = .SDL_GPU_VERTEXINPUTRATE_VERTEX,
		instance_step_rate = 0,
		pitch = size_of(PositionColorVertex)
	    }].data,
	    num_vertex_attributes = 2,
	    vertex_attributes = SDL_GPUVertexAttribute.[{
		buffer_slot = 0,
		format = .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3,
		location = 0,
		offset = 0
	    }, {
		buffer_slot = 0,
		format = .SDL_GPU_VERTEXELEMENTFORMAT_UBYTE4_NORM,
		location = 1,
		offset = size_of(float) * 3
	    }].data
	},
	primitive_type =.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
	vertex_shader = vertex_shader,
	fragment_shader = fragment_shader
    };

    pipeline = SDL_CreateGPUGraphicsPipeline(context.device, *pipeline_create_info);
    if pipeline == null{
	log("Failed to create pipeline!");
	return -1;
    }
    
    // Create the vertex and index buffers
    vertex_buffer = SDL_CreateGPUBuffer(
	context.device,
	*(SDL_GPUBufferCreateInfo.{
	    usage = SDL_GPU_BUFFERUSAGE_VERTEX,
	    size = size_of(PositionColorVertex) * 9
	}));

    index_buffer = SDL_CreateGPUBuffer(
        context.device,
	*(SDL_GPUBufferCreateInfo.{
	    usage = SDL_GPU_BUFFERUSAGE_INDEX,
	    size = size_of(u16) * 6
	}));

    // Set the buffer data
    transfer_buffer := SDL_CreateGPUTransferBuffer(
	context.device,
	*(SDL_GPUTransferBufferCreateInfo.{
	    usage = .SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
	    size = (size_of(PositionColorVertex) * 9) + (size_of(u16) * 6),
	}));

    defer SDL_ReleaseGPUTransferBuffer(context.device, transfer_buffer);

    transfer_data := cast(*PositionColorVertex) SDL_MapGPUTransferBuffer(
	context.device,
	transfer_buffer,
	false
    );
    
    defer SDL_UnmapGPUTransferBuffer(context.device, transfer_buffer);

    transfer_data[0] = PositionColorVertex.{ -1, -1, 0, 255,   0,   0, 255 };
    transfer_data[1] = PositionColorVertex.{  1, -1, 0,   0, 255,   0, 255 };
    transfer_data[2] = PositionColorVertex.{  0,  1, 0,   0,   0, 255, 255 };
    
    transfer_data[3] = PositionColorVertex.{ -1, -1, 0, 255, 165,   0, 255 };
    transfer_data[4] = PositionColorVertex.{  1, -1, 0,   0, 128,   0, 255 };
    transfer_data[5] = PositionColorVertex.{  0,  1, 0,   0, 255, 255, 255 };
    
    transfer_data[6] = PositionColorVertex.{ -1, -1, 0, 255, 255, 255, 255 };
    transfer_data[7] = PositionColorVertex.{  1, -1, 0, 255, 255, 255, 255 };
    transfer_data[8] = PositionColorVertex.{  0,  1, 0, 255, 255, 255, 255 };
    
    index_data := cast(*u16) *transfer_data[9];
    for 0..5 {
        index_data[it] = cast(u16) it;
    }

    
    
    // Upload the transfer data to the vertex and index buffer
    upload_cmd_buf := SDL_AcquireGPUCommandBuffer(context.device);
    copy_pass := SDL_BeginGPUCopyPass(upload_cmd_buf);

    SDL_UploadToGPUBuffer(
	copy_pass,
	*(SDL_GPUTransferBufferLocation.{
	    transfer_buffer = transfer_buffer,
	    offset = 0
	}),
	*(SDL_GPUBufferRegion.{
	    buffer = vertex_buffer,
	    offset = 0,
	    size = size_of(PositionColorVertex) * 9
	}),
	false);

    SDL_UploadToGPUBuffer(
	copy_pass,
	*(SDL_GPUTransferBufferLocation.{
	    transfer_buffer = transfer_buffer,
	    offset = size_of(PositionColorVertex) * 9
	}),
	*(SDL_GPUBufferRegion.{
	    buffer = index_buffer,
	    offset = 0,
	    size = size_of(u16) * 6
	}),
	false);
    
    SDL_EndGPUCopyPass(copy_pass);
    SDL_SubmitGPUCommandBuffer(upload_cmd_buf);
    
    
    return 0;
}

update :: () -> int {
    if context.left_pressed {
        use_vertex_offset = !use_vertex_offset;
        log("Using vertex offset: %", ifx use_vertex_offset then "true" else "false");
    }

    if context.right_pressed {
        use_index_offset = !use_index_offset;
        log("Using index offset: %", ifx use_index_offset then "true" else "false");
    }

    if context.up_pressed{
	use_index_buffer = !use_index_buffer;
        log("Using index buffer: %", ifx use_index_buffer then "true" else "false");
    }

    return 0;
}

draw :: () -> int {
    vertex_offset: u32 = xx ifx use_vertex_offset then 3 else 0;
    index_offset: u32 = xx ifx use_index_offset then 3 else 0;

    cmd_buf := SDL_AcquireGPUCommandBuffer(context.device);
    if cmd_buf == null {
        log("AcquireGPUCommandBuffer failed: %", SDL_GetError());
        return -1;
    }

    swapchain_texture: *SDL_GPUTexture;
    if !SDL_WaitAndAcquireGPUSwapchainTexture(cmd_buf, context.window, *swapchain_texture, null, null) {
        log("WaitAndAcquireGPUSwapchain_texture failed: %", SDL_GetError());
        return -1;
    }

    if swapchain_texture != null {
	color_target_info: SDL_GPUColorTargetInfo;
	color_target_info.texture = swapchain_texture;
	color_target_info.clear_color = SDL_FColor.{ 0.0, 0.0, 0.0, 1.0 };
	color_target_info.load_op = .SDL_GPU_LOADOP_CLEAR;
	color_target_info.store_op = .SDL_GPU_STOREOP_STORE;

	render_pass := SDL_BeginGPURenderPass(cmd_buf, *color_target_info, 1, null);
	
	SDL_BindGPUGraphicsPipeline(render_pass, pipeline);
	SDL_BindGPUVertexBuffers(render_pass, 0, *(SDL_GPUBufferBinding.{ buffer = vertex_buffer, offset = 0 }), 1);
	
	if use_index_buffer{
	    SDL_BindGPUIndexBuffer(render_pass, *(SDL_GPUBufferBinding.{ buffer = index_buffer, offset = 0 }), .SDL_GPU_INDEXELEMENTSIZE_16BIT);
	    SDL_DrawGPUIndexedPrimitives(render_pass, 3, 16, index_offset, xx vertex_offset, 0);
	} else {
	    SDL_DrawGPUPrimitives(render_pass, 3, 16, vertex_offset, 0);
	}

	SDL_EndGPURenderPass(render_pass);
    }
    
    SDL_SubmitGPUCommandBuffer(cmd_buf);

    return 0;
}

quit :: () -> int {
    SDL_ReleaseGPUGraphicsPipeline(context.device, pipeline);
    SDL_ReleaseGPUBuffer(context.device, vertex_buffer);
    SDL_ReleaseGPUBuffer(context.device, index_buffer);
    
    use_vertex_offset = false;
    use_index_offset = false;
    use_index_buffer = true;
    
    common_quit();

    return 0;
}

#scope_export
instanced_indexed_example := SDLExample.{ "InstancedIndexed", init, update, draw, quit };
