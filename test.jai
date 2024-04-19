main :: () {
    s : Shader;
    // init_shader_uniform(*s, "clip_sphere", Clip_Sphere);
    // init_shader_uniform(*s, "clip_range[0]", Clip_Range);
    // init_shader_uniform(*s, "clip_range[1]", Clip_Range);
    // init_shader_uniform(*s, "clip_range[2]", Clip_Range);

    init_shader_uniforms(*s, "", Render_Transforms.{});

    init_shader_uniform(*s, "world_from_model", .Matrix4, type_info(Matrix4));


    world_from_model : Matrix4;
    set_shader_uniform(*s, "world_from_model", world_from_model);

    // f : float
    // set_shader_uniform(*s, "world_from_model", f);

    set_shader_uniform(*s, "world_from_model", 1.);


    print_vars(s);
    for s.uniforms {
        print_vars(it_index, it);
    }

    defer print("done!\n");
}


// Shader_Uniform_Type_To_Kind_Map :: 
// Shader_Uniform_Kind_To_Type_Map


Shader :: struct {
    program : GLuint;
    type : Type;
    uniforms : [..]Shader_Uniform;
}

Shader_Uniform :: struct {

    Kind :: enum {
        Int1; // This can be used for bool
        Int2;
        Int3;
        Int4;

        UInt1; // This can be used for bool
        UInt2;
        UInt3;
        UInt4;

        Float1; // This can be used for bool
        Float2;
        Float3;
        Float4;

        Matrix2;
        Matrix3;
        Matrix4;
    }

    kind : Kind;
    name : *u8; // Can also be a nested name or array e.g., "my_struct.member_array[3].member_scalar";
    location : GLint = -1;

    check_type : *Type_Info; // TODO Make this an optional member not present in release builds
}

// nocommit s/any/uniform_value/
// nocommit print loc in all errors/asserts
set_shader_uniform :: (shader : Shader, uniform_name : *u8, any : Any, loc := #caller_location) {

    name_string := to_string(uniform_name);

    using uniform : Shader_Uniform;
    for * shader.uniforms {
        if to_string(it.name) == name_string {
            uniform = it.*;
            break;
        }
    }
    assert(location != -1);

    if check_type {
        assert(check_type == any.type); // @Cleanup With this assert we can remove all the rest
    }

    AssertArray :: ($wanted_tag : Type_Info_Tag, $wanted_count : s64) #expand {
        assert(any.type.type == .ARRAY, "Wanted array type, got '%'", any.type.type);
        assert(wanted_tag == (cast(*Type_Info_Array)any.type).element_type.type, "Wanted array element type '%', got '%'", wanted_tag, (cast(*Type_Info_Array)any.type).element_type.type);
        assert(wanted_count == (cast(*Type_Info_Array)any.type).array_count, "Wanted array count %, got %", wanted_count, );
    }

    if #complete kind == {

    case .Int1;
        assert(any.type.type == .INTEGER || any.type.type == .BOOL);
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
        assert(any.type.type == .INTEGER || any.type.type == .BOOL);
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
        assert(any.type.type == .FLOAT || any.type.type == .BOOL);
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



    case .Matrix2;
        assert(any.type == type_info(Matrix2));
        glUniformMatrix2fv(location, 1, true, *((cast(*Matrix2)any.value_pointer).*)._11);

    case .Matrix3;
        assert(any.type == type_info(Matrix3));
        glUniformMatrix3fv(location, 1, true, *((cast(*Matrix3)any.value_pointer).*)._11);

    case .Matrix4;
        assert(any.type == type_info(Matrix4));
        glUniformMatrix4fv(location, 1, true, *((cast(*Matrix4)any.value_pointer).*)._11);
    }
}


// :CacheUniformLocationsWithCodeNotReflection
// Perhaps its better for debugging/understandablity to rewrite this as code generation to make functions
// call glGetUniformLocation.  Also, this trades compile-time for easier debugging and I guess allows the
// option to manually overwrite functions
/*
cache_uniform_locations :: (shader_name : string, program : GLuint, name : string, data : *void, info : *Type_Info, flatten : bool = false) {

    if info.type == .INTEGER { // Base case

        info_integer := cast(*Type_Info_Integer)info;

        assert(info_integer.runtime_size == size_of(GLuint));

        loc : GLint = glGetUniformLocation(program, temp_c_string(name));
        if loc <  0 then log_error("Unknown parameter: '%' in shader '%'", name, shader_name);
        if loc >= 0 then (cast(*GLuint)data).* = cast(GLuint)loc;

        // Useful for debugging
        //print_vars(loc, name, data);

    } else if info.type == .STRUCT { // Recursive case

        info_struct := cast(*Type_Info_Struct)info;

        // The UseNameAsPrefix note is useful when a application struct contains uniforms that are used different shader stages of the same program
        for member : info_struct.members {
            join := ifx flatten then "_" else ".";
            ext_name := ifx member.flags & .USING then "" else member.name;
            new_name := ifx name then tprint("%1%2%3", name, join, ext_name) else ext_name;
            cache_uniform_locations(shader_name, program, new_name, data + member.offset_in_bytes, member.type, array_find(member.notes, "UseNameAsPrefix"));
        }

    } else if info.type == .ARRAY { // Recursive case

        info_array := cast(*Type_Info_Array)info;

        array_count, array_data := get_array_count_and_data(data, info_array);
        element_size := info_array.element_type.runtime_size;

        for 0..array_count-1 {
            new_name := tprint("%[%]", name, it);
            cache_uniform_locations(shader_name, program, new_name, array_data + it * element_size, info_array.element_type);
        }

    }
}
*/


// Deduce the shader uniforms from members with @Uniform notes in the passed any ()
init_shader_uniforms :: (using shader : *Shader, name : string, any : Any, loc := #caller_location) {
    print_vars(name);

    if any.type.type == {
    case .INTEGER;
    case .FLOAT;
    case .BOOL;
    case .ENUM;
    case .STRUCT;

        info_struct := cast(*Type_Info_Struct)any.type;

        // The UseNameAsPrefix note is useful when a application struct contains uniforms that are used different shader stages of the same program
        for member : info_struct.members {
            if array_find(member.notes, "Uniform") {
                new_name := ifx name then tprint("%1%2%3", name, ".", member.name) else member.name;
                new_any := Any.{type=member.type, value_pointer=any.value_pointer + member.offset_in_bytes};
                // cache_uniform_locations(shader_name, program, new_name, data + member.offset_in_bytes, member.type, array_find(member.notes, "UseNameAsPrefix"));
                init_shader_uniforms(shader, new_name, new_any);
            }
        }

    case .ARRAY;
    case;
        // If you passed Type at the top-level, you probably intended to pass a value, a default/empty struct will be fine, e.g., if you passed My_Struct, pass My_Struct.{} instead
        assert(false, "Passed unsupported type '%' to init_shader_uniform. Called from %:%:%\n", any.type.type, loc.fully_pathed_filename, loc.line_number, loc.character_number);
    }
}

init_shader_uniform :: (using shader : *Shader, name : *u8, kind : Shader_Uniform.Kind, check_type : *Type_Info = null, loc := #caller_location) {
    name_string := to_string(name);
    for *uniform : uniforms {
        if to_string(uniform.name) == name_string {
            assert(false, "Already initted uniform '%' at index %. Called from %:%:%\n", name_string, it_index, loc.fully_pathed_filename, loc.line_number, loc.character_number);
        }
    }

    uniform : *Shader_Uniform = array_add(*uniforms);
    uniform.kind = kind;
    uniform.name = name;
    uniform.location = glGetUniformLocation(program, name);
    uniform.check_type = check_type;
}












Clip_Range :: struct {
    normal : Vector3;          @Uniform // @Cleanup Is this unit???
    is_active : bool;          @Uniform
    min : float = 0hFF800000;  @Uniform // -inf
    max : float = 0h7F800000;  @Uniform // +inf
}

Clip_Sphere :: struct {
    center : Vector3;          @Uniform
    radius := 0h7F800000;      @Uniform // +inf nocommit Make this a constatn
    is_active : bool = false;  @Uniform
}

Render_Transforms :: struct {
    world_from_model : Matrix4;  @Uniform
    view_from_world : Matrix4;   @Uniform
    clip_from_view : Matrix4;    @Uniform
}












GLint :: s32;
GLuint :: u32;
GLfloat :: float32;
GLsizei :: u32;
GLboolean :: bool;  // s8?

gloc : GLint = -1;
glUniform1ui :: (location: GLint, v0: GLuint) {}
glUniform2ui :: (location: GLint, v0: GLuint, v1: GLuint) {}
glUniform3ui :: (location: GLint, v0: GLuint, v1: GLuint, v2: GLuint) {}
glUniform4ui :: (location: GLint, v0: GLuint, v1: GLuint, v2: GLuint, v3: GLuint) {}
glUniform1f :: (location: GLint, v0: GLfloat) {}
glUniform2f :: (location: GLint, v0: GLfloat, v1: GLfloat) {}
glUniform3f :: (location: GLint, v0: GLfloat, v1: GLfloat, v2: GLfloat) {}
glUniform4f :: (location: GLint, v0: GLfloat, v1: GLfloat, v2: GLfloat, v3: GLfloat) {}
glUniform1i :: (location: GLint, v0: GLint) {}
glUniform2i :: (location: GLint, v0: GLint, v1: GLint) {}
glUniform3i :: (location: GLint, v0: GLint, v1: GLint, v2: GLint) {}
glUniform4i :: (location: GLint, v0: GLint, v1: GLint, v2: GLint, v3: GLint) {}
glUniform1fv :: (location: GLint, count: GLsizei, value: *GLfloat) {}
glUniform2fv :: (location: GLint, count: GLsizei, value: *GLfloat) {}
glUniform3fv :: (location: GLint, count: GLsizei, value: *GLfloat) {}
glUniform4fv :: (location: GLint, count: GLsizei, value: *GLfloat) {}
glUniform1iv :: (location: GLint, count: GLsizei, value: *GLint) {}
glUniform2iv :: (location: GLint, count: GLsizei, value: *GLint) {}
glUniform3iv :: (location: GLint, count: GLsizei, value: *GLint) {}
glUniform4iv :: (location: GLint, count: GLsizei, value: *GLint) {}
glUniformMatrix2fv :: (location: GLint, count: GLsizei, transpose: GLboolean, value: *GLfloat) {}
glUniformMatrix3fv :: (location: GLint, count: GLsizei, transpose: GLboolean, value: *GLfloat) {}
glUniformMatrix4fv :: (location: GLint, count: GLsizei, transpose: GLboolean, value: *GLfloat) {}
glGetUniformLocation :: (program : GLuint, name : *u8) -> GLint { gloc += 1; return gloc; };

#import "Basic";
#import "Math";
#import "Print_Vars";
