Prism_Color_Theme :: enum #specified {
    DARK ::  0;
    LIGHT :: 1;
}

// Defaults are for light theme
Prism_Theme :: struct {
    theme : Prism_Color_Theme = .DARK;
    generic_color : Vector4 = NICE_BLUE;
    keymap_color : Vector4 = NICE_BLUE;
    changelog_color : Vector4 = NICE_BLUE;
    console_interactive_text_color : Vector4 = BLACK;
    console_transparent_text_color : Vector4 = BLACK;
    item_list_border_color : Vector4 = NICE_GREY;
    item_list_border_size : float = BORDER_SIZE;
    camera_ui_border_color : Vector4 = NICE_GREY;
    camera_ui_border_size : float = BORDER_SIZE;
    camera_ui_button_border_color : Vector4 = .{110./255, 110./255, 128./255, 128./255};
}

Prism_Theme_Light :: struct {
    using #as base : Prism_Theme;
    theme = .LIGHT;
}

Prism_Theme_Dark :: struct {
    using #as base : Prism_Theme;
    theme = .DARK;
    generic_color = NICE_YELLOW;
    keymap_color = NICE_YELLOW;
    changelog_color = NICE_YELLOW;
    console_interactive_text_color = WHITE;
    camera_ui_button_border_color = BLACK;
}

RED   :: ImGui.ImVec4.{1., 0., 0., 1.};
GREEN :: ImGui.ImVec4.{0., 1., 0., 1.};
BLUE  :: ImGui.ImVec4.{0., 0., 1., 1.};
BLACK :: ImGui.ImVec4.{0., 0., 0., 1.};
WHITE :: ImGui.ImVec4.{1., 1., 1., 1.};
NICE_YELLOW :: ImGui.ImVec4.{1, .8, 0, 1};
NICE_BLUE :: BLUE; // ImGui.ImVec4.{216/255., 109/255., 48/255., 1};
NICE_GREY :: #run color_convert_HSV_to_RGB(0, 0, 80./255, 1);

SELECT_TRIANGLE :: Vector4.{190./255, 186./255, 48./255, 1};
SELECT_SEGMENT :: #run darken(SELECT_TRIANGLE, .8);
SELECT_POINT :: #run darken(SELECT_SEGMENT, .8);
SELECT_VERTEX :: #run darken(SELECT_POINT, .8);

// Junk
// IMGUI_BUTTON_DARK_BLUE :: #run color_u32_as_vector4(0x4296FA); // ImGui.Col.Button for the dark theme
// IMGUI_BUTTON_DARK_BLUE_TETRADIC_GREEN :: #run color_u32_as_vector4(0x2BB12D);
// IMGUI_BUTTON_DARK_BLUE_TETRADIC_PURPLE :: #run color_u32_as_vector4(0xB12BAF);
// IMGUI_BUTTON_DARK_BLUE_TETRADIC_YELLOW :: NICE_YELLOW; // #run color_u32_as_vector4(0xB1702B);

FONT_SIZE :: 58;

BORDER_SIZE :: 2;

// Chosen using the tetradic option here, with the default button color as input https://www.canva.com/colors/color-wheel/
CONTEXT_MENU_POPUP_TARGET_BORDER_COLOR :: ImGui.ImVec4.{43./255, 117./255, 45./255, 1.};
CONTEXT_MENU_POPUP_TARGET_BORDER_SIZE :: BORDER_SIZE;

CONSOLE_DOCUMENTATION_TRANSPARENT :: ImGui.ImVec4.{0., 0., 220./255, 1.};
CONSOLE_COMMENT_TRANSPARENT :: ImGui.ImVec4.{226./255, 127./255, 14./255, 1.};
CONSOLE_WARNING_TRANSPARENT :: ImGui.ImVec4.{0., 78./255, 1., 1.};
CONSOLE_ERROR_TRANSPARENT ::   ImGui.ImVec4.{1., .2, .2, 1.};

CONSOLE_DOCUMENTATION_INTERACTIVE ::  ImGui.ImVec4.{0.5, 0.5, 220./255, 1.};
CONSOLE_COMMENT_INTERACTIVE :: ImGui.ImVec4.{1., .78, .58, 1.};
CONSOLE_WARNING_INTERACTIVE :: ImGui.ImVec4.{0., 178./255, 1., 1.};
CONSOLE_ERROR_INTERACTIVE ::   ImGui.ImVec4.{1., .4, .4, 1.};

color_u32_as_vector4 :: (color : ImGui.ImU32, alpha := 1.) -> ImGui.ImVec4 {
    result := ImGui.ColorConvertU32ToFloat4(color);
    result.w = alpha;
    return result;
}

color_convert_RGB_to_HSV :: (r : float, g : float, b : float, a : float) -> hsv : ImGui.ImVec4 {
    h, s, v : float;
    ImGui.ColorConvertRGBtoHSV(r, g, b, *h, *s, *v);
    return make_ImVec4(h, s, v, a);
}

color_convert_HSV_to_RGB :: (h : float, s : float, v : float, a : float) -> rgb : ImGui.ImVec4 {
    r, g, b : float;
    ImGui.ColorConvertHSVtoRGB(h, s, v, *r, *g, *b);
    return make_ImVec4(r, g, b, a);
}

darken :: (rgb : ImGui.ImVec4, darken_factor : float) -> darker_rgb : ImGui.ImVec4 {
    hsv := color_convert_RGB_to_HSV(rgb.x, rgb.y, rgb.z, rgb.w);
    hsv.z *= darken_factor;
    return color_convert_HSV_to_RGB(hsv.x, hsv.y, hsv.z, hsv.w);
}