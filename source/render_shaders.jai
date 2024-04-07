// @TODO Use GLSL Interface Blocks for transforms and other data global to most shaders
// @TODO Use type variants like Shader_Id :: #type,isa GLuint
// @TODO Add checking (verify all the _loc variables are not -1, verify glIsProgram etc)
// @TODO Add a RenderState struct to capture pipeline state: Culling, Blending, DepthTest, LineWidth...

Shader :: struct {
    program : GLuint;
    type : Type;
}

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
    world_from_model : Matrix4; @Uniform
    view_from_world : Matrix4; @Uniform
    clip_from_view : Matrix4; @Uniform
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

#insert #run generate_uniforms_set_procedure(Clip_Range);
#insert #run generate_uniforms_set_procedure(Clip_Sphere);
#insert #run generate_uniforms_set_procedure(Normal_Style);
#insert #run generate_uniforms_set_procedure(Render_Transforms);

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

    info := type_info(T);

    // We can't overload a set_uniforms function because of this compile error:
    //
    //   Error: Attempt to add an overload of this procedure, but it has already been sealed,
    //   so no further overloads can be added. Any overloads of a single procedure must be added
    //   during the same source code parsing phase. If you want to generate procedures via #insert
    //   or a metaprogram, you have to add all overloads of a procedure at the same time.
    //
    Print("set_uniforms_%1 :: (uniforms : %1_Uniforms, using values : %1) {\n", info.name);
    for member : info.members {
        handle_member(*builder, member);
    }
    Print("}\n");

    text := builder_to_string(*builder);
    //print("%\n", text);
    return text;
}

generate_uniforms_struct :: ($T : Type) -> string {
    builder : String_Builder;

    info := type_info(T);

    Print("%_Uniforms :: struct {\n", info.name);

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

    for member : info.members {
        handle_member(*builder, member);
    }

    Print("}\n");

    return builder_to_string(*builder);
}

Print :: (format_string : string, args : ..Any) #expand {
    print_to_builder(*`builder, format_string, ..args);
} @PrintLike