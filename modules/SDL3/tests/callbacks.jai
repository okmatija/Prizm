#import "Basic";
#import,file "../module.jai";

window:   *SDL_Window;
renderer: *SDL_Renderer;

SDL_AppInit :: (appstate: **void, argc: s32, argv: **u8) -> SDL_AppResult
{
    SDL_SetAppMetadata("Example Renderer Clear", "1.0", "com.example.renderer-clear");

    if !SDL_Init(SDL_INIT_VIDEO)
    {
        SDL_Log("Couldn't initialize SDL: %s", SDL_GetError());
        return .SDL_APP_FAILURE;
    }

    if !SDL_CreateWindowAndRenderer("examples/renderer/clear", 640, 480, 0, *window, *renderer)
     {
        SDL_Log("Couldn't create window/renderer: %s", SDL_GetError());
        return .SDL_APP_FAILURE;
    }
    
    SDL_SetWindowResizable(window, true);

    return .SDL_APP_CONTINUE;  /* carry on with the program! */
}

/* This function runs when a new event (mouse input, keypresses, etc) occurs. */
SDL_AppEvent :: (appstate: *void, event: *SDL_Event) -> SDL_AppResult
{
    if event.type == 
    {
        case xx SDL_EventType.SDL_EVENT_QUIT;
            return .SDL_APP_SUCCESS;  /* end the program, reporting success to the OS. */
    }
    
    return .SDL_APP_CONTINUE;  /* carry on with the program! */
}

/* This function runs once per frame, and is the heart of the program. */
SDL_AppIterate :: (appstate: *void) -> SDL_AppResult
{
    now := SDL_GetTicks().(float64) / 1000.0;

    red   := (0.5 + 0.5 * SDL_sin(now)).(float);
    green := (0.5 + 0.5 * SDL_sin(now + SDL_PI_D * 2 / 3)).(float);
    blue  := (0.5 + 0.5 * SDL_sin(now + SDL_PI_D * 4 / 3)).(float);

    SDL_SetRenderDrawColorFloat(renderer, red, green, blue, SDL_ALPHA_OPAQUE_FLOAT);
    SDL_RenderClear(renderer);
    SDL_RenderPresent(renderer);

    return .SDL_APP_CONTINUE;  /* carry on with the program! */
}

/* This function runs once at shutdown. */
SDL_AppQuit :: (appstate: *void, result: SDL_AppResult)
{
    /* SDL will clean up the window/renderer for us. */
}

main :: ()
{
    SDL_EnterAppMainCallbacks(SDL_AppInit, SDL_AppIterate, SDL_AppEvent, SDL_AppQuit);
}
