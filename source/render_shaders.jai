// @TODO Use GLSL Interface Blocks for transforms and other data global to most shaders
// @TODO Use type variants like Shader_Id :: #type,isa GLuint
// @TODO Add checking (verify all the _loc variables are not -1, verify glIsProgram etc)
// @TODO Add a RenderState struct to capture pipeline state: Culling, Blending, DepthTest, LineWidth...

// nocommit Make a Shader_Uniform struct, a tagged union of all uniform types
// nocommit We don't actually update most uniforms except the camera ones very often


Shader :: struct {
    program : GLuint;
    type : Type;

    //uniforms : [..]Shader_Uniform;

    // Derived structs should define a uniforms variable with GLint members, or an auto-generated _Uniforms struct
    //uniforms : struct { ... };
}

/*
// nocommit s/any/uniform_value/
// nocommit print loc in all errors/asserts
set_shader_uniform :: (shader : Shader, uniform_name : *u8, any : Any, loc := #caller_location) {

    name_string := to_string(uniform_name);

    uniform : Shader_Uniform;
    for * shader.uniforms {
        if to_string(it.name) == name_string {
            uniform = it.*;
            break;
        }
    }
    assert(uniform.location != -1);

    AssertArray :: ($element_type_tag : Type_Info_Tag, $count : s64) #expand {
        assert(any.type.type == .ARRAY);
        assert((cast(*Type_Info_Array)any.type).element_type.type == element_type_tag);
        assert((cast(*Type_Info_Array)any.type).array_count == count);
    }

    if #complete uniform.type == {

    case .Int1;
        assert(any.type.type == .INTEGER || any.type.type == .BOOL);
        glUniform1i(location, cast(GLint)any.value_pointer.*);

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
        glUniform1ui(location, cast(GLuint)any.value_pointer.*);

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
        glUniform1f(location, cast(GLfloat)any.value_pointer.*);

    case .Float2;
        AssertArray(.FLOAT, 2);
        glUniform2f(location, uniform.float2[0], uniform.float2[1]);

    case .Float3;
        AssertArray(.FLOAT, 3);
        glUniform3f(location, uniform.float3[0], uniform.float3[1], uniform.float3[2]);

    case .Float4;
        AssertArray(.FLOAT, 4);
        glUniform4f(location, uniform.float4[0], uniform.float4[1], uniform.float4[2], uniform.float4[3]);



    case .Matrix2;
        assert(any.type == type_info(Matrix2));
        glUniformMatrix2fv(location, 1, true, *(cast(*Matrix2)any.value_pointer.*)._11);

    case .Matrix3;
        assert(any.type == type_info(Matrix3));
        glUniformMatrix3fv(location, 1, true, *(cast(*Matrix3)any.value_pointer.*)._11);

    case .Matrix4;
        assert(any.type == type_info(Matrix4));
        glUniformMatrix4fv(location, 1, true, *(cast(*Matrix4)any.value_pointer.*)._11);
    }
}

cache_uniform :: (using shader : *Shader, name : *u8, kind : Shader_Uniform.Kind, loc := #caller_location) {
    name_string := to_string(name);
    for *uniform : uniforms {
        if to_string(uniform.name) == name_string {
            print("nocommit Error at %:%:%: already cached uniform '%' at index %\n", loc.fully_pathed_filename, loc.line_number, loc.character_number, name_string, it_index);
            assert(false);
        }
    }

    uniform : *Shader_Uniform = array_add(*uniforms);
    uniform.kind = kind;
    uniform.name = name;
    uniform.location = glGetUniformLocation(program, name);
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
}

//Shader_Triangles :: struct {
//    using #as base : Shader;
//    type = Shader_Point_Normal_Vectors;
//
//    uniforms : struct {
//        wave : GLuint;
//        using render_transforms : Render_Transforms_Uniforms;
//        normal_style : Normal_Style_Uniforms; @UseNameAsPrefix
//        clip_sphere : Clip_Sphere_Uniforms;
//        clip_range : [3]Clip_Range_Uniforms;
//    }
//}
*/

Shader_Point_Normal_Vectors :: struct {
    using #as base : Shader;
    type = Shader_Point_Normal_Vectors;

    uniforms : struct {
        using render_transforms : Render_Transforms_Uniforms;
        normal_style : Normal_Style_Uniforms; @UseNameAsPrefix
        clip_sphere : Clip_Sphere_Uniforms;
        clip_range : [3]Clip_Range_Uniforms;
    };
}

Shader_Segment_Normal_Vectors :: struct {
    using #as base : Shader;
    type = Shader_Segment_Normal_Vectors;

    uniforms : struct {
        using render_transforms : Render_Transforms_Uniforms;
        normal_style : Normal_Style_Uniforms; @UseNameAsPrefix
        clip_sphere : Clip_Sphere_Uniforms;
        clip_range : [3]Clip_Range_Uniforms;
    };
}

Shader_Triangle_Normal_Vectors :: struct {
    using #as base : Shader;
    type = Shader_Triangle_Normal_Vectors;

    uniforms : struct {
        using render_transforms : Render_Transforms_Uniforms;
        normal_style : Normal_Style_Uniforms; @UseNameAsPrefix
        clip_sphere : Clip_Sphere_Uniforms;
        clip_range : [3]Clip_Range_Uniforms;
    };
}

Render_Transforms :: struct {
    world_from_model : Matrix4;  @Uniform
    view_from_world : Matrix4;   @Uniform
    clip_from_view : Matrix4;    @Uniform
}

make_render_transforms :: (world_from_model : Matrix4) -> Render_Transforms {
    result : Render_Transforms;
    result.world_from_model = world_from_model;
    result.view_from_world = make_look_at_matrix(app.camera);
    result.clip_from_view = make_orthographic_projection_matrix(app.camera);
    return result;
}

#insert #run generate_uniforms_struct(Clip_Range);
#insert #run generate_uniforms_struct(Clip_Sphere);
#insert #run generate_uniforms_struct(Normal_Style);
#insert #run generate_uniforms_struct(Render_Transforms);
#insert #run generate_uniforms_struct(Triangle_Style);

#insert #run generate_uniforms_set_procedure(Clip_Range);
#insert #run generate_uniforms_set_procedure(Clip_Sphere);
#insert #run generate_uniforms_set_procedure(Normal_Style);
#insert #run generate_uniforms_set_procedure(Render_Transforms);
#insert #run generate_uniforms_set_procedure(Triangle_Style);

// :CacheUniformLocationsWithCodeNotReflection
//#insert #run generate_uniforms_cache_locations_procedure();

#scope_file

skip_member :: (member : Type_Info_Struct_Member) -> bool {
    for note : member.notes {
        if note == "Uniform" return false;
    }
    return true;
}

generate_uniforms_set_procedure :: ($T : Type) -> string {
    builder : String_Builder;

    handle_member :: (builder : *String_Builder, member : Type_Info_Struct_Member) {

        Print :: (format_string : string, args : ..Any) #expand {
            print_to_builder(`builder, format_string, ..args);
        } @PrintLike

        if skip_member(member) return;

        if member.flags & .USING {

            for using_member : (cast(*Type_Info_Struct)member.type).members {
                handle_member(builder, using_member);
            }

        } else {

            if member.type.type == .INTEGER {

                info_integer := cast(*Type_Info_Integer)member.type;

                if info_integer.signed {

                    Print("    glUniform1i(uniforms.%1, %1);\n", member.name);

                } else {

                    Print("    glUniform1ui(uniforms.%1, %1);\n", member.name);

                }

            } else if member.type.type == .FLOAT {

                Print("    glUniform1f(uniforms.%1, %1);\n", member.name);

            } else if member.type.type == .BOOL {

                Print("    glUniform1f(uniforms.%1, cast(GLfloat)%1);\n", member.name); // Can use 1f for bool

            } else if member.type.type == .ENUM {

                info_enum := cast(*Type_Info_Enum)member.type;

                if info_enum.internal_type.signed {

                    Print("    glUniform1i(uniforms.%1, %1);\n", info_enum.name);

                } else {

                    Print("    glUniform1ui(uniforms.%1, %1);\n", info_enum.name);

                }

            } else if member.type.type == .STRUCT {

                handle_member_struct :: (builder : *String_Builder, member_name : string, member : Type_Info_Struct_Member) {
                    info_struct := cast(*Type_Info_Struct)member.type;

                    if info_struct == type_info(Vector2) {

                        Print("    glUniform2f(uniforms.%1, %1.x, %1.y);\n", member_name);

                    } else if info_struct == type_info(Vector3) {

                        Print("    glUniform3f(uniforms.%1, %1.x, %1.y, %1.z);\n", member_name);

                    } else if info_struct == type_info(Vector4) {

                        Print("    glUniform4f(uniforms.%1, %1.x, %1.y, %1.z, %1.w);\n", member_name);

                    } else if info_struct == type_info(Matrix4) {

                        Print("    glUniformMatrix4fv(uniforms.%1, 1, true, *%1._11);\n", member_name);

                    } else {

                        // Recurse
                        for member : info_struct.members {
                            ext_name := ifx member.flags & .USING then "" else member.name;
                            use_name := ifx member_name then tprint("%1.%2", member_name, ext_name) else ext_name;
                            handle_member_struct(builder, use_name, member);
                        }

                        //compiler_report(tprint("Unhandled struct '%'\n", info_struct.name));

                    }
                }

                info_struct := cast(*Type_Info_Struct)member.type;
                handle_member_struct(builder, member.name, member);

            } else {

                compiler_report(tprint("Unhandled type '%'\n", member.type.type));

            }
        }
    }
    return true;
}

generate_uniforms_struct :: ($T : Type) -> string {
    handle_member :: (builder : *String_Builder, member : Type_Info_Struct_Member) {
        if skip_member(member) return;

        if member.flags & .USING {
            for using_member : (cast(*Type_Info_Struct)member.type).members {
                handle_member(builder, using_member); // Recursive case
            }
        } else {
            print_to_builder(builder, "    % : GLint = -1;\n", member.name); // Base case
        }
    }

    info := type_info(T);

    builder : String_Builder;
    print_to_builder(*builder, "%_Uniforms :: struct {\n", info.name);
    for member : info.members {
        handle_member(*builder, member);
    }
    print_to_builder(*builder, "}\n");

    return builder_to_string(*builder);
}