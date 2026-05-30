#scope_file

scene_pipeline: *SDL_GPUGraphicsPipeline;
scene_vertex_buffer: *SDL_GPUBuffer;
scene_index_buffer: *SDL_GPUBuffer;
scene_color_texture: *SDL_GPUTexture;
scene_depth_texture: *SDL_GPUTexture;

effect_pipeline: *SDL_GPUGraphicsPipeline;
effect_vertex_buffer: *SDL_GPUBuffer;
effect_index_buffer: *SDL_GPUBuffer;
effect_sampler: *SDL_GPUSampler;

time: float;
scene_width, scene_height: u32;

init :: () -> int {
    if !common_init(0) {
	return -1;
    }

    // Creates the Shaders & Pipelines
    {
	scene_vertex_shader := load_shader(context.device, "PositionColorTransform.vert", 0, 1, 0, 0);
	if scene_vertex_shader == null {
	    log("Failed to create 'PositionColorTransform' vertex shader!");
	    return -1;
	}

	defer SDL_ReleaseGPUShader(context.device, scene_vertex_shader);

	scene_fragment_shader := load_shader(context.device, "SolidColorDepth.frag", 0, 1, 0, 0);
	if scene_fragment_shader == null {
	    log("Failed to create 'SolidColorDepth' fragment shader!");
	    return -1;
	}
	
	defer SDL_ReleaseGPUShader(context.device, scene_fragment_shader);

	effect_vertex_shader := load_shader(context.device, "TexturedQuad.vert", 0, 0, 0, 0);
	if effect_vertex_shader == null	{
	    log("Failed to create 'TexturedQuad' vertex shader!");
	    return -1;
	}

	defer SDL_ReleaseGPUShader(context.device, effect_vertex_shader);

	effect_fragment_shader := load_shader(context.device, "DepthOutline.frag", 2, 1, 0, 0);
	if effect_fragment_shader == null {
	    log("Failed to create 'DepthOutline' fragment shader!");
	    return -1;
	}

	defer SDL_ReleaseGPUShader(context.device, effect_fragment_shader);


	scene_color_desc := SDL_GPUColorTargetDescription.{format = .SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM};
	
	scene_vertex_buffer_desc := SDL_GPUVertexBufferDescription.{
	    slot = 0,
	    input_rate = .SDL_GPU_VERTEXINPUTRATE_VERTEX,
	    instance_step_rate = 0,
	    pitch = size_of(PositionColorVertex)
	};

	scene_vertex_attrs := SDL_GPUVertexAttribute.[{
	    buffer_slot = 0,
	    format = .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3,
	    location = 0,
	    offset = 0
	}, {
	    buffer_slot = 0,
	    format = .SDL_GPU_VERTEXELEMENTFORMAT_UBYTE4_NORM,
	    location = 1,
	    offset = size_of(float) * 3
	}];
						      
	scene_pipeline_create_info := SDL_GPUGraphicsPipelineCreateInfo.{
	    target_info = .{
		num_color_targets = 1,
		color_target_descriptions = *scene_color_desc,
		has_depth_stencil_target = true,
		depth_stencil_format = .SDL_GPU_TEXTUREFORMAT_D16_UNORM
	    },
	    depth_stencil_state = SDL_GPUDepthStencilState.{
		enable_depth_test = true,
		enable_depth_write = true,
		enable_stencil_test = false,
		compare_op = .SDL_GPU_COMPAREOP_LESS,
		write_mask = 0xFF
	    },
	    rasterizer_state = SDL_GPURasterizerState.{
		cull_mode = .SDL_GPU_CULLMODE_BACK,
		fill_mode = .SDL_GPU_FILLMODE_FILL,
		front_face = .SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE
	    },
	    vertex_input_state = SDL_GPUVertexInputState.{
		num_vertex_buffers = 1,
		vertex_buffer_descriptions = *scene_vertex_buffer_desc,
		num_vertex_attributes = 2,
		vertex_attributes = scene_vertex_attrs.data
	    },
	    primitive_type = .SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
	    vertex_shader = scene_vertex_shader,
	    fragment_shader = scene_fragment_shader
	};
						      
	scene_pipeline = SDL_CreateGPUGraphicsPipeline(context.device, *scene_pipeline_create_info);
	if scene_pipeline == null {
	    log("Failed to create Scene pipeline!");
	    return -1;
	}

	effect_color_desc := SDL_GPUColorTargetDescription.{
	    format = SDL_GetGPUSwapchainTextureFormat(context.device, context.window),
	    blend_state = SDL_GPUColorTargetBlendState.{
		enable_blend = true,
		src_color_blendfactor = .SDL_GPU_BLENDFACTOR_ONE,
		dst_color_blendfactor = .SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
		color_blend_op = .SDL_GPU_BLENDOP_ADD,
		src_alpha_blendfactor = .SDL_GPU_BLENDFACTOR_ONE,
		dst_alpha_blendfactor = .SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
		alpha_blend_op = .SDL_GPU_BLENDOP_ADD,
	    }
	};

	effect_vertex_buffer_desc := SDL_GPUVertexBufferDescription.{
	    slot = 0,
	    input_rate = .SDL_GPU_VERTEXINPUTRATE_VERTEX,
	    instance_step_rate = 0,
	    pitch = size_of(PositionTextureVertex)
	};

	effect_vertex_attrs := SDL_GPUVertexAttribute.[{
	    buffer_slot = 0,
	    format = .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3,
	    location = 0,
	    offset = 0
	}, {
	    buffer_slot = 0,
	    format = .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2,
	    location = 1,
	    offset = size_of(float) * 3
	}];
	
	effect_pipeline_create_info := SDL_GPUGraphicsPipelineCreateInfo.{
	    target_info = .{
		num_color_targets = 1,
		color_target_descriptions = *effect_color_desc,
	    },
	    vertex_input_state = SDL_GPUVertexInputState.{
		num_vertex_buffers = 1,
		vertex_buffer_descriptions = *effect_vertex_buffer_desc,
		num_vertex_attributes = 2,
		vertex_attributes = effect_vertex_attrs.data,
	    },
	    primitive_type = .SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
	    vertex_shader = effect_vertex_shader,
	    fragment_shader = effect_fragment_shader
	};

	effect_pipeline = SDL_CreateGPUGraphicsPipeline(context.device, *effect_pipeline_create_info);
	if effect_pipeline == null {
	    log("Failed to create Outline Effect pipeline!");
	    return -1;
	}

    }

    // Create the Scene Textures
    {
	// Make them smaller so pixels stand out more
	w, h: s32;
	SDL_GetWindowSizeInPixels(context.window, *w, *h);
	scene_width = (cast(u32) w) / 4;
	scene_height = (cast(u32) h) / 4;

	scene_color_texture_create_info :=  SDL_GPUTextureCreateInfo.{
	    type = .SDL_GPU_TEXTURETYPE_2D,
	    width = scene_width,
	    height = scene_height,
	    layer_count_or_depth = 1,
	    num_levels = 1,
	    sample_count = .SDL_GPU_SAMPLECOUNT_1,
	    format = .SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
	    usage = SDL_GPU_TEXTUREUSAGE_SAMPLER | SDL_GPU_TEXTUREUSAGE_COLOR_TARGET
	};
	
	scene_color_texture = SDL_CreateGPUTexture(
	    context.device,
	    *scene_color_texture_create_info);

	scene_depth_texture_create_info := SDL_GPUTextureCreateInfo.{
	    type = .SDL_GPU_TEXTURETYPE_2D,
	    width = scene_width,
	    height = scene_height,
	    layer_count_or_depth = 1,
	    num_levels = 1,
	    sample_count = .SDL_GPU_SAMPLECOUNT_1,
	    format = .SDL_GPU_TEXTUREFORMAT_D16_UNORM,
	    usage = SDL_GPU_TEXTUREUSAGE_SAMPLER | SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET
	};
	
	scene_depth_texture = SDL_CreateGPUTexture(
	    context.device,
	    *scene_depth_texture_create_info);
    }

    // Create Outline Effect Sampler
    
    effect_sampler_create_info := SDL_GPUSamplerCreateInfo.{
	min_filter = .SDL_GPU_FILTER_NEAREST,
	mag_filter = .SDL_GPU_FILTER_NEAREST,
	mipmap_mode = .SDL_GPU_SAMPLERMIPMAPMODE_NEAREST,
	address_mode_u = .SDL_GPU_SAMPLERADDRESSMODE_REPEAT,
	address_mode_v = .SDL_GPU_SAMPLERADDRESSMODE_REPEAT,
	address_mode_w = .SDL_GPU_SAMPLERADDRESSMODE_REPEAT,
    };
    
    effect_sampler = SDL_CreateGPUSampler(
	context.device,
	*effect_sampler_create_info);
    
    // Create & Upload Scene Index and Vertex Buffers
    {
	scene_vertex_buyffer_create_info := SDL_GPUBufferCreateInfo.{
	    usage = SDL_GPU_BUFFERUSAGE_VERTEX,
	    size = size_of(PositionColorVertex) * 24
	};
	
	scene_vertex_buffer = SDL_CreateGPUBuffer(
	    context.device,
            *scene_vertex_buyffer_create_info);

	scene_index_buffer_create_info := SDL_GPUBufferCreateInfo.{
	    usage = SDL_GPU_BUFFERUSAGE_INDEX,
	    size = size_of(Uint16) * 36
	};
	
	scene_index_buffer = SDL_CreateGPUBuffer(
	    context.device,
	    *scene_index_buffer_create_info);

	transfer_buffer_create_info := SDL_GPUTransferBufferCreateInfo.{
	    usage = .SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
	    size = (size_of(PositionColorVertex) * 24) + (size_of(Uint16) * 36)
	};
	    
	buffer_transfer_buffer := SDL_CreateGPUTransferBuffer(
	    context.device,
	    *transfer_buffer_create_info);

	defer SDL_ReleaseGPUTransferBuffer(context.device, buffer_transfer_buffer);

	transfer_data := cast(*PositionColorVertex) SDL_MapGPUTransferBuffer(
	    context.device,
	    buffer_transfer_buffer,
	    false);

	defer SDL_UnmapGPUTransferBuffer(context.device, buffer_transfer_buffer);

	/// NOTE -- jhenzie: 
	// /modified from original example to use correct winding order and allow back face culling
	transfer_data[0] = PositionColorVertex.{ -10, -10, 10, 255, 0, 0, 255 };
	transfer_data[1] = PositionColorVertex.{ 10, -10, 10, 255, 0, 0, 255 };
	transfer_data[2] = PositionColorVertex.{ 10, 10, 10, 255, 0, 0, 255 };
	transfer_data[3] = PositionColorVertex.{ -10, 10, 10, 255, 0, 0, 255 };
	
	transfer_data[4] = PositionColorVertex.{ 10, -10, 10, 255, 0, 255, 255 };
	transfer_data[5] = PositionColorVertex.{ 10, -10, -10, 255, 0, 255, 255 };
	transfer_data[6] = PositionColorVertex.{ 10, 10, -10, 255, 0, 255, 255 };
	transfer_data[7] = PositionColorVertex.{ 10, 10, 10, 255, 0, 255, 255 };
	
	transfer_data[8] = PositionColorVertex.{ 10, -10, -10, 255, 255, 0, 255 };
	transfer_data[9] = PositionColorVertex.{ -10, -10, -10, 255, 255, 0, 255 };
	transfer_data[10] = PositionColorVertex.{ -10, 10, -10, 255, 255, 0, 255 };
	transfer_data[11] = PositionColorVertex.{ 10, 10, -10, 255, 255, 0, 255 };
	
	transfer_data[12] = PositionColorVertex.{ -10, -10, -10, 0, 255, 0, 255 };
	transfer_data[13] = PositionColorVertex.{ -10, -10, 10, 0, 255, 0, 255 };
	transfer_data[14] = PositionColorVertex.{ -10, 10, 10, 0, 255, 0, 255 };
	transfer_data[15] = PositionColorVertex.{ -10, 10, -10, 0, 255, 0, 255 };
	
	transfer_data[16] = PositionColorVertex.{ -10, 10, 10, 0, 0, 255, 255 };
	transfer_data[17] = PositionColorVertex.{ 10, 10, 10, 0, 0, 255, 255 };
	transfer_data[18] = PositionColorVertex.{ 10, 10, -10, 0, 0, 255, 255 };
	transfer_data[19] = PositionColorVertex.{ -10, 10, -10, 0, 0, 255, 255 };
	
	transfer_data[20] = PositionColorVertex.{ -10, -10, 10, 0, 0, 255, 255 };
	transfer_data[21] = PositionColorVertex.{ 10, -10, 10, 0, 0, 255, 255 };
	transfer_data[22] = PositionColorVertex.{ 10, -10, 10, 0, 0, 255, 255 };
	transfer_data[23] = PositionColorVertex.{ -10, -10, -10, 0, 0, 255, 255 };
	
	index_data := cast(*u16) *transfer_data[24];
	indices := u16.[
	    0, 1, 2, 0, 2, 3,
	    4, 5, 6, 4, 6, 7,
	    8, 9, 10, 8, 10, 11,
	    12, 13, 14, 12, 14, 15,
	    16, 17, 18, 16, 18, 19,
	    20, 21, 22, 20, 22, 23
	];

	memcpy(index_data, indices.data, size_of(type_of(indices)));

	// Upload the transfer data to the GPU buffers
	upload_cmd_buffer := SDL_AcquireGPUCommandBuffer(context.device);
	copy_pass := SDL_BeginGPUCopyPass(upload_cmd_buffer);

	vertex_transfer_buffer_location := SDL_GPUTransferBufferLocation.{
	    transfer_buffer = buffer_transfer_buffer,
	    offset = 0
	};

	vertex_buffer_region := SDL_GPUBufferRegion.{
	    buffer = scene_vertex_buffer,
	    offset = 0,
	    size = size_of(PositionColorVertex) * 24
	};
	
	SDL_UploadToGPUBuffer(
	    copy_pass,
	    *vertex_transfer_buffer_location,
	    *vertex_buffer_region,
	    false);

	index_transfer_buffer_location := SDL_GPUTransferBufferLocation.{
	    transfer_buffer = buffer_transfer_buffer,
	    offset = size_of(PositionColorVertex) * 24
	};
	
	index_buffer_region := SDL_GPUBufferRegion.{
	    buffer = scene_index_buffer,
	    offset = 0,
	    size = size_of(u16) * 36
	};
	
	SDL_UploadToGPUBuffer(
	    copy_pass,
	    *index_transfer_buffer_location,
	    *index_buffer_region,
	    false);
	
	SDL_EndGPUCopyPass(copy_pass);
	SDL_SubmitGPUCommandBuffer(upload_cmd_buffer);
    }

    // Create & Upload Outline Effect Vertex and Index buffers
    {
	effect_vertex_buffer_create_info := SDL_GPUBufferCreateInfo.{
	    usage = SDL_GPU_BUFFERUSAGE_VERTEX,
	    size = size_of(PositionTextureVertex) * 4
	};
	
	effect_vertex_buffer = SDL_CreateGPUBuffer(
	    context.device,
	    *effect_vertex_buffer_create_info);

	effect_index_buffer_create_info := SDL_GPUBufferCreateInfo.{
	    usage = SDL_GPU_BUFFERUSAGE_INDEX,
	    size = size_of(u16) * 6
	};
	
	effect_index_buffer = SDL_CreateGPUBuffer(
	    context.device,
		*effect_index_buffer_create_info);

	tranfer_buffer_create_info := SDL_GPUTransferBufferCreateInfo.{
	    usage = .SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
	    size = (size_of(PositionTextureVertex) * 4) + (size_of(u16) * 6)
	};

	buffer_transfer_buffer := SDL_CreateGPUTransferBuffer(
	    context.device,
	    *tranfer_buffer_create_info);

	defer SDL_ReleaseGPUTransferBuffer(context.device, buffer_transfer_buffer);
	
	transfer_data := cast(*PositionTextureVertex) SDL_MapGPUTransferBuffer(
	    context.device,
	    buffer_transfer_buffer,
	    false);

	defer SDL_UnmapGPUTransferBuffer(context.device, buffer_transfer_buffer);

	transfer_data[0] = PositionTextureVertex.{ -1,  1, 0, 0, 0 };
	transfer_data[1] = PositionTextureVertex.{  1,  1, 0, 1, 0 };
	transfer_data[2] = PositionTextureVertex.{  1, -1, 0, 1, 1 };
	transfer_data[3] = PositionTextureVertex.{ -1, -1, 0, 0, 1 };
	
	indexData := cast(*u16) *transfer_data[4];
	indexData[0] = 0;
	indexData[1] = 1;
	indexData[2] = 2;
	indexData[3] = 0;
	indexData[4] = 2;
	indexData[5] = 3;

	upload_cmd_buffer := SDL_AcquireGPUCommandBuffer(context.device);
	copy_pass := SDL_BeginGPUCopyPass(upload_cmd_buffer);

	vertex_transfer_buffer_location := SDL_GPUTransferBufferLocation.{
	    transfer_buffer = buffer_transfer_buffer,
	    offset = 0
	};

	vertex_buffer_region := SDL_GPUBufferRegion.{
	    buffer = effect_vertex_buffer,
	    offset = 0,
	    size = size_of(PositionTextureVertex) * 4
	};
	
	SDL_UploadToGPUBuffer(
	    copy_pass,
	    *vertex_transfer_buffer_location,
	    *vertex_buffer_region ,
	    false);

	index_transfer_buffer_location := SDL_GPUTransferBufferLocation.{
	    transfer_buffer = buffer_transfer_buffer,
	    offset = size_of(PositionTextureVertex) * 4
	};

	index_buffer_region := SDL_GPUBufferRegion.{
	    buffer = effect_index_buffer,
	    offset = 0,
	    size = size_of(u16) * 6
	};
	
	SDL_UploadToGPUBuffer(
	    copy_pass,
	    *index_transfer_buffer_location,
	    *index_buffer_region,
	    false);
	
	SDL_EndGPUCopyPass(copy_pass);
	SDL_SubmitGPUCommandBuffer(upload_cmd_buffer);
    }

    time = 0;
    return 0;
}

update :: () -> int {
    time += context.delta_time;
    return 0;
}

draw :: () -> int {
    draw_cmd_buffer := SDL_AcquireGPUCommandBuffer(context.device);
    if draw_cmd_buffer == null {
	log("AcquireGPUCommandBuffer failed: %", SDL_GetError());
	return -1;
    }

    swapchain_texture: *SDL_GPUTexture;
    if !SDL_WaitAndAcquireGPUSwapchainTexture(draw_cmd_buffer, context.window, *swapchain_texture, null, null) {
	log("WaitAndAcquireGPUSwapchainTexture failed: %", SDL_GetError());
	return -1;
    }

    if swapchain_texture != null {
	// Render the 3D Scene (Color and Depth pass)
	near_plane := 20.0;
	far_plane := 60.0;

	proj := Matrix4x4_CreatePerspectiveFieldOfView(
	    75.0 * PI / 180.0,
	    scene_width / cast(float)scene_height,
	    near_plane,
	    far_plane);
	
	view := Matrix4x4_CreateLookAt(
	    .{ cos(time) * 30, 30, sin(time) * 30 },
	    .{ 0, 0, 0 },
	    .{ 0, 1, 0 }
	);

	view_proj := multiply(view, proj);

	color_target_info: SDL_GPUColorTargetInfo;
	color_target_info.texture = scene_color_texture;
	color_target_info.clear_color = SDL_FColor.{ 0.0, 0.0, 0.0, 0.0 };
	color_target_info.load_op = .SDL_GPU_LOADOP_CLEAR;
	color_target_info.store_op = .SDL_GPU_STOREOP_STORE;
	
	depth_stencil_target_info: SDL_GPUDepthStencilTargetInfo;
	depth_stencil_target_info.texture = scene_depth_texture;
	depth_stencil_target_info.cycle = true;
	depth_stencil_target_info.clear_depth = 1;
	depth_stencil_target_info.clear_stencil = 0;
	depth_stencil_target_info.load_op = .SDL_GPU_LOADOP_CLEAR;
	depth_stencil_target_info.store_op = .SDL_GPU_STOREOP_STORE;
	depth_stencil_target_info.stencil_load_op = .SDL_GPU_LOADOP_CLEAR;
	depth_stencil_target_info.stencil_store_op = .SDL_GPU_STOREOP_STORE;

	SDL_PushGPUVertexUniformData(draw_cmd_buffer, 0, *view_proj, size_of(type_of(view_proj)));
	SDL_PushGPUFragmentUniformData(draw_cmd_buffer, 0, float.[near_plane, far_plane].data, 8);

	scene_vertex_buffer_binding := SDL_GPUBufferBinding.{buffer = scene_vertex_buffer, offset = 0};
	scene_index_buffer_binding := SDL_GPUBufferBinding.{buffer = scene_index_buffer, offset = 0};
	
	scene_render_pass := SDL_BeginGPURenderPass(draw_cmd_buffer, *color_target_info, 1, *depth_stencil_target_info);
	SDL_BindGPUVertexBuffers(scene_render_pass, 0, *scene_vertex_buffer_binding, 1);
	SDL_BindGPUIndexBuffer(scene_render_pass, *scene_index_buffer_binding, .SDL_GPU_INDEXELEMENTSIZE_16BIT);
	SDL_BindGPUGraphicsPipeline(scene_render_pass, scene_pipeline);

	SDL_DrawGPUIndexedPrimitives(scene_render_pass, 36, 1, 0, 0, 0);

	SDL_EndGPURenderPass(scene_render_pass);

	// Render the Outline Effect that samples from the Color/Depth textures
	swapchain_target_info: SDL_GPUColorTargetInfo;
	swapchain_target_info.texture = swapchain_texture;
	swapchain_target_info.clear_color = SDL_FColor.{ 0.2, 0.5, 0.4, 1.0 };
	swapchain_target_info.load_op = .SDL_GPU_LOADOP_CLEAR;
	swapchain_target_info.store_op = .SDL_GPU_STOREOP_STORE;

	effect_vertex_buffer_binding := SDL_GPUBufferBinding.{buffer = effect_vertex_buffer, offset = 0};
	effect_index_buffer_binding := SDL_GPUBufferBinding.{buffer = effect_index_buffer, offset = 0};
	effect_texture_sampler_bindings := SDL_GPUTextureSamplerBinding.[
	    {texture = scene_color_texture, sampler = effect_sampler},
	    {texture = scene_depth_texture, sampler = effect_sampler}];
	
	effect_render_pass := SDL_BeginGPURenderPass(draw_cmd_buffer, *swapchain_target_info, 1, null);
	SDL_BindGPUGraphicsPipeline(effect_render_pass, effect_pipeline);
	SDL_BindGPUVertexBuffers(effect_render_pass, 0, *effect_vertex_buffer_binding, 1);
	SDL_BindGPUIndexBuffer(effect_render_pass, *effect_index_buffer_binding, .SDL_GPU_INDEXELEMENTSIZE_16BIT);
	SDL_BindGPUFragmentSamplers(effect_render_pass, 0, effect_texture_sampler_bindings.data, 2);

	SDL_DrawGPUIndexedPrimitives(effect_render_pass, 6, 1, 0, 0, 0);

	SDL_EndGPURenderPass(effect_render_pass);
    }
    
    SDL_SubmitGPUCommandBuffer(draw_cmd_buffer);

    return 0;
}

quit :: () -> int {
    SDL_ReleaseGPUGraphicsPipeline(context.device, scene_pipeline);
    SDL_ReleaseGPUTexture(context.device, scene_color_texture);
    SDL_ReleaseGPUTexture(context.device, scene_depth_texture);
    SDL_ReleaseGPUBuffer(context.device, scene_vertex_buffer);
    SDL_ReleaseGPUBuffer(context.device, scene_index_buffer);
    
    SDL_ReleaseGPUGraphicsPipeline(context.device, effect_pipeline);
    SDL_ReleaseGPUBuffer(context.device, effect_vertex_buffer);
    SDL_ReleaseGPUBuffer(context.device, effect_index_buffer);
    SDL_ReleaseGPUSampler(context.device, effect_sampler);
    
    common_quit();

    return 0;
}

#scope_export

depth_sampler_example := SDLExample.{
    name = "DepthSampler",
    init = init,
    quit = quit,
    update = update,
    draw = draw};
