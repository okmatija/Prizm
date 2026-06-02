//
// Helpful macros to interface with the C api
//
#if ENABLED {
	#load "bindings.jai";

    #import "Basic";
    #import "String";

	FrameMark :: (name: *u8 = null) #expand #no_debug {
		___tracy_emit_frame_mark(name);
	}

	FrameMarkStart :: (name: *u8 = null) #expand #no_debug {
		___tracy_emit_frame_mark_start(name);
	}

	FrameMarkEnd :: (name: *u8 = null) #expand #no_debug {
		___tracy_emit_frame_mark_end(name);
	}

	// Call this at the start of the scope you want to profile.
	ZoneScoped :: ($name := "", text := "", color: u32 = 0, value: u64 = 0) #expand #no_debug {
        location :: #location(#this);
		#if name {
			ZONE_NAME :: name;
		} else {
            PROC_NAME :: #procedure_name(#this);
            #if PROC_NAME {
                ZONE_NAME :: PROC_NAME;
            } else {
                ZONE_NAME :: #run sprint("%:<anonymous_procedure>", basename(location.fully_pathed_filename));
            }
		}

		tracy_loc := ___tracy_alloc_srcloc(xx location.line_number, location.fully_pathed_filename.data, xx location.fully_pathed_filename.count, ZONE_NAME.data, ZONE_NAME.count, 0);
		tracy_ctx := ___tracy_emit_zone_begin_alloc(tracy_loc, 1);

		if text  ___tracy_emit_zone_text(tracy_ctx, text.data, cast(u64) text.count);
		if color ___tracy_emit_zone_color(tracy_ctx, color);
		if value ___tracy_emit_zone_value(tracy_ctx, value);

		`defer ___tracy_emit_zone_end(tracy_ctx);
	}

    // Tracy requires these libs to work.
    #if OS == .WINDOWS {
        #library,system,link_always "ws2_32";
        #library,system,link_always "msvcprt";
        #library,system,link_always "advapi32";
        #library,system,link_always "user32";
    } else {
        #library,system,link_always "libpthread";
        #library,system,link_always "libdl";
        // libstdc++ is pulled in transitively via libtracy.so's NEEDED list; no explicit link needed
    }
} else {
	FrameMark :: (name: *u8 = null) #expand #no_debug {}
	FrameMarkStart :: (name: *u8 = null) #expand #no_debug {}
	FrameMarkEnd :: (name: *u8 = null) #expand #no_debug {}
	ZoneScoped :: ($name := "", text := "", color: u32 = 0, value: u64 = 0, location := #caller_location) #expand #no_debug {}
}
