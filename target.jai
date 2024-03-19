main :: () {
    // With the following line in main() the compilation hangs.
    Simp.update_window(get_window_type(null));
}

ImGui :: #import "ImGui";
Simp :: #import "Simp";