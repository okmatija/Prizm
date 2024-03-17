// @Incomplete Demo mode: Rendering key and mouse state to the viewport to help with recording gifs etc. This will make it easier to demo prizm, there can be UI/options for:
// - Configuring where to put the text e.g., follow the cursor, text color etc
// - There should be a TTL option on the demo text and a stack that pushes older text down while it fades

do_demo_mode :: () {
    /* nocommit :Linux
    if !app.demo_mode return;

    if io_mouse_left_down() {
        // [-1, 1]x[-1,1] -> [0, current_window_width]x[0, current_window_height]
        text_position_11 : Vector2;
        text_position_11.x = 0;
        text_position_11.y = 0.9;
        text_position_px : Tuple2i;
        text_position_px.x = xx (app.current_window_width *  (text_position_11.x + 1) / 2);
        text_position_px.y = xx (app.current_window_height * (text_position_11.y + 1) / 2);

        Simp.ScopeContext();
        glEnable(GL_BLEND);
        defer glDisable(GL_BLEND);
        // Culling is unhelpful for polygon meshes @Cleanup make this a property on the mesh
        // glDisable(GL_CULL_FACE);
        // defer glEnable(GL_CULL_FACE);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

        quads : [..]Simp.Font_Quad = temp_array(Element_Type=Simp.Font_Quad);
        cache_text_quads(*quads, ifx io().KeyCtrl then "Ctrl LMB" else "LMB", text_position_px, 1);
        draw_cached_text_quads(quads, .{0,0,0,1});
    }

    if io_mouse_right_down() {
        // [-1, 1]x[-1,1] -> [0, current_window_width]x[0, current_window_height]
        text_position_11 : Vector2;
        text_position_11.x = 0;
        text_position_11.y = 0.9;
        text_position_px : Tuple2i;
        text_position_px.x = xx (app.current_window_width *  (text_position_11.x + 1) / 2);
        text_position_px.y = xx (app.current_window_height * (text_position_11.y + 1) / 2);

        Simp.ScopeContext();
        glEnable(GL_BLEND);
        defer glDisable(GL_BLEND);
        // Culling is unhelpful for polygon meshes @Cleanup make this a property on the mesh
        // glDisable(GL_CULL_FACE);
        // defer glEnable(GL_CULL_FACE);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

        quads : [..]Simp.Font_Quad = temp_array(Element_Type=Simp.Font_Quad);
        cache_text_quads(*quads, "RMB", text_position_px, 1);
        draw_cached_text_quads(quads, .{0,0,0,1});
    }

    if io_mouse_middle_down() {
        // [-1, 1]x[-1,1] -> [0, current_window_width]x[0, current_window_height]
        text_position_11 : Vector2;
        text_position_11.x = 0;
        text_position_11.y = 0.9;
        text_position_px : Tuple2i;
        text_position_px.x = xx (app.current_window_width *  (text_position_11.x + 1) / 2);
        text_position_px.y = xx (app.current_window_height * (text_position_11.y + 1) / 2);

        Simp.ScopeContext();
        glEnable(GL_BLEND);
        defer glDisable(GL_BLEND);
        // Culling is unhelpful for polygon meshes @Cleanup make this a property on the mesh
        // glDisable(GL_CULL_FACE);
        // defer glEnable(GL_CULL_FACE);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

        quads : [..]Simp.Font_Quad = temp_array(Element_Type=Simp.Font_Quad);
        cache_text_quads(*quads, "MMB", text_position_px, 1);
        draw_cached_text_quads(quads, .{0,0,0,1});
    }
    */
}