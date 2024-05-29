Framebuffer :: struct {
    gl_handle : GLuint;
}

Geometry_Pass :: struct {
    framebuffer : Framebuffer;

    // @Cleanup Clarify exactly what kind of depth
    depth : Texture;
    depth.format = .Depth;
    depth.filter = .NEAREST;
    depth.wrap = .CLAMP_TO_EDGE;

    // Convenient to put color attachement textures after depth texture

    // @Cleanup Clarify if world position?
    // nocommit Store the texture units here as well?
    position : Texture;
    position.format = .RGBA16F;
    position.filter = .NEAREST;
    position.wrap = .CLAMP_TO_EDGE;

    // @Cleanup Clarify if world normal?
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

    pass : *Geometry_Pass = *app.geometry_pass;

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

    attachments : [3]GLenum = .[GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2];
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
    // TODO Add RenderDoc tags

    pass : *Geometry_Pass = *app.geometry_pass;

    // Geometry Pass: (positions, normals, albedo, depth?)
    glBindFramebuffer(GL_FRAMEBUFFER, pass.framebuffer.gl_handle);
    assert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);


    glClearColor(0., 0., 0., 1.); // Must use a black clear color for the geometry pass!
    glClear(GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT);

    // // @Think Maybe we can have the metaprogram check that the app global variable is not modified in these functions
    // // FIXME: When rendering entities we clear the depth buffer which means the order of these functions is quite @Volatile!
    // glBindTexture(GL_TEXTURE_2D, app.render_info.gbuffer_albedo_texture);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, app.geometry_pass.position.gl_handle);
    debug_label_object(GL_TEXTURE, app.geometry_pass.position.gl_handle, "position");
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, app.geometry_pass.normal.gl_handle);
    debug_label_object(GL_TEXTURE, app.geometry_pass.normal.gl_handle, "normal");
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, app.geometry_pass.base_color.gl_handle);
    debug_label_object(GL_TEXTURE, app.geometry_pass.base_color.gl_handle, "base_color");

    glCullFace(GL_BACK);
    glDepthFunc(GL_LESS);
    glEnable(GL_DEPTH_TEST);
    glDisable(GL_BLEND);
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

    //glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);

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