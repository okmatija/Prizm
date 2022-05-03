RED   :: ImGui.ImVec4.{1., 0., 0., 1.};
GREEN :: ImGui.ImVec4.{0., 1., 0., 1.};
BLUE  :: ImGui.ImVec4.{0., 0., 1., 1.};
BLACK :: ImGui.ImVec4.{0., 0., 0., 1.};
WHITE :: ImGui.ImVec4.{1., 1., 1., 1.};
CONTEXT_MENU_POPUP_TARGET_BORDER_COLOR :: #run color_convert_HSV_to_RGB(0, 0, 80./255, 1);
CONTEXT_MENU_POPUP_TARGET_BORDER_SIZE :: 4;
NICE_YELLOW :: ImGui.ImVec4.{1, .8, 0, 1};
KEYBINDING_COLOR :: NICE_YELLOW;
CHANGELOG_COLOR :: NICE_YELLOW;

CONSOLE_DOCUMENTATION_TRANSPARENT :: ImGui.ImVec4.{0., 0., 220./255, 1.};
CONSOLE_COMMENT_TRANSPARENT :: ImGui.ImVec4.{226./255, 127./255, 14./255, 1.};
CONSOLE_WARNING_TRANSPARENT :: ImGui.ImVec4.{0., 78./255, 1., 1.};
CONSOLE_ERROR_TRANSPARENT ::   ImGui.ImVec4.{1., .2, .2, 1.};
CONSOLE_INFO_TRANSPARENT ::    BLACK;

CONSOLE_DOCUMENTATION_INTERACTIVE ::  ImGui.ImVec4.{0.5, 0.5, 220./255, 1.};
CONSOLE_COMMENT_INTERACTIVE :: ImGui.ImVec4.{1., .78, .58, 1.};
CONSOLE_WARNING_INTERACTIVE :: ImGui.ImVec4.{0., 178./255, 1., 1.};
CONSOLE_ERROR_INTERACTIVE ::   ImGui.ImVec4.{1., .4, .4, 1.};
CONSOLE_INFO_INTERACTIVE ::    WHITE;

color_convert_HSV_to_RGB :: (h : float, s : float, v : float, a : float) -> rgb : ImGui.ImVec4 {
    r, g, b : float;
    ImGui.ColorConvertHSVtoRGB(h, s, v, *r, *g, *b);
    return make_ImVec4(r, g, b, a);
}