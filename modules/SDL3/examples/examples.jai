#import("Command_Line");
#import("jai-sdl3"); 

#load("common.jai");
#load("basic_triangle.jai");
#load("depth_sampler.jai");
#load("instanced_indexed.jai");
#load("compute_uniforms.jai");

Args :: struct {
    name := "";
    number := -1;
}

main :: () {	
    
    example_index := -1;
    goto_example_index := 0;
    quit := false;
    last_time := 0.0;

    array_add(*examples, basic_triangle_example);
    array_add(*examples, depth_sampler_example);
    array_add(*examples, instanced_indexed_example);
    array_add(*examples, compute_uniforms_example);
    
    defer array_free(examples);

    success, args, is_set, free_args := parse_arguments(Args);
    if is_set.name {
	for *examples {
	    log("% == %", it.name, args.name);
	    if it.name == args.name {
		goto_example_index = it_index;
		break;
	    }
	}
    }
    
    if !SDL_Init(.VIDEO) {
	log("Failed to initialize SDL: %", SDL_GetError());
	return;
    }

    SDL_AddEventWatch(application_lifecycle_watcher, null);


    log("Welcome to SDL_GPU examples in jai");
    log("Press [A]/[D] [RB]/[LB] to switch between examples");

    can_draw := true;

    while (!quit) {
	reset_context();

	event: SDL_Event;

	while SDL_PollEvent(*event) {
	    event_type := cast (SDL_EventType)event.type;
	    if event_type == {
		case .SDL_EVENT_QUIT;
		{
		    if example_index != -1 {
			examples[example_index].quit();
		    }

		    quit = true;
		}

		case .SDL_EVENT_USER;
		{
		    if event.user.code == 0 {
                        #if #exists(SDL_PLATFORM_GDK) {
			    if context.device {
				SDL_GDKSuspendGPU(context.device);
				can_draw = false;
				SDL_GDKSuspendCompete();
			    }
			}
		    } else if event.user.code == 1 {
			 #if #exists(SDL_PLATFORM_GDK) {
			     if context.device {
				 SDL_GDKResumeGPU(context.device);
			     }
			 }
		    }
		}

		case .SDL_EVENT_KEY_DOWN;
		{
		    if event.key.key == {
			case SDLK_D;
			{
			    goto_example_index = (example_index + 1) % examples.count;			    
			}

			case SDLK_A;
			{
			    goto_example_index = ifx example_index == 0 then examples.count - 1 else example_index - 1;
			}

			case SDLK_LEFT;
			{
			    context.left_pressed = true;
			}

			case SDLK_RIGHT;
			{
			    context.right_pressed = true;
			}

			case SDLK_DOWN;
			{
			    context.down_pressed = true;
			}

			case SDLK_UP;
			{
			    context.up_pressed = true;
			}
		    }
		}

		case .SDL_EVENT_MOUSE_BUTTON_DOWN;
		{
		    if event.button.button == SDL_BUTTON_LEFT {
			goto_example_index = ifx example_index == 0 then examples.count - 1 else example_index - 1;
		    } else if event.button.button == SDL_BUTTON_RIGHT {
			 goto_example_index = (example_index + 1) % examples.count;
		    }
		} 
	    }
	}

	if quit {
	    break;
	}
	
	if goto_example_index != -1 {
	    if example_index != -1 {
		examples[example_index].quit();
	    }
	
	    example_index = goto_example_index;
	    goto_example_index = -1;
	    context.example_name = examples[example_index].name;
	
	    log("Starting example %", context.example_name);
	
	    if examples[example_index].init() < 0 {
		log("init failed");
		return;
	    }
	}
	
	new_time := SDL_GetTicks() / 1000.0;
	context.delta_time = new_time - last_time;

	last_time = new_time;
	
	if examples[example_index].update() < 0 {
	    log("update failed");
	    return;
	}
	
	if can_draw {
	    if examples[example_index].draw() < 0 {
		log("draw failed");
		return;
	    }
	}
    }
}

#scope_file

examples: [..] SDLExample;

application_lifecycle_watcher :: (user_data: *void, event: *SDL_Event) -> bool #c_call {
    // This callback may be on a different thread, so let's
    // push these events as USER events so they appear
    // in the main thread's event loop.
    // That allows us to cancel drawing before/after we finish
    // drawing a frame, rather than mid-draw (which can crash!)
    if event.type == xx SDL_EventType.SDL_EVENT_DID_ENTER_BACKGROUND {
	evt: SDL_Event;
	evt.type = xx SDL_EventType.SDL_EVENT_USER;
	evt.user.code = 0;
	SDL_PushEvent(*evt);
    } else if event.type == xx SDL_EventType.SDL_EVENT_WILL_ENTER_FOREGROUND {
	evt: SDL_Event;
	evt.type = xx SDL_EventType.SDL_EVENT_USER;
	evt.user.code = 1;
	SDL_PushEvent(*evt);
    }

    return false;
}

reset_context :: () {
    context.left_pressed = false;
    context.right_pressed = false;
    context.down_pressed = false;
    context.up_pressed = false;
}
