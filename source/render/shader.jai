// @Speed We only need to update the uniforms which have changed, so think of a way to couple this code to the UI update code
// @Cleanup We read some shader files more than once. We should just store these inline

Shader :: struct {
    program : GLuint; // nocommit rename to gl_handle
    type : Type;
    uniforms : [..]Shader_Uniform;
    // @Incomplete Maybe also store the shader text here
}

// Convenience function to dispatch to specialized function
init_shader :: (shader : *$T/Shader) {
    shader.init_shader(shader);
}

// Convenience function to set the shader program and set the uniforms
use_shader :: (shader : *$T/Shader, mesh : Simple_Mesh, display_info : Display_Info) {
    shader.use_shader(shader, mesh, display_info);
}
use_shader :: (shader : *$T/Shader, mesh : Simple_Mesh) {
    shader.use_shader(shader, mesh);
}
use_shader :: (shader : *$T/Shader) {
    shader.use_shader(shader);
}

Shader_Uniform :: struct {

    Kind :: enum {
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

        Texture;

        Enum;
        Bool;
    }

    kind : Kind;
    name : string; // Can also be a nested name or array e.g., "my_struct.member_array[3].member_scalar"; @Leak
    location : GLint = -1;
}

cache_shader_uniform_location :: (shader : *Shader, name_string : string, kind : Shader_Uniform.Kind, loc := #caller_location) {
    for *uniform : shader.uniforms {
        if uniform.name == name_string {
            assert(false, "Already initted uniform '%' at index %. Called from %:%:%\n", name_string, it_index, loc.fully_pathed_filename, loc.line_number, loc.character_number);
        }
    }

    // TODO We could sort this array by uniform name so that its faster to look things up in set_shader_uniform
    uniform : *Shader_Uniform = array_add(*shader.uniforms);
    uniform.kind = kind;
    uniform.name = copy_string(name_string);
    uniform.location = glGetUniformLocation(shader.program, temp_c_string(name_string));

    // :InvalidUniformLocationUnusedVariables This assert is annoying when developing shaders since it triggers
    // whenever we comment usage code but leave declarations. Consider disabling it to work on shaders...
    assert(uniform.location != -1,
        "Got -1 location for uniform '%', if you do not use this variable in the shader you should not call glGetUniformLocation (this applies recursively to struct members..!)",
        name_string);
}

Texture_Uniform :: struct {
    texture : *Texture;
    texture_unit : GLenum;
}

set_shader_uniform_value :: (shader : Shader, uniform_name : string, uniform_value : Any, loc := #caller_location) {

    using uniform : Shader_Uniform;
    for * shader.uniforms {
        if it.name == uniform_name {
            uniform = it.*;
            break;
        }
    }
    // Better to check this when the location is created, checking it here is not that helpful...
    //assert(location != -1, "Error at '%:%:%' Location of '%' is -1", loc.fully_pathed_filename, loc.line_number, loc.character_number, uniform_name);

    // @Incomplete print loc in all errors/asserts

    any := *uniform_value; // A shorter alias for the argument

    AssertArray :: ($wanted_tag : Type_Info_Tag, $wanted_count : s64) #expand {
        assert(any.type.type == .ARRAY, "Uniform kind is '%' so wanted array type, got '%'. If you mean to pass vector/matrix data perhaps you forgot .component/.floats", kind, any.type.type);
        info_array := cast(*Type_Info_Array)any.type;
        assert(4 == info_array.element_type.runtime_size);
        assert(wanted_tag == info_array.element_type.type, "Uniform kind is '%' so wanted array element type '%', got '%'", kind, wanted_tag, (cast(*Type_Info_Array)any.type).element_type.type);
        assert(wanted_count == info_array.array_count, "Uniform kind is '%' so wanted array count %, got %", kind, wanted_count);
    }

    if #complete kind == {

    case .Enum;
        assert(any.type.type == .ENUM);
        info_enum := cast(*Type_Info_Enum)any.type;
        glUniform1i(location, (cast(*GLint)any.value_pointer).*);



    case .Bool;
        assert(any.type.type == .BOOL);
        assert(any.type.runtime_size == 1, "Error at '%:%:%' Wanted runtime size 4, got %, for '%'", loc.fully_pathed_filename, loc.line_number, loc.character_number, any.type.runtime_size, uniform_name);
        glUniform1i(location, cast(GLint)((cast(*bool)any.value_pointer).*));



    case .Int1;
        assert(any.type.type == .INTEGER);
        assert(any.type.runtime_size == 4);
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
        assert(any.type.type == .INTEGER);
        assert(any.type.runtime_size == 4);
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




    case .Texture;

        tex := cast(*Texture_Uniform)any.value_pointer;
        assert(tex.texture != null);
        assert(tex.texture.gl_handle != 0);

        glActiveTexture(tex.texture_unit);
        glBindTexture(GL_TEXTURE_2D, tex.texture.gl_handle);
        glUniform1ui(location, tex.texture_unit);

    }
}


// This is an incomplete experiment to generate the code calling cache_shader_uniform_location and set_shader_uniform_value
/*
#insert -> string {
    Uniform_Desc :: struct {
        name : string;
        kind : Shader_Uniform.Kind;
    }

    // Render transform uniforms
    {
        Print :: (format_string : string, args : ..Any) #expand {
            print_to_builder(*`builder, format_string, ..args);
            print_to_builder(*`builder, "\n");
            if ends_with(format_string, "{") indent += 1;
            if ends_with(format_string, "}") indent -= 1;
        } @PrintLike

        builder : String_Builder;
        indent := 0;

        name := "_Render_Transform_Uniforms";
        uniforms := Uniform_Desc.[
            .{"world_from_model", .Matrix4},
            .{"view_from_world", .Matrix4},
            .{"clip_from_view", .Matrix4},
        ];

        Print("/*");

        Print("_Render_Transform_Uniforms :: struct {"); // if you have {\n at end print indents next time
        Print("cache :: (shader : *Shader) {");
        for uniforms {
            // Print the correct glUniformXXX function here
            // Print("cache_shader_uniform_location(shader, \"%\", .%);", it.name, it.kind);
        }
        Print("}");
        Print("\n");
        Print("set :: (shader : *Shader) {");
        for uniforms Print(2, "cache_shader_uniform_location(shader, \"%\", .%);", it.name, it.kind);
        Print("}");
        Print("}");

        Print("*/");

        return builder_to_string(*builder);
    }

    return "";
}
*/
