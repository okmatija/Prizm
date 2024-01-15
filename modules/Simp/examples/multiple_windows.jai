window_a: Window_Type;
window_b: Window_Type;

window_a_width  : s32 = 800;
window_a_height : s32 = 600;

window_b_width  : s32 = 800;
window_b_height : s32 = 600;

window_a_font: *Simp.Dynamic_Font;
window_b_font: *Simp.Dynamic_Font;

FONT_A_SCALE :: 1 / 24.0;  // 1/24th of the screen height.
FONT_B_SCALE :: 1 / 10.0;  // 1/10th of the screen height.

main :: () {
    #if OS == .WINDOWS {
        Windows.SetProcessDPIAware();

        // Windows is very bad at thread-switching by default unless you do this. Sad.
        Windows :: #import "Windows";
        Windows.timeBeginPeriod(1);
    }

    window_a = create_window(window_a_width, window_a_height, "A Window");
    window_b = create_window(window_b_width, window_b_height, "B Window", window_a_width);

    // Actual render size in pixels can be different from the window dimensions we specified above (for example on high-resolution displays on macOS/iOS).
    window_a_width, window_a_height = Simp.get_render_dimensions(window_a);
    window_b_width, window_b_height = Simp.get_render_dimensions(window_b);

    my_init_fonts(*window_a_font, window_a_width, window_a_height, FONT_A_SCALE);
    my_init_fonts(*window_b_font, window_b_width, window_b_height, FONT_B_SCALE);
    
    quit := false;
    while !quit {
        Input.update_window_events();

        for Input.get_window_resizes() {
            Simp.update_window(it.window);
            if it.window == window_a {
                should_reinit := (it.width != window_a_width) || (it.height != window_a_height);

                if should_reinit {
                    window_a_width  = it.width;
                    window_a_height = it.height;
                    my_init_fonts(*window_a_font, window_a_width, window_a_height, FONT_A_SCALE);  // Resize the font for the new window size.
                }
            } else if it.window == window_b {
                should_reinit := (it.width != window_b_width) || (it.height != window_b_height);

                if should_reinit {
                    window_b_width  = it.width;
                    window_b_height = it.height;
                    my_init_fonts(*window_b_font, window_b_width, window_b_height, FONT_B_SCALE);  // Resize the font for the new window size.
                }
            }
        }

        for Input.events_this_frame {
            if it.type == .QUIT then quit = true;

            if it.type == {
              case .KEYBOARD;
                if it.key_pressed && it.key_code == .ESCAPE {
                    quit = true;
                }
            }
        }

        draw_one_frame();
        
        sleep_milliseconds(10);
        reset_temporary_storage();
    }
}

draw_window_a :: () {
    Simp.set_render_target(window_a);
    Simp.clear_render_target(.15, .08, .08, 1);
    Simp.set_shader_for_color();

    time := get_time();

    // This is our own code to set up a rotating square:
    {
        b := cast(float)window_a_height / 10;
        p: Vector2;
        p.x = cast(float)(window_a_width  / 2);
        p.y = cast(float)(window_a_height / 2);

        theta := cast(float) fmod(time, TAU);    

        ct := cos(theta);
        st := sin(theta);
        
        w := make_vector2(b*ct, b*st);
        h := make_vector2(b*st, -b*ct);

        p0 := p - w - h;
        p1 := p + w - h;
        p2 := p + w + h;
        p3 := p - w + h;

        a :: 1.0;
        c0 := Vector4.{1, 0, 0, a};
        c1 := Vector4.{0, 1, 0, a};
        c2 := Vector4.{0, 0, 1, a};
        c3 := Vector4.{1, 1, 1, a};
        
        Simp.immediate_quad(p0, p1, p2, p3, c0, c1, c2, c3);
    }

    // Draw some text.
    {
        color := get_timed_hue();

        // Now, to draw the text:
        text := "Simp!";
        
        // We could just call Simp.draw_text to draw text! But we want to know the width
        // so that we can center the text, and to find the width, we have to do all the
        // text layout. So it makes sense just to draw the prepared text after that,
        // so there's a special routine, "draw_prepared_text", that draws the thing
        // you just prepared and got the width of.

        text_width := Simp.prepare_text(window_a_font, text);
        
        text_x := (window_a_width - text_width) / 2;
        text_y := window_a_height/2 - window_a_font.character_height/4;

        Simp.draw_prepared_text(window_a_font, text_x, text_y, color);
    }
}

draw_window_b :: () {
    Simp.set_render_target(window_b);

    color := get_timed_hue();
    Simp.clear_render_target(color.x, color.y, color.z, color.w);

    text := "Hello, Sailor!";
        
    text_width := Simp.prepare_text(window_b_font, text);
        
    text_x := (window_b_width - text_width) / 2;
    text_y := window_b_height/2 - window_b_font.character_height/4;

    black := Vector4.{0,0,0,1};
    Simp.draw_prepared_text(window_b_font, text_x, text_y, black);
}

draw_one_frame :: () {
    draw_window_a();
    Simp.swap_buffers(window_a);

    draw_window_b();
    Simp.swap_buffers(window_b);
}

my_init_fonts :: (result: **Simp.Dynamic_Font, width: s32, height: s32, scale: float) {
    // So that we can load our font, set to path of running executable.
    if !working_directory_set {
        path := path_strip_filename(get_path_of_running_executable());
        set_working_directory(path);
        working_directory_set = true;
    }
    
    pixel_height := cast(s32) floor(height * scale + .5);

    // @Cleanup: Don't have path + name be separate.
    font := Simp.get_font_at_size(".", "OpenSans-BoldItalic.ttf", pixel_height);
    assert(font != null);
    <<result = font;
}

get_timed_hue :: () -> Vector4 {
    // Just get an RGB color that changes over time.
    
    time := get_time();

    theta := cast(float) fmod(time*3, TAU);    
    color: Vector4;
    color.x = cos(theta)*.5+.5;
    Clamp(*color.x, 0, 1);
    color.y = 1;
    color.z = sin(theta)*.5+.5;
    Clamp(*color.z, 0, 1);
    color.w = 1;

    return color;
}

working_directory_set := false;

Simp  :: #import "Simp";
Input :: #import "Input";

// @CompilerBug: This doesn't work.
// #import "Simple_Render_Framework"(.SOFTWARE);

#import "Window_Creation";

#import "Basic";
#import "Math";
#import "System";  // For get_path_of_running_executable. @Cleanup.
#import "String";  // For path_strip_filename. @Cleanup.


#run {
    #if OS == .WINDOWS {
        WR :: #import "Windows_Resources";
        WR.disable_runtime_console();
    }
}

