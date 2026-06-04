// CPU-side screen-space projection helper used by label placement.
to_screen_position :: (point_space : Vector3, projection_from_space : Matrix4) -> Tuple2i {
    result : Tuple2i = ---;
    // [-1, 1]x[-1,1] -> [0, window_size.width]x[0, window_size.height]
    transformed := transform_point(projection_from_space, point_space);
    result.x = xx (app.window_size.width  * (transformed.x + 1) / 2);
    result.y = xx (app.window_size.height * (transformed.y + 1) / 2);
    return result;
}

debug_text_at_cursor :: (text : string, color : Vector4 = .{0, 0, 0, 1}, font : *ImGui.ImFont = null) {

    if !ImGui.IsAnyMouseDown() return;

    if font {
        push_font(font);
    }

    window_position := io().MousePos;
    window_size := ImGui.CalcTextSize(text);

    LabelWindow2 :: (window_position : Vector2, window_size : Vector2) #expand {
        label_window_flags :: ImGui.WindowFlags.NoTitleBar|.NoResize|.NoMove|.NoScrollbar|.NoSavedSettings|.NoInputs|.NoMouseInputs|.NoBackground;

        window_position_index := cast(int)(window_position.x + app.window_size.width * window_position.y);

        ImGui.SetNextWindowSize(.{65, 50});
        ImGui.SetNextWindowPos(window_position - .{-3, window_size.y} + app.settings.labelling_offset);
        ImGui.SetNextWindowBgAlpha(0.);

        ImGui.Begin(imgui_label("Labels", xx window_position_index), flags=label_window_flags);
        `defer ImGui.End();
    }

    LabelWindow2(window_position, window_size);

    ImGui.TextColored(color, "%", text);

    if font {
        ImGui.PopFont();
    }
}
