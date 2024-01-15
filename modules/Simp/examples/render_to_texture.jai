my_window: Window_Type;
window_width  : s32 = 1920;
window_height : s32 = 1080;

// In a real program, you might adjust the resolution of your offscreen render targets,
// as your window changes, but here, for simplicitly, we don't.
render_texture_width  :: 960;
render_texture_height :: 540;

// Each frame, we render separate scenes to render_target_a and render_target_b.
// Then we draw those textures into the final window.
render_target_a: *Simp.Texture;
render_target_b: *Simp.Texture;

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
    Simp.clear_render_target(.15, .08, .08, 1);

    render_target_a = Simp.texture_create_render_target(render_texture_width, render_texture_height, .RGBA8);
    render_target_b = Simp.texture_create_render_target(render_texture_width, render_texture_height, .RGBA8);
    
    quit := false;
    while !quit {
        Input.update_window_events();

        for Input.get_window_resizes() {
            Simp.update_window(my_window);  // Simp will do nothing if it doesn't care about this window.
            
            if it.window == my_window {
                window_width  = it.width;
                window_height = it.height;
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

render_texture_1 :: () {
    Simp.set_render_target(render_target_a);
    Simp.clear_render_target(.15, .15, .15, 1);

    Simp.set_shader_for_color();

    time := get_time();
    
    // Ye ole rotating square:
    {
        rw := cast(float) render_texture_width;
        rh := cast(float) render_texture_height;
        
        b := cast(float)rh / 3;
        p: Vector2;
        p.x = cast(float)(rw  / 2);
        p.y = cast(float)(rh / 2);

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
}

render_texture_2 :: () {
    Simp.set_render_target(render_target_b);

    color := make_vector4(.5, .3, .3, 1);
    Simp.clear_render_target(color.x, color.y, color.z, color.w);

    Simp.set_shader_for_color();

    {
        rw := cast(float) render_texture_width;
        rh := cast(float) render_texture_height;

        // Draw a circle with varying alpha in the middle of the target.
        // So later, when we blend this target against other stuff, it will
        // have varying opacity.
        NUM_SEGMENTS :: 50;

        time := get_time();
        b0 := rh / 10.0;
        b1 := rh / 1.0;
        theta := cast(float) fmod(time, TAU);    
        factor := cos(theta);
        factor *= factor;
        b := lerp(b0, b1, factor);
        
        p: Vector3;
        p.x = rw / 2.0;
        p.y = rh / 2.0;
        
        c_in  := color;
        c_out := color;
        c_in .w = 0;
        c_out.w = 1;
        
        for i: 0..NUM_SEGMENTS {
            theta0 := (i     / cast(float) NUM_SEGMENTS) * TAU;
            theta1 := ((i+1) / cast(float) NUM_SEGMENTS) * TAU;

            ct0 := cos(theta0);
            st0 := sin(theta0);
            ct1 := cos(theta1);
            st1 := sin(theta1);

            r0 := make_vector3(b*ct0, b*st0, 0);
            r1 := make_vector3(b*ct1, b*st1, 0);

            p0 := p + r0;
            p1 := p + r1;

            Simp.immediate_triangle(p, p0, p1, c_in, c_out, c_out);
        }
    }
}

draw_one_frame :: () {
    render_texture_1();
    render_texture_2();

    Simp.set_render_target(my_window);
    Simp.clear_render_target(.15, .08, .08, 1);

    rt_aspect := render_texture_height / cast(float)render_texture_width;

    // Whatever size the window is, pick a size to draw the render targets that
    // is 2/3 the window width...

    rt_width  := (window_width * 2) / 3;
    rt_height := cast(s32)(rt_aspect * rt_width);

    margin_x := (window_width  - rt_width)  / 4.0;
    margin_y := (window_height - rt_height) / 4.0;

    offset := make_vector3(margin_x, margin_y, 0);

    time := get_time();
    theta := cast(float) fmod(time * .13, TAU); 
    offset.xy = rotate(offset.xy, theta);
    
    x0 := (window_width - rt_width)   * .5 - offset.x;
    y0 := (window_height - rt_height) * .5 - offset.y;
    
    {
        Simp.set_shader_for_images(render_target_a);
        c0 := Vector4.{1, 1, 1, 1};
        Simp.immediate_quad(x0, y0, x0 + rt_width, y0 + rt_height, c0);
    }

    x0 += 2*offset.x;
    y0 += 2*offset.y;
    
    {
        Simp.set_shader_for_images(render_target_b);
        c0 := Vector4.{1, 1, 1, 1};
        Simp.immediate_quad(x0, y0, x0 + rt_width, y0 + rt_height, c0);
    }
    
    Simp.swap_buffers(my_window);
}

my_font: *Simp.Dynamic_Font;

Simp  :: #import "Simp";
Input :: #import "Input";

// @CompilerBug: This doesn't work.
// #import "Simple_Render_Framework"(.SOFTWARE);

#import "Window_Creation";

#import "Basic";
#import "Math";
#import "System";  // For get_path_of_running_executable. @Cleanup.
#import "String";  // For path_strip_filename. @Cleanup.

/*
#run {
    #if OS == .WINDOWS {
        WR :: #import "Windows_Resources";
        WR.disable_runtime_console();
    }
}
*/
