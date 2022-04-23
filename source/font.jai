// TODO Just use Simp instead, seems to do what we want!

// TODO Consider using https://github.com/Chlumsky/msdfgen
// TODO Look at putting more glyphs into one texture e.g., see https://github.com/plamennf/text-rendering-demo/
// TODO What does raylib do for text?

FONT_SIZE :: 58;
ASCII_COUNT :: 128;

chars : Table(u32, Char); // @Speed We're generating a unique texture id per glyph.

Char :: struct {
    texture_id : GLuint;
    bearing    : Vector2;
    size       : Vector2;
    advance    : s32;
}

init_font :: () {
    // FreeType Init
    ft : *FT_Library;
    if (FT_Init_FreeType(*ft) != 0) {
        print("Could not init FreeType lib.\n");
        exit(1); // Hard-exit for now.
    }

#if false { // Load font at run-time
    exe_found, exe_path, exe_name := split_from_right(get_path_of_running_executable(), #char "/");
    if !exe_found {
        print("Error: Unable to find my own executable?!\n");
        exit(1); // Hard-exit for now.
    }

    face : FT_Face;
    if (FT_New_Face(ft, temp_c_string(join(exe_path, "/data/Inconsolata.otf")), 0, *face)) {
        print("Could not load data/Inconsolata.otf\n");
        exit(1); // Hard-exit for now.
    }
} else { // Load font at compile-time
    face : FT_Face;
    FONT, FONT_OK :: #run read_entire_file("data/Inconsolata.otf"); #assert(FONT_OK);
    if (FT_New_Memory_Face(ft, cast(*u8)FONT.data, FONT.count, 0, *face)) {
        print("Could not load data/Inconsolata.otf\n");
        exit(1); // Hard-exit for now.
    }
}

    FT_Set_Pixel_Sizes(face, 0, FONT_SIZE);

    using gl;
    
    // We're assuming OpenGL has been initialized.
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

    for 0..ASCII_COUNT-1 {
        if FT_Load_Char(face, xx it, FT_LOAD_RENDER) {
            print("Failed to load ascii char %\n", it);
            continue;
        }

        texture : GLuint;

        // Generate texture object for glyph.
        {
            glGenTextures(1, *texture);
            glBindTexture(GL_TEXTURE_2D, texture);
            glTexImage2D(GL_TEXTURE_2D, 
                         0, GL_RED, 
                         xx face.glyph.bitmap.width,
                         xx face.glyph.bitmap.rows,
                         0, GL_RED,
                         GL_UNSIGNED_BYTE,
                         face.glyph.bitmap.buffer);
        }

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

        char : Char;
     
        char.texture_id = texture;
        char.bearing = make_vector2(xx face.glyph.bitmap_left, xx face.glyph.bitmap_top);
        char.size = make_vector2(xx face.glyph.bitmap.width, xx face.glyph.bitmap.rows);
        char.advance = xx face.glyph.advance.x;

        table_add(*chars, xx it, char);
    }

    glBindTexture(GL_TEXTURE_2D, 0);

    FT_Done_Face(face);
    FT_Done_FreeType(ft);
}

get_text_width_in_pixels :: (text: string, scale: float) -> int {
    w : int;

    for i : 0..text.count-1 {
        ch, is_ascii := table_find(chars, text.data[i]);
        assert(is_ascii);
        w += (ch.advance >> 6) * xx scale;
    }

    return w;
}

render_text_quad :: (shader_program: GLuint, text: string, position: Vector2, scale: float, color: Vector4) {
    using app;

    if text.count == 0 {
        return;
    }


    Simp.draw_text(simp_font, xx position.x, xx position.y, text, color, scale=scale);

/*
    glUseProgram(shader_program);

    {
        loc := glGetUniformLocation(shader_program, "text_color");
        glUniform4f(loc, color.x, color.y, color.z, color.w);
    }

    {
        loc := glGetUniformLocation(app.text_program, "clip_from_view");
        clip_from_view := orthographic_projection_matrix(0.0, xx current_window_width, 0.0, xx current_window_height, -1.0, 1.0);
        glUniformMatrix4fv(loc, 1, true, *clip_from_view._11);
    }

    glActiveTexture(GL_TEXTURE0);
    glBindVertexArray(text_vao);

    pos := position;

    for i : 0..text.count-1 {
        ch, is_ascii := table_find(chars, text.data[i]);
        assert(is_ascii);

        x_pos : float = pos.x + ch.bearing.x * scale;
        y_pos : float = pos.y - (ch.size.y - ch.bearing.y) * scale;

        w : float = ch.size.x * scale;
        h : float = ch.size.y * scale;

        vertices : [24] float;

        {
            vertices[0] = x_pos;
            vertices[1] = y_pos + h;
            vertices[2] = 0.0;
            vertices[3] = 0.0;

            vertices[4] = x_pos;
            vertices[5] = y_pos;
            vertices[6] = 0.0;
            vertices[7] = 1.0;

            vertices[8]  = x_pos + w;
            vertices[9]  = y_pos;
            vertices[10] = 1.0;
            vertices[11] = 1.0;

            vertices[12] = x_pos;
            vertices[13] = y_pos + h;
            vertices[14] = 0.0;
            vertices[15] = 0.0;

            vertices[16] = x_pos + w;
            vertices[17] = y_pos;
            vertices[18] = 1.0;
            vertices[19] = 1.0;

            vertices[20] = x_pos + w;
            vertices[21] = y_pos + h;
            vertices[22] = 1.0;
            vertices[23] = 0.0;
        }

        //
        // Since we're wanting a different sized quad for each character (not terribly efficient!), let's update
        // the VBO memory.
        //
        glBindTexture(GL_TEXTURE_2D, ch.texture_id);
        glBindBuffer(GL_ARRAY_BUFFER, text_vbo);
        glBufferSubData(GL_ARRAY_BUFFER, 0, size_of(type_of(vertices)), *vertices);

        glBindBuffer(GL_ARRAY_BUFFER, 0);

        // Draw the glyph
        glDrawArrays(GL_TRIANGLES, 0, 6);

        // Advance to next glyph
        pos.x += (ch.advance >> 6) * scale;
    }

    glBindVertexArray(0);
    glBindTexture(GL_TEXTURE_2D, 0);
    */
}