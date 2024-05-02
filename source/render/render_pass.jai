Framebuffer :: struct {
    gl_handle : GLuint;
}

Geometry_Pass :: struct {
    framebuffer : Framebuffer;

    depth : Texture;
    depth.format = .Depth;
    depth.filter = .NEAREST;
    depth.wrap = .CLAMP_TO_EDGE;

    // Convenient to put color attachement textures after depth texture

    position : Texture;
    position.format = .RGBA16F;
    position.filter = .NEAREST;
    position.wrap = .CLAMP_TO_EDGE;

    normal : Texture;
    normal.format = .RGBA16F;
    normal.filter = .NEAREST;

    //uvs : Texture;

};

geometry_pass_init :: (pass : *Geometry_Pass) {
    //pass.name = "Geometry_Pass";

    glGenFramebuffers(1, *pass.framebuffer.gl_handle);
    glBindFramebuffer(GL_FRAMEBUFFER, pass.framebuffer.gl_handle);

    texture_init(*pass.depth, app.window_size.width, app.window_size.height);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, pass.depth.gl_handle, 0);

    texture_init(*pass.position, app.window_size.width, app.window_size.height);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, pass.position.gl_handle, 0);

    texture_init(*pass.normal, app.window_size.width, app.window_size.height);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_2D, pass.normal.gl_handle, 0);

    // Is this necessary?? Also, add color here, too!
    attachments : [2]GLenum = .[GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1];
    glDrawBuffers(2, attachments.data);

    assert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);

    status := glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if status != GL_FRAMEBUFFER_COMPLETE {
        //print_stack_trace();
        assert(false, "Framebuffer error.\n");
    }

    glBindFramebuffer(GL_FRAMEBUFFER, 0); // Restore the default framebuffer after initialization
}


Ssao_Pass :: struct {
    // Inputs (Read textures)
    position : *Texture;
    normal : *Texture;
    depth : *Texture;
    noise : Texture;

    // Outputs (Write textures)
    ssao : Texture;
};

Ssao_Blur_Pass :: struct {
    // Inputs (Read textures)
    ssao : *Texture;

    // Outputs (Write textures)
    ssao_blurred : Texture;
}