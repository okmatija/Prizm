render_text :: () {
    // Render the text labels and flash hovered item over everything else
    glClear(GL_DEPTH_BUFFER_BIT);

    // @Incomplete Add option to render points in world coordinates? Model is probably mostly useful for 2D shapes

    //// When we are moving the mouse to rotate the camera dont bother rendering labels since the mouse position is not in a helpful place,
    //// perhaps we can just render the previously shown labels rather than nothing though..! its not helpful to. This also helps with
    //// @Speed, traversing the AABB for large meshes needs profiling!
    //if !mouse_orbit_camera() {
    if !io().WantCaptureMouse {
        if #complete app.settings.labelling_mode == {
            case .RAY_CAST;

                render_entity_text_ray_cast(visit_visible);

            case .SPOTLIGHT;

                render_entity_text_spotlight(visit_visible);
        }
    }
    //}
}

#scope_file

render_entity_text_ray_cast :: ($entity_filter : Code) {

    should_target_points :: (entity : Entity) -> bool {
        return (any_vertex_label_visible(entity) || any_point_label_visible(entity));
    }

    should_target_segments :: (entity : Entity) -> bool {
        return (any_vertex_label_visible(entity) || any_segment_label_visible(entity));
    }

    should_target_triangles :: (entity : Entity) -> bool {
        return (any_vertex_label_visible(entity) || any_triangle_label_visible(entity));
    }

    closest_world : Closest_Point_Ray_Entity = find_closest_element(
        target_points    = should_target_points,
        target_segments  = should_target_segments,
        target_triangles = should_target_triangles
    );

    if closest_world.entity_index == -1 {
        return;
    }

    entity : *Entity = app.entities[closest_world.entity_index];
    if !entity.display_info.is_visible {
        return;
    }

    closest_point_world : Vector3 = get_closest_point_on_element(closest_world);
    if is_clipped(entity.display_info, closest_point_world) {
        return;
    }

    glEnable(GL_BLEND);
    defer glDisable(GL_BLEND);
    // Culling is unhelpful for polygon meshes @Cleanup make this a property on the mesh
    // glDisable(GL_CULL_FACE);
    // defer glEnable(GL_CULL_FACE);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

    labels : [..]Label_Info = temp_array(Element_Type=Label_Info);

    projection_from_world : Matrix4 = make_projection_from_world(app.camera);

    using,except(is_visible) entity.display_info;

    // position_index is an index into the array of mesh.positions, which is filled with v-directive data
    AddVertexAndVertexAnnotationLabels :: (position_world : Vector3, position_model : Vector3, position_index : int) #expand {
        // Note: Since we don't have a mapping from mesh.positions to mesh.points we can't easily add to the point_labels array in this function, but this is kindof an unusual case anyhow: it only occurs if you have a triangle element where the connected positions are also point elements
        //if is_visible(`point_label_theme) {...}

        if any_vertex_label_visible(`entity, annotation_labels=false) {
            text_position_px : Tuple2i = to_screen_position(position_world, `projection_from_world);
            text : string = get_point_text(position_model, position_index, `vertex_label_theme);
            array_add(*`labels, Label_Info.{Label_Kind.VERTEX, text_position_px, text});
        }

        // @Speed this should use the spatial index?? since annotations are sparse, maybe not
        if any_vertex_label_visible(`entity, geometry_labels=false) for :AnnotationIterator annotation : entity {
            if annotation.kind == .VERTEX && annotation.id == position_index {
                text_position_px : Tuple2i = to_screen_position(position_world, `projection_from_world);
                text : string = to_string(annotation);
                array_add(*`labels, Label_Info.{Label_Kind.VERTEX|.ANNOTATION, text_position_px, text});
            }
        }
    }


    if #complete closest_world.closest_point_element == {
    case .VERTEX; // aka position

        // @Think closest_world may never return this case actually?

        // Position and annotation label
        {
            position_world := closest_point_world;
            position_model := transform_point(inverse(entity.mesh.world_from_model), closest_point_world);
            position_index := closest_world.element_index;

            AddVertexAndVertexAnnotationLabels(position_world, position_model, position_index);
        }

    case .POINT;

        // Point label
        if any_point_label_visible(entity, annotation_labels=false) {
            text_position_px : Tuple2i = to_screen_position(closest_point_world, projection_from_world);
            text : string = get_point_text(closest_world.element_index, point_label_theme);
            array_add(*labels, Label_Info.{Label_Kind.POINT, text_position_px, text});
        }

        // Point annotation label
        if any_point_label_visible(entity, geometry_labels=false) for :AnnotationIterator annotation : entity {
            if annotation.kind == .POINT && annotation.id == closest_world.element_index {
                text_position_px : Tuple2i = to_screen_position(closest_point_world, projection_from_world);
                text : string = to_string(annotation);
                array_add(*labels, Label_Info.{Label_Kind.POINT|.ANNOTATION, text_position_px, text});
            }
        }

        // Point position and position annotation labels
        {
            position_world := closest_point_world;
            position_model := transform_point(inverse(entity.mesh.world_from_model), closest_point_world);
            position_index := entity.mesh.points[closest_world.element_index];

            AddVertexAndVertexAnnotationLabels(position_world, position_model, position_index);
        }

    case .SEGMENT;

        // Segment label
        if any_segment_label_visible(entity, annotation_labels=false) {
            text_position_px : Tuple2i = to_screen_position(closest_point_world, projection_from_world);
            text : string = get_point_text(closest_world.element_index, segment_label_theme);
            array_add(*labels, Label_Info.{Label_Kind.SEGMENT, text_position_px, text});
        }

        // Segment annotation label
        if any_segment_label_visible(entity, geometry_labels=false) for :AnnotationIterator annotation : entity {
            if annotation.kind == .LINE && annotation.id == closest_world.element_index {
                text_position_px : Tuple2i = to_screen_position(closest_point_world, projection_from_world);
                text : string = to_string(annotation);
                array_add(*labels, Label_Info.{Label_Kind.SEGMENT|.ANNOTATION, text_position_px, text});
            }
        }

        // Segment position and position annotation labels
        segment_tuple : Tuple2(u32) = mesh_segment3_tuple(entity.mesh, closest_world.element_index);
        segment_model : Segment3 = mesh_segment3_model(entity.mesh, closest_world.element_index);
        segment_world : Segment3 = mesh_segment3_world(entity.mesh, closest_world.element_index);
        for 0..1 {
            position_world := segment_world.p[it];
            position_model := segment_model.p[it];
            position_index := segment_tuple.component[it];

            AddVertexAndVertexAnnotationLabels(position_world, position_model, position_index);
        }

    case .TRIANGLE;

        // Triangle label
        if any_triangle_label_visible(entity, annotation_labels=false) {
            text_position_px : Tuple2i = to_screen_position(closest_point_world, projection_from_world);
            text : string = get_point_text(closest_world.element_index, triangle_label_theme);
            array_add(*labels, Label_Info.{Label_Kind.TRIANGLE, text_position_px, text});
        }

        // Triangle annotation label
        if any_triangle_label_visible(entity, geometry_labels=false) for :AnnotationIterator annotation : entity {
            if annotation.kind == .TRIANGLE && annotation.id == closest_world.element_index {
                text_position_px : Tuple2i = to_screen_position(closest_point_world, projection_from_world);
                text : string = to_string(annotation);
                array_add(*labels, Label_Info.{Label_Kind.TRIANGLE|.ANNOTATION, text_position_px, text});
            }
        }

        // Triangle position and position annotation labels
        triangle_tuple : Tuple3(u32) = mesh_triangle_tuple(entity.mesh, closest_world.element_index);
        triangle_model : Triangle3 = mesh_triangle_model(entity.mesh, closest_world.element_index);
        triangle_world : Triangle3 = mesh_triangle_world(entity.mesh, closest_world.element_index);
        for 0..2 {
            position_world := triangle_world.v[it];
            position_model := triangle_model.v[it];
            position_index := triangle_tuple.component[it];

            AddVertexAndVertexAnnotationLabels(position_world, position_model, position_index);
        }

    case .MESH;

        //  Do nothing

    }

    draw_label_infos(entity, labels);
}

render_entity_text_spotlight :: ($entity_filter : Code) {
    glEnable(GL_BLEND);
    defer glDisable(GL_BLEND);
    // Culling is unhelpful for polygon meshes @Cleanup make this a property on the mesh
    // glDisable(GL_CULL_FACE);
    // defer glEnable(GL_CULL_FACE);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

    projection_from_world : Matrix4 = make_projection_from_world(app.camera);

    FilterIterator :: #bake_arguments EntitiesIterator(entity_filter=entity_filter);
    for :FilterIterator entity, entity_index : app.entities {

        // @TODO pull these arrays out of the entity loop so that label overlapping can be fixed across entities e.g., if mesh A and B have a coincident vertex we'd like the text labels for that vertex not to overlap
        labels : [..]Label_Info = temp_array(Element_Type=Label_Info);

        using,except(is_visible) entity.display_info;

        //
        // Annotation labels
        //

        {
            AddAnnotation :: (point_world : Vector3, label_kind : Label_Kind) #expand {
                if !is_clipped(`entity.display_info, point_world) {
                    text_position_px : Tuple2i = to_screen_position(point_world, projection_from_world);
                    if on_screen_in_disk(text_position_px, app.settings.labelling_radius_px) {
                        text : string = to_string(`annotation);
                        array_add(*`labels, Label_Info.{label_kind, text_position_px, text});
                    }
                }
            }

            // @Speed this should use the spatial index?? since annotations are sparse, maybe not
            if any_vertex_label_visible(entity, geometry_labels=false) for annotation : entity.vertex_annotations {
                point_model := mesh_position_model(entity.mesh, annotation.id);
                point_world := mesh_position_world(entity.mesh, annotation.id);
                AddAnnotation(point_world, Label_Kind.VERTEX|.ANNOTATION);
            }

            if any_point_label_visible(entity, geometry_labels=false) for annotation : entity.point_annotations {
                point_model := mesh_point_model(entity.mesh, annotation.id);
                point_world := mesh_point_world(entity.mesh, annotation.id);
                AddAnnotation(point_world, Label_Kind.POINT|.ANNOTATION);
            }

            if any_segment_label_visible(entity, geometry_labels=false) for annotation : entity.line_annotations {
                point_model := centroid(mesh_segment3_model(entity.mesh, annotation.id));
                point_world := centroid(mesh_segment3_world(entity.mesh, annotation.id));
                AddAnnotation(point_world, Label_Kind.SEGMENT|.ANNOTATION);
            }

            if any_triangle_label_visible(entity, geometry_labels=false) for annotation : entity.face_annotations {
                point_model := compute_centroid(mesh_triangle_model(entity.mesh, annotation.id));
                point_world := transform_point(entity.mesh.world_from_model, point_model);
                AddAnnotation(point_world, Label_Kind.TRIANGLE|.ANNOTATION);
            }
        }

        //
        // Vertex labels
        //

        // @continue FIXME Remove this and instead show the position data for vertices connected to displayed elements
        {
            // @Speed this should use the spatial index??
            if any_vertex_label_visible(entity, annotation_labels=false) for :ModelVertexIterator position_model, position_index : entity.mesh {
                position_world := mesh_position_world(entity.mesh, position_index);
                if !is_clipped(entity.display_info, position_world) {
                    text_position_px : Tuple2i = to_screen_position(position_world, projection_from_world);
                    if on_screen_in_disk(text_position_px, app.settings.labelling_radius_px) {
                        // @Incomplete Add option to render points in world coordinates? Model is probably mostly useful for 2D shapes
                        text : string = get_point_text(position_model, position_index, vertex_label_theme);
                        array_add(*labels, Label_Info.{Label_Kind.VERTEX, text_position_px, text});
                    }
                }
            }
        }

        //
        // Point labels
        //

        {
            if any_point_label_visible(entity, annotation_labels=false) for :ModelPointIterator position_model, point_index : entity.mesh {
                position_world : Vector3 = transform_point(entity.mesh.world_from_model, position_model);

                if !is_clipped(entity.display_info, position_world) {
                    text_position_px : Tuple2i = to_screen_position(position_world, projection_from_world);
                    if on_screen_in_disk(text_position_px, app.settings.labelling_radius_px) {
                        text : string = get_point_text(point_index, point_label_theme);
                        array_add(*labels, Label_Info.{Label_Kind.POINT, text_position_px, text});
                    }
                }
            }
        }

        //
        // Segment labels
        //

        {
            if any_segment_label_visible(entity, annotation_labels=false) for :ModelSegmentIterator segment : entity.mesh {
                point_model : Vector3 = centroid(segment);
                point_world : Vector3 = transform_point(entity.mesh.world_from_model, point_model);

                if !is_clipped(entity.display_info, point_world) {
                    text_position_px : Tuple2i = to_screen_position(point_world, projection_from_world);
                    if on_screen_in_disk(text_position_px, app.settings.labelling_radius_px) {
                        text : string = get_point_text(it_index, segment_label_theme);
                        array_add(*labels, Label_Info.{Label_Kind.SEGMENT, text_position_px, text});
                    }
                }
            }
        }

        //
        // Triangle labels
        //

        {
            Process_Triangle_Data :: struct {
                entity : *Entity;
                projection_from_world : *Matrix4;
                triangle_label_theme : *Element_Label_Theme;
                labels : *[..]Label_Info;
            };

            process_triangle_data : Process_Triangle_Data = ---;
            process_triangle_data.entity                = entity;
            process_triangle_data.projection_from_world = *projection_from_world;
            process_triangle_data.triangle_label_theme  = *triangle_label_theme;
            process_triangle_data.labels                = *labels;

            process_triangle :: (triangle_model : Triangle3, triangle_index : int, data : *void) {
                using process_triangle_data := cast(*Process_Triangle_Data) data;
                point_model : Vector3 = compute_centroid(triangle_model);
                point_world : Vector3 = transform_point(entity.mesh.world_from_model, point_model);
                if !is_clipped(entity.display_info, point_world) {
                    text_position_px : Tuple2i = to_screen_position(point_world, projection_from_world);
                    if on_screen_in_disk(text_position_px, app.settings.labelling_radius_px) {
                        text : string = get_point_text(triangle_index, triangle_label_theme);
                        array_add(labels, Label_Info.{Label_Kind.TRIANGLE, text_position_px, text});
                    }
                }
            }

            if any_triangle_label_visible(entity, annotation_labels=false) {
                if entity.spatial == null {

                    // log_error("Use brute force");
                    for :ModelTriangleIterator entity.mesh {
                        process_triangle(it, it_index, *process_triangle_data);
                    }

                } else {

                    ray_world : Ray3 = make_camera_ray();
                    ray_model : Ray3 = transform_ray(inverse(entity.mesh.world_from_model), ray_world);
                    distance : float = get_model_space_query_radius(entity.render_info.bounding_aabb, app.settings.labelling_radius_px);

                    // log_error("Use spatial index");
                    visit_elements_near_ray(entity.spatial, ray_model, distance, process_triangle, *process_triangle_data);

                }
            }
        }

        draw_label_infos(entity, labels);
    }
}

// @Volatile!!! This function MUST be inlined, we do that right now with expand, but we SHOULD be able to use inline but right now that doesn't work @CompilerBug (see the comment about this in the Any how_to) also do ti
GetPointTextFormatFloat :: (v : float) -> FormatFloat #expand {
    f := app.label_format.format_float;
    f.value = v;
    return f;
}

get_point_text :: (point : Vector2, point_index : int, theme : Vertex_Label_Theme, label_index_offset : int = 0) -> string {
    result : string;
    f :: GetPointTextFormatFloat;
    if  theme.show_index &&  theme.show_position result = tprint("% (%, %)", label_index_offset + point_index, f(point.x), f(point.y));
    if !theme.show_index &&  theme.show_position result = tprint("(%, %)", f(point.x), f(point.y));
    if  theme.show_index && !theme.show_position result = tprint("%", label_index_offset + point_index);
    return result;
}

get_point_text :: (point : Vector3, point_index : int, theme : Vertex_Label_Theme, label_index_offset : int = 0) -> string {
    result : string;
    f :: GetPointTextFormatFloat;
    if  theme.show_index &&  theme.show_position result = tprint("% (%, %, %)", label_index_offset + point_index, f(point.x), f(point.y), f(point.z));
    if !theme.show_index &&  theme.show_position result = tprint("(%, %, %)", f(point.x), f(point.y), f(point.z));
    if  theme.show_index && !theme.show_position result = tprint("%", label_index_offset + point_index);
    return result;
}

get_point_text :: (index : int, theme : Element_Label_Theme, label_index_offset : int = 0) -> string {
    result : string;
    if  theme.show_index result = tprint("%", label_index_offset + index);
    return result;
}

on_screen_in_disk :: (text_position_px : Tuple2i, visible_radius_px : int) -> bool {
    if io().MousePos == ImGui.ImVec2.{-FLOAT32_MAX,-FLOAT32_MAX} {
        return false;
    }

    if text_position_px.x < 0 ||
       text_position_px.y < 0 ||
       text_position_px.x > xx app.window_size.width ||
       text_position_px.y > xx app.window_size.height {
        return false;
    }

    mouse_position := Vector2.{io().MousePos.x, app.window_size.height - io().MousePos.y};
    text_position :=  Vector2.{xx text_position_px.x, xx text_position_px.y};
    if distance(mouse_position, text_position) > xx visible_radius_px {
        return false;
    }

    return true;
}


Label_Kind :: enum_flags u8 {
    // The following are mutually exclusive
    VERTEX;
    POINT;
    SEGMENT;
    TRIANGLE;
    // The above can be combined with this
    ANNOTATION;
}

get_label_font :: (entity : Entity, kind : Label_Kind) -> *ImGui.ImFont, Vector4 {
    using entity.display_info;

    if kind & .ANNOTATION {
        if kind & .VERTEX {
            using vertex_label_theme.annotation_label_theme;
            return get_font(label_scale), label_color;
        }
        if kind & .POINT {
            using point_label_theme.annotation_label_theme;
            return get_font(label_scale), label_color;
        }
        if kind & .SEGMENT {
            using segment_label_theme.annotation_label_theme;
            return get_font(label_scale), label_color;
        }
        if kind & .TRIANGLE {
            using triangle_label_theme.annotation_label_theme;
            return get_font(label_scale), label_color;
        }
    } else {
        if kind & .VERTEX {
            using vertex_label_theme;
            return get_font(label_scale), label_color;
        }
        if kind & .POINT {
            using point_label_theme;
            return get_font(label_scale), label_color;
        }
        if kind & .SEGMENT {
            using segment_label_theme;
            return get_font(label_scale), label_color;
        }
        if kind & .TRIANGLE {
            using triangle_label_theme;
            return get_font(label_scale), label_color;
        }
    }

    log_error("Unreachable");
    using vertex_label_theme;
    return get_font(label_scale), label_color;
}

Label_Info :: struct {
    kind : Label_Kind; // Used to deduce the color/font size from the corresponding theme
    position_px : Tuple2i;
    label : string;
}

draw_label_infos :: (entity : Entity, label_infos : []Label_Info) {
    push_allocator(temp);

    if !label_infos.count return;

    // @CompilerBug why is operator== not found??
    compare_Tuple2i :: (a : Tuple2i, b : Tuple2i) -> bool {
        return a == b;
    }

    label_table : Table(Tuple2i, [..]Label_Info, hash_Tuple2i, compare_Tuple2i);
    init(*label_table, label_infos.count);
    defer deinit(*label_table);

    for label_info : label_infos {
        overlapping_labels : *[..]Label_Info = find_or_add(*label_table, label_info.position_px);
        array_add(overlapping_labels, label_info);
    }

    for overlapping_labels, position_px : label_table {

        // @CompilerBug When I move this to a better place I got an undeclared identifier error for Tuple2i.
        to_imgui_position :: (position_screen : Tuple2i) -> ImGui.ImVec2 {
            return .{cast(float) position_screen.x, cast(float)app.window_size.height - cast(float) position_screen.y};
        }

        window_position := to_imgui_position(position_px);
        window_position_index := cast(int)(window_position.x + app.window_size.width * window_position.y);

        text_size : ImGui.ImVec2;
        for overlapping_labels {
            font, color := get_label_font(entity, it.kind);
            ImGui.PushFont(font);
            defer ImGui.PopFont();
            size := ImGui.CalcTextSize(it.label);
            text_size.x = max(text_size.x, size.x);
            text_size.y += size.y;
        }

        label_window_flags :: ImGui.WindowFlags.NoTitleBar|.NoResize|.NoMove|.NoScrollbar|.NoSavedSettings|.NoInputs;

        LabelWindow(window_position, text_size);

        for overlapping_labels {
            font, color := get_label_font(entity, it.kind);
            ImGui.PushFont(font);
            ImGui.TextColored(color, "%", it.label);
            ImGui.PopFont();
        }
    }
}


// Clipping and camera position are not checked here

any_vertex_label_visible :: (entity : Entity, $geometry_labels := true, $annotation_labels := true) -> bool {
    // We do NOT check entity.display_info.vertex_style.visible here, this option is usually off and we still want to see vertex labels
    return entity.display_info.is_visible && entity.display_info.show_labels /*&& entity.display_info.vertex_style.visible*/ && entity.mesh.positions.count && (
        (geometry_labels   && (entity.display_info.vertex_label_theme.show_index || entity.display_info.vertex_label_theme.show_position)) ||
        (annotation_labels && entity.display_info.vertex_label_theme.annotation_label_theme.visible && entity.vertex_annotations.count)
    );
}

any_point_label_visible :: (entity : Entity, $geometry_labels := true, $annotation_labels := true) -> bool {
    // Also checking mesh.positions.count
    return entity.display_info.is_visible && entity.display_info.show_labels && entity.display_info.point_style.visible && entity.mesh.positions.count && entity.mesh.points.count && (
        (geometry_labels   && entity.display_info.point_label_theme.show_index) ||
        (annotation_labels && entity.display_info.point_label_theme.annotation_label_theme.visible && entity.point_annotations.count)
    );
}

any_segment_label_visible :: (entity : Entity, $geometry_labels := true, $annotation_labels := true) -> bool {
    // Also checking mesh.positions.count
    return entity.display_info.is_visible && entity.display_info.show_labels && entity.display_info.segment_style.visible && entity.mesh.positions.count && entity.mesh.segments.count && (
        (geometry_labels   && entity.display_info.segment_label_theme.show_index) ||
        (annotation_labels && entity.display_info.segment_label_theme.annotation_label_theme.visible && entity.line_annotations.count)
    );
}

any_triangle_label_visible :: (entity : Entity, $geometry_labels := true, $annotation_labels := true) -> bool {
    // @Think Maybe we should check triangle_style.edge_style.visible here?
    // Also checking mesh.positions.count
    return entity.display_info.is_visible && entity.display_info.show_labels && entity.display_info.triangle_style.visible && entity.mesh.positions.count && entity.mesh.triangles.count && (
        (geometry_labels   && entity.display_info.triangle_label_theme.show_index) ||
        (annotation_labels && entity.display_info.triangle_label_theme.annotation_label_theme.visible && entity.face_annotations.count)
    );
}