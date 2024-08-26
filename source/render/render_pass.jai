Framebuffer :: struct {
    gl_handle : GLuint;
}

Lighting_Pass :: struct {
    framebuffer : Framebuffer;

    // Outputs (Write textures)
    lit : Texture;
    lit.format = .RGBA8;
}


init_lighting_pass :: () {
    pass : *Lighting_Pass = *app.render_info.lighting_pass;

    glGenFramebuffers(1, *pass.framebuffer.gl_handle);
    glBindFramebuffer(GL_FRAMEBUFFER, pass.framebuffer.gl_handle);

    texture_init(*pass.lit, app.window_size.width, app.window_size.height);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, pass.lit.gl_handle, 0);

    glBindFramebuffer(GL_FRAMEBUFFER, 0); // Restore the default framebuffer after initialization
}

use_lighting_pass :: () {

    DebugScopeGLGroup("Lighting Pass");

    pass : *Lighting_Pass = *app.render_info.lighting_pass;

    glBindFramebuffer(GL_FRAMEBUFFER, pass.framebuffer.gl_handle);
    //assert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);
    glClear(GL_COLOR_BUFFER_BIT);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, pass.lit.gl_handle);
    debug_label_object(GL_TEXTURE, pass.lit.gl_handle, "lit");
}



Geometry_Pass :: struct {
    framebuffer : Framebuffer;

    // @Cleanup Clarify exactly what kind of depth
    depth : Texture;
    depth.format = .Depth;
    depth.filter = .NEAREST;
    depth.wrap = .CLAMP_TO_EDGE;

    // Convenient to put color attachement textures after depth texture

    // @Cleanup Rename to position_world
    // @Cleanup Store the texture units here as well?
    position : Texture;
    position.format = .RGBA32F;
    position.filter = .NEAREST;
    position.wrap = .CLAMP_TO_EDGE;

    // @Cleanup Rename to normal_world
    normal : Texture;
    normal.format = .RGBA16F;
    normal.filter = .NEAREST;

    // @Think Opacity should be handled in a separately for depth peeling??
    base_color : Texture;
    base_color.format = .RGBA8;
    base_color.filter = .NEAREST;

    //uvs : Texture;

};

init_geometry_pass :: () {
    //pass.name = "Geometry_Pass";

    pass : *Geometry_Pass = *app.render_info.geometry_pass;

    glGenFramebuffers(1, *pass.framebuffer.gl_handle);
    glBindFramebuffer(GL_FRAMEBUFFER, pass.framebuffer.gl_handle);

    texture_init(*pass.depth, app.window_size.width, app.window_size.height);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, pass.depth.gl_handle, 0);

    texture_init(*pass.position, app.window_size.width, app.window_size.height);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, pass.position.gl_handle, 0);

    texture_init(*pass.normal, app.window_size.width, app.window_size.height);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_2D, pass.normal.gl_handle, 0);

    texture_init(*pass.base_color, app.window_size.width, app.window_size.height);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT2, GL_TEXTURE_2D, pass.base_color.gl_handle, 0);

    attachments : [3]GLenum = .[GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2]; // @Cleanup no GL_DEPTH_ATTACHMENT?
    glDrawBuffers(3, attachments.data);

    assert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);

    status := glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if status != GL_FRAMEBUFFER_COMPLETE {
        //print_stack_trace();
        assert(false, "Framebuffer error.\n");
    }

    glBindFramebuffer(GL_FRAMEBUFFER, 0); // Restore the default framebuffer after initialization

    // print_vars(pass.*);
    // print("pass.* is %\n", formatStruct(pass.*, use_long_form_if_more_than_this_many_members=0));
}

use_geometry_pass :: () {
    DebugScopeGLGroup("Geometry Pass");

    pass : *Geometry_Pass = *app.render_info.geometry_pass;

    // Geometry Pass: (positions, normals, albedo, depth?)
    glBindFramebuffer(GL_FRAMEBUFFER, pass.framebuffer.gl_handle);
    assert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, pass.position.gl_handle);
    debug_label_object(GL_TEXTURE, pass.position.gl_handle, "position");

    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, pass.normal.gl_handle);
    debug_label_object(GL_TEXTURE, pass.normal.gl_handle, "normal");

    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, pass.base_color.gl_handle);
    debug_label_object(GL_TEXTURE, pass.base_color.gl_handle, "base_color");

    glClearColor(0., 0., 0., 1.); // Must use a black clear color for the geometry pass!
    glClear(GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT);
    glCullFace(GL_BACK);
    glDepthFunc(GL_LESS);
    glEnable(GL_DEPTH_TEST);
    glDisable(GL_BLEND);
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

    //glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);

}




Ssao_Pass :: struct {
    framebuffer : Framebuffer;

    // Inputs (Read textures)
    position : *Texture;
    normal : *Texture;

    ssao_noise : Texture;
    ssao_noise.format = .RGB32F;
    ssao_noise.filter =.NEAREST;
    ssao_noise.wrap = .REPEAT; // We will use tile the whole screen with this noise texture

    ssao_kernel : [Shader_Ssao.SAMPLES_MAX]Vector3 = ---; // @TODO Make this a texture?

    // Outputs (Write textures)
    ssao_color : Texture;
    ssao_color.format = .R32F;
    ssao_color.filter =.NEAREST;
    ssao_color.wrap = .REPEAT;

};

init_ssao_pass :: () {
    pass : *Ssao_Pass = *app.render_info.ssao_pass;
    pass.position = *app.render_info.geometry_pass.position; // @TODO Replace with Depth instead?
    pass.normal = *app.render_info.geometry_pass.normal;

    glGenFramebuffers(1, *pass.framebuffer.gl_handle);
    glBindFramebuffer(GL_FRAMEBUFFER, pass.framebuffer.gl_handle);

    texture_init(*pass.ssao_color, app.window_size.width, app.window_size.height);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, pass.ssao_color.gl_handle, 0);

    glBindFramebuffer(GL_FRAMEBUFFER, 0); // Restore the default framebuffer after initialization

    // Generate SSAO sample kernel and noise texture
    {
        for * pass.ssao_kernel {
            it.x = random_get_zero_to_one() * 2. - 1.;
            it.y = random_get_zero_to_one() * 2. - 1.;
            it.z = random_get_zero_to_one() * 2. - 1.;
            normalize(it);
            it.* *= random_get_zero_to_one();

            // scale samples so they are more aligned to the center of the kernel
            scale : float = cast(float)it_index / pass.ssao_kernel.count;
            scale = lerp(.1, 1., scale * scale);
            it.* *= scale;
        }

        // Generate SSAO noise texture used to rotate the kernel around the z-axis i.e., in the surface tangent space
        ssao_noise_values : [16]Vector3 = ---;
        for * ssao_noise_values {
            it.x = random_get_zero_to_one() * 2. - 1.;
            it.y = random_get_zero_to_one() * 2. - 1.;
            it.z = 0.;
        }
        texture_init(*pass.ssao_noise, 4, 4, ssao_noise_values.data);
    }

    // print_vars(pass.*);
    // print("pass.* is %\n", formatStruct(pass.*, use_long_form_if_more_than_this_many_members=0));
}

use_ssao_pass :: () {
    DebugScopeGLGroup("SSAO Pass");

    pass : *Ssao_Pass = *app.render_info.ssao_pass;

    glBindFramebuffer(GL_FRAMEBUFFER, pass.framebuffer.gl_handle);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, pass.position.gl_handle);
    debug_label_object(GL_TEXTURE, pass.position.gl_handle, "tex_position");

    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, pass.normal.gl_handle);
    debug_label_object(GL_TEXTURE, pass.normal.gl_handle, "tex_normal");

    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, pass.ssao_noise.gl_handle);
    debug_label_object(GL_TEXTURE, pass.ssao_noise.gl_handle, "tex_noise");
}

Ssao_Blur_Pass :: struct {
    framebuffer : Framebuffer;

    // Inputs (Read textures)
    ssao : *Texture;

    // Outputs (Write textures)
    ssao_blurred : Texture;
    ssao_blurred.format = .R32F;
    ssao_blurred.filter =.NEAREST;
    ssao_blurred.wrap = .REPEAT;
}

init_ssao_blur_pass :: () {
    pass : *Ssao_Blur_Pass = *app.render_info.ssao_blur_pass;
    pass.ssao = *app.render_info.ssao_pass.ssao_color;

    glGenFramebuffers(1, *pass.framebuffer.gl_handle);
    glBindFramebuffer(GL_FRAMEBUFFER, pass.framebuffer.gl_handle);

    texture_init(*pass.ssao_blurred, app.window_size.width, app.window_size.height);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, pass.ssao_blurred.gl_handle, 0);

    glBindFramebuffer(GL_FRAMEBUFFER, 0); // Restore the default framebuffer after initialization
}

use_ssao_blur_pass :: () {

    DebugScopeGLGroup("SSAO Blur Pass");

    pass : *Ssao_Blur_Pass = *app.render_info.ssao_blur_pass;

    glBindFramebuffer(GL_FRAMEBUFFER, pass.framebuffer.gl_handle);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, pass.ssao.gl_handle);
    debug_label_object(GL_TEXTURE, pass.ssao.gl_handle, "occlusion_input");
}