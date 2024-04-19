Shader :: struct {
    program : GLuint;
    type : Type;
    uniforms : [..]Shader_Uniform;
    // @Incomplete Maybe also store the shader text here
}

// Convenience function to dispatch to specialized function
init_shader :: (shader : *$T/Shader) {
    shader.init_shader(shader);
}

// Convenience function to dispatch to specialized function
set_uniform_values :: (shader : *$T/Shader, mesh : Simple_Mesh, display_info : Display_Info) {
    shader.set_uniform_values(shader, mesh, display_info);
}

// @Cleanup @Speed nocommit We read some shader files more than once. We should just store these inline

Shader_Point_Normal_Vectors :: struct {
    using #as base : Shader;

    init_shader :: (shader : *Shader) {
        VERT, VERT_OK :: #run read_entire_file("source/render/normals.vert"); #assert(VERT_OK);
        GEOM, GEOM_OK :: #run read_entire_file("source/render/normals_points.geom"); #assert(GEOM_OK);
        FRAG, FRAG_OK :: #run read_entire_file("source/render/normals.frag"); #assert(FRAG_OK);
        shader.program = get_shader_program(VERT, FRAG, GEOM);
        cache_shader_uniform_locations_normal_vectors(shader);
    }

    set_uniform_values :: (shader : *Shader, using mesh : Simple_Mesh, using display_info : Display_Info) {
        set_uniform_values_normal_vectors(shader, mesh, point_style.normal_style, clip_sphere, clip_ranges);
    }
}

Shader_Segment_Normal_Vectors :: struct {
    using #as base : Shader;

    init_shader :: (shader : *Shader) {
        VERT, VERT_OK :: #run read_entire_file("source/render/normals.vert"); #assert(VERT_OK);
        GEOM, GEOM_OK :: #run read_entire_file("source/render/normals_segments.geom"); #assert(GEOM_OK);
        FRAG, FRAG_OK :: #run read_entire_file("source/render/normals.frag"); #assert(FRAG_OK);
        shader.program = get_shader_program(VERT, FRAG, GEOM);
        cache_shader_uniform_locations_normal_vectors(shader);
    }

    set_uniform_values :: (shader : *Shader, using mesh : Simple_Mesh, using display_info : Display_Info) {
        set_uniform_values_normal_vectors(shader, mesh, segment_style.normal_style, clip_sphere, clip_ranges);
    }
}

Shader_Triangle_Normal_Vectors :: struct {
    using #as base : Shader;

    init_shader :: (shader : *Shader) {
        VERT, VERT_OK :: #run read_entire_file("source/render/normals.vert"); #assert(VERT_OK);
        GEOM, GEOM_OK :: #run read_entire_file("source/render/normals_triangles.geom"); #assert(GEOM_OK);
        FRAG, FRAG_OK :: #run read_entire_file("source/render/normals.frag"); #assert(FRAG_OK);
        shader.program = get_shader_program(VERT, FRAG, GEOM);
        cache_shader_uniform_locations_normal_vectors(shader);
    }

    set_uniform_values :: (shader : *Shader, using mesh : Simple_Mesh, using display_info : Display_Info) {
        set_uniform_values_normal_vectors(shader, mesh, triangle_style.normal_style, clip_sphere, clip_ranges);
    }
}





Shader_Uniform :: struct {

    Kind :: enum {
        Bool;

        Int1;
        Int2;
        Int3;
        Int4;

        UInt1;
        UInt2;
        UInt3;
        UInt4;

        Float1;
        Float2;
        Float3;
        Float4;

        Matrix2;
        Matrix3;
        Matrix4;
    }

    kind : Kind;
    name : string; // Can also be a nested name or array e.g., "my_struct.member_array[3].member_scalar"; @Leak
    location : GLint = -1;
}

#scope_file

cache_shader_uniform_locations_normal_vectors :: (shader : *Shader) {
    cache_shader_uniform_location(shader, "world_from_model", .Matrix4);
    cache_shader_uniform_location(shader, "view_from_world", .Matrix4);
    cache_shader_uniform_location(shader, "clip_from_view", .Matrix4);
    cache_shader_uniform_location(shader, "normal_style_color", .Float4);
    cache_shader_uniform_location(shader, "normal_style_scale", .Float1);
    cache_shader_uniform_location(shader, "normal_style_normalized", .Bool);
    cache_shader_uniform_location(shader, "clip_sphere.center", .Float3);
    cache_shader_uniform_location(shader, "clip_sphere.radius", .Float1);
    cache_shader_uniform_location(shader, "clip_sphere.is_active", .Bool);
    for 0..2 {
        cache_shader_uniform_location(shader, tprint("clip_range[%].is_active", it), .Bool);
        cache_shader_uniform_location(shader, tprint("clip_range[%].normal", it), .Float3);
        cache_shader_uniform_location(shader, tprint("clip_range[%].max", it), .Float1);
        cache_shader_uniform_location(shader, tprint("clip_range[%].min", it), .Float1);
    }
}

set_uniform_values_normal_vectors :: (shader : *Shader, using mesh : Simple_Mesh, normal_style : Normal_Style, clip_sphere : Clip_Sphere, clip_ranges : [3]Clip_Range) {
    view_from_world := make_look_at_matrix(app.camera);
    clip_from_view := make_orthographic_projection_matrix(app.camera);

    set_shader_uniform_value(shader, "world_from_model", world_from_model.floats);
    set_shader_uniform_value(shader, "view_from_world", view_from_world.floats);
    set_shader_uniform_value(shader, "clip_from_view", clip_from_view.floats);
    set_shader_uniform_value(shader, "normal_style_color", normal_style.color.component);
    set_shader_uniform_value(shader, "normal_style_scale", normal_style.scale);
    set_shader_uniform_value(shader, "normal_style_normalized", normal_style.normalized);
    set_shader_uniform_value(shader, "clip_sphere.center", clip_sphere.center.component);
    set_shader_uniform_value(shader, "clip_sphere.radius", clip_sphere.radius);
    set_shader_uniform_value(shader, "clip_sphere.is_active", clip_sphere.is_active);
    for 0..2 {
        set_shader_uniform_value(shader, tprint("clip_range[%].is_active", it), clip_ranges[it].is_active);
        set_shader_uniform_value(shader, tprint("clip_range[%].normal", it), clip_ranges[it].normal.component);
        set_shader_uniform_value(shader, tprint("clip_range[%].max", it), clip_ranges[it].max);
        set_shader_uniform_value(shader, tprint("clip_range[%].min", it), clip_ranges[it].min);
    }
}



cache_shader_uniform_location :: (using shader : *Shader, name_string : string, kind : Shader_Uniform.Kind, loc := #caller_location) {
    for *uniform : uniforms {
        if uniform.name == name_string {
            assert(false, "Already initted uniform '%' at index %. Called from %:%:%\n", name_string, it_index, loc.fully_pathed_filename, loc.line_number, loc.character_number);
        }
    }

    // TODO We could sort this array by uniform name so that its faster to look things up in set_shader_uniform
    uniform : *Shader_Uniform = array_add(*uniforms);
    uniform.kind = kind;
    uniform.name = copy_string(name_string);
    uniform.location = glGetUniformLocation(program, temp_c_string(name_string));
}

set_shader_uniform_value :: (shader : Shader, uniform_name : string, uniform_value : Any, loc := #caller_location) {

    using uniform : Shader_Uniform;
    for * shader.uniforms {
        if it.name == uniform_name {
            uniform = it.*;
            break;
        }
    }
    assert(location != -1, "Error at '%:%:%' Location of '%' is -1", loc.fully_pathed_filename, loc.line_number, loc.character_number, uniform_name);

    // @Incomplete print loc in all errors/asserts

    any := *uniform_value; // A shorter alias for the argument

    AssertArray :: ($wanted_tag : Type_Info_Tag, $wanted_count : s64) #expand {
        assert(any.type.type == .ARRAY, "Uniform kind is '%' so wanted array type, got '%'", kind, any.type.type);
        info_array := cast(*Type_Info_Array)any.type;
        assert(4 == info_array.element_type.runtime_size);
        assert(wanted_tag == info_array.element_type.type, "Uniform kind is '%' so wanted array element type '%', got '%'", kind, wanted_tag, (cast(*Type_Info_Array)any.type).element_type.type);
        assert(wanted_count == info_array.array_count, "Uniform kind is '%' so wanted array count %, got %", kind, wanted_count);
    }

    if #complete kind == {

    case .Bool;
        assert(any.type.runtime_size == 1, "Error at '%:%:%' Wanted runtime size 4, got %", loc.fully_pathed_filename, loc.line_number, loc.character_number, any.type.runtime_size);
        assert(any.type.type == .BOOL);
        glUniform1i(location, (cast(*GLint)any.value_pointer).*);



    case .Int1;
        assert(any.type.runtime_size == 4);
        assert(any.type.type == .INTEGER);
        glUniform1i(location, (cast(*GLint)any.value_pointer).*);

    case .Int2;
        AssertArray(.INTEGER, 2);
        int2 := cast(*GLint)any.value_pointer;
        glUniform2i(location, int2[0], int2[1]);

    case .Int3;
        AssertArray(.INTEGER, 3);
        int3 := cast(*GLint)any.value_pointer;
        glUniform3i(location, int3[0], int3[1], int3[2]);

    case .Int4;
        AssertArray(.INTEGER, 4);
        int4 := cast(*GLint)any.value_pointer;
        glUniform4i(location, int4[0], int4[1], int4[2], int4[3]);



    case .UInt1;
        assert(any.type.runtime_size == 4);
        assert(any.type.type == .INTEGER);
        glUniform1ui(location, (cast(*GLuint)any.value_pointer).*);

    case .UInt2;
        AssertArray(.INTEGER, 2);
        uint2 := cast(*GLuint)any.value_pointer;
        glUniform2ui(location, uint2[0], uint2[1]);

    case .UInt3;
        AssertArray(.INTEGER, 3);
        uint3 := cast(*GLuint)any.value_pointer;
        glUniform3ui(location, uint3[0], uint3[1], uint3[2]);

    case .UInt4;
        AssertArray(.INTEGER, 4);
        uint4 := cast(*GLuint)any.value_pointer;
        glUniform4ui(location, uint4[0], uint4[1], uint4[2], uint4[3]);



    case .Float1;
        assert(any.type.type == .FLOAT);
        glUniform1f(location, (cast(*GLfloat)any.value_pointer).*);

    case .Float2;
        AssertArray(.FLOAT, 2);
        float2 := cast(*GLfloat)any.value_pointer;
        glUniform2f(location, float2[0], float2[1]);

    case .Float3;
        AssertArray(.FLOAT, 3);
        float3 := cast(*GLfloat)any.value_pointer;
        glUniform3f(location, float3[0], float3[1], float3[2]);

    case .Float4;
        AssertArray(.FLOAT, 4);
        float4 := cast(*GLfloat)any.value_pointer;
        glUniform4f(location, float4[0], float4[1], float4[2], float4[3]);


    // For Matricies we could just assert that the type_info matches MatrixN, but we chose not to do that to be consistent with Vectors

    case .Matrix2;
        AssertArray(.FLOAT, 4);
        glUniformMatrix2fv(location, 1, true, *((cast(*Matrix2)any.value_pointer).*)._11);

    case .Matrix3;
        AssertArray(.FLOAT, 9);
        glUniformMatrix3fv(location, 1, true, *((cast(*Matrix3)any.value_pointer).*)._11);

    case .Matrix4;
        AssertArray(.FLOAT, 16);
        glUniformMatrix4fv(location, 1, true, *((cast(*Matrix4)any.value_pointer).*)._11);
    }
}