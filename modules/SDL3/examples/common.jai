#import("Basic");
#import("File_Utilities");
#import("Math");
#import("File");
#import("stb_image");
#import("String");
#import("System");

#import("jai-sdl3");

#add_context example_name: string = "";
#add_context base_path: string = "";
#add_context window: *SDL_Window = null;
#add_context device: *SDL_GPUDevice = null;
#add_context left_pressed: bool = false;
#add_context right_pressed: bool = false;
#add_context down_pressed: bool = false;
#add_context up_pressed: bool = false;
#add_context delta_time: float = 0.0;

SDLExample :: struct {
    name: string;
    init: #type () -> int;
    update: #type () -> int;
    draw: #type () -> int;
    quit: #type () -> int;
}

PositionColorVertex :: struct {
    x, y, z: float;
    r, g, b, a: u8;
}

PositionTextureVertex :: struct {
    x, y, z: float;
    u, v: float;
}

common_init :: (window_flags: SDL_WindowFlags) -> bool {
    assert(context.device == null && context.window == null);

    init_base_path();
    
    context.device = SDL_CreateGPUDevice(SDL_GPU_SHADERFORMAT_SPIRV | SDL_GPU_SHADERFORMAT_DXIL | SDL_GPU_SHADERFORMAT_MSL, true, null);
    if context.device == null {
	log("CreateGPUDevice failes");
	return false;
    }

    example_name_as_cstring := string_to_cstring(context.example_name);
    defer free(example_name_as_cstring);
    
    context.window = SDL_CreateWindow(example_name_as_cstring, 640, 500, window_flags);
    if context.window == null {
	common_quit();
	
	log("CreateWindow failed %", SDL_GetError());
	return false;
    }

    if !SDL_ClaimWindowForGPUDevice(context.device, context.window) {
	common_quit();
	
	log("ClaimWindowForGPUDevice failed");
	return false;
    }

    return true;
    
}

common_quit :: () {

    if context.device && context.window {
	SDL_ReleaseWindowFromGPUDevice(context.device, context.window);
    }

    if context.window {
	SDL_DestroyWindow(context.window);
    }

    if context.device {
	SDL_DestroyGPUDevice(context.device);
    }
    
    context.window = null;
    context.device = null;

    free(base_path.data);
}

load_shader_file :: (device: *SDL_GPUDevice, filename: string) -> code: *void, code_size: u64, stage: SDL_GPUShaderStage, format: u32, entry_point: string {
    assert(device != null); // todo file exists
    
    stage: SDL_GPUShaderStage;
    
    if ends_with(filename, ".vert") {
	stage = .SDL_GPU_SHADERSTAGE_VERTEX;
    } else if ends_with(filename, ".frag") {
	stage = .SDL_GPU_SHADERSTAGE_FRAGMENT;
    } else if !ends_with(filename, ".comp") {
	log("Invalid shader stage, shader files must have am extension of .vert or .frag");
	return null, 0, stage, SDL_GPU_SHADERFORMAT_INVALID, "";
    }

    backend_format := SDL_GetGPUShaderFormats(device);
    shader_format: SDL_GPUShaderFormat = SDL_GPU_SHADERFORMAT_INVALID;
    entry_point := "main";
    shader_file_path_builder: String_Builder;

    init_string_builder(*shader_file_path_builder);
    print_to_builder(*shader_file_path_builder, base_path);
    
    print_to_builder(*shader_file_path_builder, "Content/Shaders/Compiled/");

    if backend_format & SDL_GPU_SHADERFORMAT_SPIRV {
	shader_format = SDL_GPU_SHADERFORMAT_SPIRV;
	print_to_builder(*shader_file_path_builder, "SPIRV/");
	print_to_builder(*shader_file_path_builder, filename);
	print_to_builder(*shader_file_path_builder, ".spv");
	
    } else if backend_format & SDL_GPU_SHADERFORMAT_MSL {
	shader_format = SDL_GPU_SHADERFORMAT_MSL;
	entry_point = "main0";
	print_to_builder(*shader_file_path_builder, "MSL/");
	print_to_builder(*shader_file_path_builder, filename);
	print_to_builder(*shader_file_path_builder, ".msl");
    } else if backend_format & SDL_GPU_SHADERFORMAT_DXIL {
	shader_format = SDL_GPU_SHADERFORMAT_DXIL;
	print_to_builder(*shader_file_path_builder, "DXIL/");
	print_to_builder(*shader_file_path_builder, filename);
	print_to_builder(*shader_file_path_builder, ".dxil");
    } else {
	log("Unrecognized backend shader format");
	return null, 0, stage, SDL_GPU_SHADERFORMAT_INVALID, "";
    }

    code_size: u64;
    shader_path := builder_to_string(*shader_file_path_builder);

    log("loading shader file at %", shader_path);
    
    shader_path_as_cstring := string_to_cstring(shader_path);
    defer free(shader_path_as_cstring);
    
    code := SDL_LoadFile(shader_path_as_cstring, *code_size);
    
    if code == null {
	log("Failed to load shader from %", shader_path);
	return null, 0, stage, SDL_GPU_SHADERFORMAT_INVALID, "";
    }

    return code, code_size, stage, shader_format, entry_point;
}


load_shader :: (device: *SDL_GPUDevice, filename: string, sampler_count: u32 = 0, uniform_buffer_count: u32 = 0, storage_buffer_count: u32 = 0, storage_texture_count: u32 = 0) -> *SDL_GPUShader {
    code, code_size, stage, format, entry_point := load_shader_file(device, filename);

    if code == null {
	return null;
    }

    defer SDL_free(code);

    entry_point_as_cstring := string_to_cstring(entry_point);
    defer free(entry_point_as_cstring);

    shader_info := SDL_GPUShaderCreateInfo.{
	    code = code,
	    code_size = code_size,
	    entrypoint = entry_point_as_cstring,
	    format = format,
	    stage = stage,
	    num_samplers = sampler_count,
	    num_uniform_buffers = uniform_buffer_count,
	    num_storage_buffers = storage_buffer_count,
	    num_storage_textures = storage_texture_count,
    };

    shader := SDL_CreateGPUShader(device, *shader_info);
    if shader == null {
	log("Failed to create shader from filename: %", filename);
    }

    return shader;
}


create_compute_pipeline_from_shader :: (device: *SDL_GPUDevice, filename: string, create_info: *SDL_GPUComputePipelineCreateInfo) -> *SDL_GPUComputePipeline {
    code, code_size, stage, format, entry_point := load_shader_file(device, filename);

    if code == null {
	return null;
    }

    defer SDL_free(code);

    entry_point_as_cstring := string_to_cstring(entry_point);
    defer free(entry_point_as_cstring);
    
    ci := create_info.*;
    
    ci.code = code;
    ci.code_size = code_size;
    ci.entrypoint = entry_point_as_cstring;
    ci.format = format;


    pipeline := SDL_CreateGPUComputePipeline(device, *ci);
    if pipeline == null {
	log("Failed to create compute pipeline.");
    }

    return pipeline;
}

load_image :: (filename: string, desired_channels: int) -> *SDL_Surface {
    assert(desired_channels == 4);
    filename_as_cstring := string_to_cstring(filename);
    defer free(filename_as_cstring);
    
    result := SDL_LoadBMP(filename_as_cstring);
    if result == null {
	log("Failed to load BMP: %", SDL_GetError());
	return null;
    }

    defer SDL_DestroySurface(result);

    format: SDL_PixelFormat;

    if desired_channels == 4 {
	format = .SDL_PIXELFORMAT_ABGR8888;
    } else {
	log("Unexpected desired channels: %", desired_channels);
	return null;
    }

    if result.format != format {
	next := SDL_ConvertSurface(result, format);
	SDL_DestroySurface(result);
	result = next;
    }

    return result;
}

load_hdr_image :: (filename: string, width: *s32, height: *s32, channels: *s32, desired_channels: s32) -> *float {
    filename_as_cstring := string_to_cstring(filename);
    defer free(filename_as_cstring);
    
    return stbi_loadf(filename_as_cstring, width, height, channels, desired_channels);
}

ASTCHeader :: struct {
    magic: [4] u8;
    blockX: u8;
    blockY: u8;
    blockZ: u8;
    dimX: [3] u8;
    dimY: [3] u8;
    dimZ: [3] u8;
}

DDS_PIXELFORMAT :: struct {
    dwSize:u8;
    dwFlags:u8;
    dwFourCC:u8;
    dwRGBBitCount:u8;
    dwRBitMask:u8;
    dwGBitMask:u8;
    dwBBitMask:u8;
    dwABitMask:u8;
}

DDS_HEADER :: struct {
    dwMagic: int;
    dwSize: int;
    dwFlags: int;
    dwHeight: int;
    dwWidth: int;
    dwPitchOrLinearSize: int;
    dwDepth: int;
    dwMipMapCount: int;
    dwReserved1: [11]int;
    ddspf: DDS_PIXELFORMAT;
    dwCaps: int;
    dwCaps2: int;
    dwCaps3: int;
    dwCaps4: int;
    dwReserved2: int;
}

DDS_HEADER_DXT10 :: struct {
    dxgiFormat: int;
    resourceDimension: int;
    miscFlag: u64;
    arraySize: u64;
    miscFlags2: u64;
}


load_astc_image :: (filename: string, width: *int, height: *int, image_data_length: *int) -> *void {
    size: u64;
    filename_as_cstring := string_to_cstring(filename);
    defer free(filename_as_cstring);
    
    file_contents := SDL_LoadFile(filename_as_cstring, *size);

    if file_contents == null {
	log("Could not load ASTC image at %", filename);
	return null;
    }

    defer SDL_free(file_contents);
    
    header := cast(*ASTCHeader) file_contents;
    if header.magic[0] != 0x13 || header.magic[1] != 0xAB || header.magic[2] != 0xA1 || header.magic[3] != 0x5C {

	log("Bad magic number for ASTC image");
	return null;
    }
    
    width.* = header.dimX[0] + (header.dimX[1] << 8) + (header.dimX[2] << 16);
    height.* = header.dimY[0] + (header.dimY[1] << 8) + (header.dimY[2] << 16);
    
    // Get the size of the texture data
    block_count_x := (width.* + header.blockX - 1) / header.blockX;
    block_count_y := (height.* + header.blockY - 1) / header.blockY;

    image_data_length.* = block_count_x * block_count_y * 16;

    file_content_ptr: *u8 = xx file_contents;  
    data := alloc(image_data_length.*);
    memcpy(data, file_content_ptr + size_of(ASTCHeader), image_data_length.*);
        
    return data;
}

load_dds_image :: (filename: string, format: SDL_GPUTextureFormat, width: *int, height: *int, image_data_length: *int) -> *void {
    size: u64;
    filename_as_cstring := string_to_cstring(filename);
    defer free(filename_as_cstring);
    
    file_contents := SDL_LoadFile(filename_as_cstring, *size);

    if file_contents == null {
	log("Could not load DDS image at %", filename);
	return null;
    }

    defer SDL_free(file_contents);

    header: *DDS_HEADER = xx file_contents;
    if header.dwMagic != 0x20534444 {
	log("Bad magic number for DDS image");
	return null;
    }

    has_dx10_header: bool = header.ddspf.dwFlags == 0x4 && header.ddspf.dwFourCC == 0x30316844;
    header_offset := size_of(DDS_HEADER);
    if has_dx10_header {
	header_offset += size_of(DDS_HEADER_DXT10);
    }
    
    width.* = header.dwWidth;
    height.* = header.dwHeight;
    image_data_length.* = header.dwPitchOrLinearSize;

    file_contents_ptr: *u8 = xx file_contents;
    file_contents_ptr += header_offset;
    data := alloc(image_data_length.*);
    memcpy(data, file_contents_ptr, image_data_length.*);
    
    return data;
}

make_rotation_z :: (radians: float) -> Matrix4 {
    return .{
	cos(radians), sin(radians), 0, 0,
	-sin(radians), cos(radians), 0, 0,
	0, 0, 1, 0,
	0, 0, 0 ,1
    };
}


Vector3_Cross :: (a: Vector3, b: Vector3) -> Vector3 {
    n: Vector3 = ---;

    n.x = a.y * b.z - b.y * a.z;
    n.y = -(a.x * b.z - b.x * a.z);
    n.z = a.x * b.y - b.x * a.y;

    return n;
}

Matrix4x4_CreateOrthographicOffCenter :: (left: float, right: float, bottom: float, top: float, near_plane: float, far_plane: float) -> Matrix4 {
    return .{
	2.0 / (right - left), 0, 0, 0,
	0, 2.0 / (top - bottom), 0, 0,
	0, 0, 1.0 / (near_plane - far_plane), 0,
	(left + right) / (left - right), (top + bottom) / (bottom - top), near_plane / (near_plane - far_plane), 1 
    };
}

Matrix4x4_CreatePerspectiveFieldOfView :: (fov: float, aspect_ratio: float, near_plane_dist: float, far_plane_dist: float) -> Matrix4 {
    num := 1.0 / cast(float) tan(fov * 0.5);
    
    return .{
	num / aspect_ratio, 0, 0, 0,
	0, num, 0, 0,
	0, 0, far_plane_dist / (near_plane_dist - far_plane_dist), -1,
	0, 0, (near_plane_dist * far_plane_dist) / (near_plane_dist - far_plane_dist), 0
    };
    
}


/// todo test this against Math library version
Matrix4x4_CreateLookAt :: (camera_pos: Vector3, target: Vector3, camera_up: Vector3) -> Matrix4 {
    target_to_position := camera_pos - target;

    a := normalize(target_to_position);
    b := normalize(cross(camera_up, a));
    c := cross(a, b);

    return .{
	b.x, c.x, a.x, 0,
	b.y, c.y, a.y, 0,
	b.z, c.z, a.z, 0,
	-dot_product(b, camera_pos), -dot_product(c, camera_pos), -dot_product(a, camera_pos), 1
    };
}

#scope_file

string_to_cstring :: (s: string) -> *u8 { 
    cstring := cast(*u8) alloc(s.count + 1);
    memcpy(cstring, s.data, s.count);
    cstring[s.count] = 0;
    
    return cstring;
}

base_path: string;

init_base_path :: () {
    base_path = copy_string(path_strip_filename(get_path_of_running_executable()));
}
