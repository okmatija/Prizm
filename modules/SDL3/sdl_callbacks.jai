#scope_file

SDL_AppInit_jai_func    :: #type (**void, s32, **u8) -> SDL_AppResult;
SDL_AppEvent_jai_func   :: #type (*void, *SDL_Event) -> SDL_AppResult;
SDL_AppIterate_jai_func :: #type (*void) -> SDL_AppResult;
SDL_AppQuit_jai_func    :: #type (*void, SDL_AppResult) -> ();

_SDL_AppInit :: (appstate: **void, argc: s32, argv: **u8) -> SDL_AppResult #c_call
{
    push_context context_pointer
    {
        return jai_appinit(appstate, argc, argv);
    }
}

_SDL_AppEvent :: (appstate: *void, event: *SDL_Event) -> SDL_AppResult #c_call
{
    push_context context_pointer
    {
        return jai_appevent(appstate, event);
    }
}

_SDL_AppIterate :: (appstate: *void) -> SDL_AppResult #c_call
{
    push_context context_pointer
    {
        return jai_appiter(appstate);
    }
}

_SDL_AppQuit :: (appstate: *void, result: SDL_AppResult) #c_call
{
    push_context context_pointer
    {
        jai_appquit(appstate, result);
    }
}

context_pointer: *#Context;
jai_appinit:  SDL_AppInit_jai_func;
jai_appiter:  SDL_AppIterate_jai_func;
jai_appevent: SDL_AppEvent_jai_func;
jai_appquit:  SDL_AppQuit_jai_func;

#scope_export

SDL_EnterAppMainCallbacks :: (appinit: SDL_AppInit_jai_func, appiter: SDL_AppIterate_jai_func, appevent: SDL_AppEvent_jai_func, appquit: SDL_AppQuit_jai_func) -> s32 #expand
{
    context_pointer = *context;
    
    jai_appinit  = appinit;
    jai_appiter  = appiter;
    jai_appevent = appevent;
    jai_appquit  = appquit;
    
    return SDL_EnterAppMainCallbacks(0, null, _SDL_AppInit, _SDL_AppIterate, _SDL_AppEvent, _SDL_AppQuit);   
}