// Per-entity GPU-side state -- bounding geometry used by pick/fit, GPU buffers in sdlgpu_render.jai.
Render_Info :: struct {
    is_dirty := true;

    // Bounding geometry in entity model space -- used by fit_scene_on_screen and picking.
    bounding_sphere : Sphere;
    bounding_aabb   : AxisBox3;
}

// Computes bounding sphere and AABB from the mesh; called by fit_scene_on_screen via
// entity_raw_world_bounding_sphere. GPU buffer upload is handled separately in sdlgpu_render.jai.
maybe_update_render_info :: (info : *Render_Info, mesh : *Simple_Mesh) {
    if mesh.positions.count == 0  return;
    assert(mesh.positions.count == mesh.colors.count);

    if info.is_dirty {
        defer info.is_dirty = false;
        info.bounding_sphere = bounding_sphere_ritter(mesh.positions);
        info.bounding_aabb   = make_axis_box3(..mesh.positions);
    }
}

// Entity visibility iterators -- exported so sdlgpu_render.jai and other callers can use them.
entity_in_clip_radius_mode :: (entity_index : int) -> bool {
    return mouse_set_clip_radius() && app.clipping_sphere_mode_entity_index >= 0 &&
    (
        ( app.entities[app.clipping_sphere_mode_entity_index].is_selected && app.entities[entity_index].is_selected) ||
        (!app.entities[app.clipping_sphere_mode_entity_index].is_selected && app.clipping_sphere_mode_entity_index == entity_index)
    );
}

not_visible_opaque ::      #code !(is_visible(it) && !it.is_hovered && it.display_info.triangle_style.color.w == 1.);
not_visible_transparent :: #code !(is_visible(it) && !it.is_hovered && it.display_info.triangle_style.color.w != 1.);
not_visible_hovered ::     #code !(is_visible(it) &&  it.is_hovered);

VisibleOpaque ::      #bake_arguments EntitiesIterator(entity_filter=not_visible_opaque);
VisibleTransparent :: #bake_arguments EntitiesIterator(entity_filter=not_visible_transparent);
VisibleHovered ::     #bake_arguments EntitiesIterator(entity_filter=not_visible_hovered);
