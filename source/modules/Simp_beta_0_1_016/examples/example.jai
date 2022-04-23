my_window: Window_Type;
window_width  : s32 = 1920;
window_height : s32 = 1080;

image_test: Simp.Texture;

screenshot_index := 0;

main :: () {
    #if OS == .WINDOWS {
        Windows.SetProcessDPIAware();

        // Windows is very bad at thread-switching by default unless you do this. Sad.
        Windows :: #import "Windows";
        Windows.timeBeginPeriod(1);
    }

    my_window = create_window(window_width, window_height, "A Window");

    // Actual render size in pixels can be different from the window dimensions we specified above (for example on high-resolution displays on macOS/iOS).
    window_width, window_height = Simp.get_render_dimensions(my_window);

    Simp.set_render_target(my_window);
    
    my_init_fonts();
    success := Simp.texture_load_from_file(*image_test, "image_test.jpg");
    assert(success);
    
    quit := false;
    want_screenshot := false;
    while !quit {
        Input.update_window_events();

        for Input.get_window_resizes() {
            Simp.update_window(it.window);  // Simp will do nothing if it doesn't care about this window.
            
            if it.window == my_window {
                should_reinit := (it.width != window_width) || (it.height != window_height);

                window_width  = it.width;
                window_height = it.height;

                if should_reinit my_init_fonts();  // Resize the font for the new window size.
            }
        }

        for Input.events_this_frame {
            if it.type == .QUIT then quit = true;

            if it.type == {
              case .KEYBOARD;
                if it.key_pressed && it.key_code == .ESCAPE {
                    quit = true;
                }

                if it.key_pressed && it.key_code == #char " " {  // Press spacebar to take a screenshot.
                    want_screenshot = true;
                }
            }
        }

        draw_one_frame();

        if want_screenshot {
            screenshot_index += 1;

            // The Simp API for screenshots makes allowance for screenshots to occur
            // asynchronously. You call pixel_read_begin to start taking the screenshot,
            // and pixel_read_end to finish it and return the resulting bitmap (if it's
            // not ready yet, pixel_read_end will block until it is). If you want to know
            // whether the screenshot is done, you can call pixel_read_is_done().
            // Not all graphics APIs give us a way to do this asynchronously (for example,
            // OpenGL does not seem to), so you aren't guaranteed that this will be smooth,
            // but the API at least *provides a way* for it to be smooth if the backend permits.

            // Because this is a simple example, we just call _end immediately after _begin
            // to show the minimal code required to take a screenshot. To be asynchronous,
            // you would issue the read on one frame, then check whether it's done on each
            // subsequent frame, or else launch a thread to do this.
            async_read := Simp.pixel_read_begin(null, .RGBA8);
            bitmap     := Simp.pixel_read_end(async_read);
            
            filename := tprint("screenshot%.png\0", screenshot_index);

            #import "stb_image_write";
            stbi_write_png(filename.data, bitmap.width, bitmap.height, 4, bitmap.data.data, xx (bitmap.width * Simp.get_image_bytes_per_texel(bitmap.format)));  // Hardcoded to 4 channels because we know we requested .BGRA8 above.

            want_screenshot = false;

            Simp.deinit(*bitmap);
        }
        
        sleep_milliseconds(10);
        reset_temporary_storage();
    }
}

draw_one_frame :: () {
    Simp.clear_render_target(.15, .08, .08, 1);
    
    Simp.set_shader_for_color();

    time := get_time();
    
    // This is our own code to set up a rotating square:
    {
        b := cast(float)window_height / 10;
        p: Vector2;
        p.x = cast(float)(window_width  / 2);
        p.y = cast(float)(window_height / 2);

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
        // Do a bunch of wacky math to figure out the text color.
        theta := cast(float) fmod(time*3, TAU);    
        color: Vector4;
        color.x = cos(theta)*.5+.5;
        Clamp(*color.x, 0, 1);
        color.y = 1;
        color.z = sin(theta)*.5+.5;
        Clamp(*color.z, 0, 1);
        color.w = 1;

        // Now, to draw the text:
        text := "Simp!";
        
        // We could just call Simp.draw_text to draw text! But we want to know the width
        // so that we can center the text, and to find the width, we have to do all the
        // text layout. So it makes sense just to draw the prepared text after that,
        // so there's a special routine, "draw_prepared_text", that draws the thing
        // you just prepared and got the width of.
        
        text_width := Simp.prepare_text(my_font, text);
        
        text_x := (window_width - text_width) / 2;
        text_y := window_height/2 - my_font.character_height/4;

        Simp.draw_prepared_text(my_font, text_x, text_y, color);
    }


    if image_test.width && image_test.height {
        // Draw the texture test, to make sure
        // it comes out right-side-up.

        Simp.set_shader_for_images(*image_test);
        Simp.immediate_begin();

        w := window_height/8.0;

        v2 :: make_vector2;
        Simp.immediate_quad(v2(0, 0), v2(w, 0), v2(w, w), v2(0, w));
        Simp.immediate_flush();
    }
    
    Simp.swap_buffers(my_window);
}

my_init_fonts :: () {
    // So that we can load our font, set to path of running executable.
    // @Incomplete: Pack a default font into Simp.

    if !working_directory_set {
        path := path_strip_filename(get_path_of_running_executable());
        set_working_directory(path);
        working_directory_set = true;
    }
    
    pixel_height := window_height / 24;

    // @Cleanup: Don't have path + name be separate.
    my_font = Simp.get_font_at_size(".", "OpenSans-BoldItalic.ttf", pixel_height);
    assert(my_font != null);
}

working_directory_set := false;

my_font: *Simp.Dynamic_Font;

Simp  :: #import "Simp";
Input :: #import "Input";

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
