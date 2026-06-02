//
// This file was auto-generated using the following command:
//
// jai generate.jai
//



TRACY_CALLSTACK :: 0;

TracyPlotFormatEnum :: enum u32 {
    Number     :: 0;
    Memory     :: 1;
    Percentage :: 2;
    Watt       :: 3;

    TracyPlotFormatNumber     :: Number;
    TracyPlotFormatMemory     :: Memory;
    TracyPlotFormatPercentage :: Percentage;
    TracyPlotFormatWatt       :: Watt;
}

___tracy_set_thread_name :: (name: *u8) -> void #foreign libtracy;

___tracy_source_location_data :: struct {
    name:     *u8;
    function: *u8;
    file:     *u8;
    line:     u32;
    color:    u32;
}

___tracy_c_zone_context :: struct {
    id:     u32;
    active: s32;
}

___tracy_gpu_time_data :: struct {
    gpuTime:  s64;
    queryId:  u16;
    _context: u8;
}

___tracy_gpu_zone_begin_data :: struct {
    srcloc:   u64;
    queryId:  u16;
    _context: u8;
}

___tracy_gpu_zone_begin_callstack_data :: struct {
    srcloc:   u64;
    depth:    s32;
    queryId:  u16;
    _context: u8;
}

___tracy_gpu_zone_end_data :: struct {
    queryId:  u16;
    _context: u8;
}

___tracy_gpu_new_context_data :: struct {
    gpuTime:  s64;
    period:   float;
    _context: u8;
    flags:    u8;
    type:     u8;
}

___tracy_gpu_context_name_data :: struct {
    _context: u8;
    name:     *u8;
    len:      u16;
}

___tracy_gpu_calibration_data :: struct {
    gpuTime:  s64;
    cpuDelta: s64;
    _context: u8;
}

___tracy_gpu_time_sync_data :: struct {
    gpuTime:  s64;
    _context: u8;
}

__tracy_lockable_context_data :: struct {}

// Some containers don't support storing const types.
// This struct, as visible to user, is immutable, so treat it as if const was declared here.
TracyCZoneCtx :: ___tracy_c_zone_context;

TracyCLockCtx :: *__tracy_lockable_context_data;

___tracy_alloc_srcloc :: (line: u32, source: *u8, sourceSz: u64, function: *u8, functionSz: u64, color: u32) -> u64 #foreign libtracy;
___tracy_alloc_srcloc_name :: (line: u32, source: *u8, sourceSz: u64, function: *u8, functionSz: u64, name: *u8, nameSz: u64, color: u32) -> u64 #foreign libtracy;

___tracy_emit_zone_begin :: (srcloc: *___tracy_source_location_data, active: s32) -> TracyCZoneCtx #foreign libtracy;
___tracy_emit_zone_begin_callstack :: (srcloc: *___tracy_source_location_data, depth: s32, active: s32) -> TracyCZoneCtx #foreign libtracy;
___tracy_emit_zone_begin_alloc :: (srcloc: u64, active: s32) -> TracyCZoneCtx #foreign libtracy;
___tracy_emit_zone_begin_alloc_callstack :: (srcloc: u64, depth: s32, active: s32) -> TracyCZoneCtx #foreign libtracy;
___tracy_emit_zone_end :: (ctx: TracyCZoneCtx) -> void #foreign libtracy;
___tracy_emit_zone_text :: (ctx: TracyCZoneCtx, txt: *u8, size: u64) -> void #foreign libtracy;
___tracy_emit_zone_name :: (ctx: TracyCZoneCtx, txt: *u8, size: u64) -> void #foreign libtracy;
___tracy_emit_zone_color :: (ctx: TracyCZoneCtx, color: u32) -> void #foreign libtracy;
___tracy_emit_zone_value :: (ctx: TracyCZoneCtx, value: u64) -> void #foreign libtracy;

___tracy_emit_gpu_zone_begin :: (unknown0: ___tracy_gpu_zone_begin_data) -> void #foreign libtracy;
___tracy_emit_gpu_zone_begin_callstack :: (unknown0: ___tracy_gpu_zone_begin_callstack_data) -> void #foreign libtracy;
___tracy_emit_gpu_zone_begin_alloc :: (unknown0: ___tracy_gpu_zone_begin_data) -> void #foreign libtracy;
___tracy_emit_gpu_zone_begin_alloc_callstack :: (unknown0: ___tracy_gpu_zone_begin_callstack_data) -> void #foreign libtracy;
___tracy_emit_gpu_zone_end :: (data: ___tracy_gpu_zone_end_data) -> void #foreign libtracy;
___tracy_emit_gpu_time :: (unknown0: ___tracy_gpu_time_data) -> void #foreign libtracy;
___tracy_emit_gpu_new_context :: (unknown0: ___tracy_gpu_new_context_data) -> void #foreign libtracy;
___tracy_emit_gpu_context_name :: (unknown0: ___tracy_gpu_context_name_data) -> void #foreign libtracy;
___tracy_emit_gpu_calibration :: (unknown0: ___tracy_gpu_calibration_data) -> void #foreign libtracy;
___tracy_emit_gpu_time_sync :: (unknown0: ___tracy_gpu_time_sync_data) -> void #foreign libtracy;

___tracy_emit_gpu_zone_begin_serial :: (unknown0: ___tracy_gpu_zone_begin_data) -> void #foreign libtracy;
___tracy_emit_gpu_zone_begin_callstack_serial :: (unknown0: ___tracy_gpu_zone_begin_callstack_data) -> void #foreign libtracy;
___tracy_emit_gpu_zone_begin_alloc_serial :: (unknown0: ___tracy_gpu_zone_begin_data) -> void #foreign libtracy;
___tracy_emit_gpu_zone_begin_alloc_callstack_serial :: (unknown0: ___tracy_gpu_zone_begin_callstack_data) -> void #foreign libtracy;
___tracy_emit_gpu_zone_end_serial :: (data: ___tracy_gpu_zone_end_data) -> void #foreign libtracy;
___tracy_emit_gpu_time_serial :: (unknown0: ___tracy_gpu_time_data) -> void #foreign libtracy;
___tracy_emit_gpu_new_context_serial :: (unknown0: ___tracy_gpu_new_context_data) -> void #foreign libtracy;
___tracy_emit_gpu_context_name_serial :: (unknown0: ___tracy_gpu_context_name_data) -> void #foreign libtracy;
___tracy_emit_gpu_calibration_serial :: (unknown0: ___tracy_gpu_calibration_data) -> void #foreign libtracy;
___tracy_emit_gpu_time_sync_serial :: (unknown0: ___tracy_gpu_time_sync_data) -> void #foreign libtracy;

___tracy_connected :: () -> s32 #foreign libtracy;

___tracy_emit_memory_alloc :: (ptr: *void, size: u64, secure: s32) -> void #foreign libtracy;
___tracy_emit_memory_alloc_callstack :: (ptr: *void, size: u64, depth: s32, secure: s32) -> void #foreign libtracy;
___tracy_emit_memory_free :: (ptr: *void, secure: s32) -> void #foreign libtracy;
___tracy_emit_memory_free_callstack :: (ptr: *void, depth: s32, secure: s32) -> void #foreign libtracy;
___tracy_emit_memory_alloc_named :: (ptr: *void, size: u64, secure: s32, name: *u8) -> void #foreign libtracy;
___tracy_emit_memory_alloc_callstack_named :: (ptr: *void, size: u64, depth: s32, secure: s32, name: *u8) -> void #foreign libtracy;
___tracy_emit_memory_free_named :: (ptr: *void, secure: s32, name: *u8) -> void #foreign libtracy;
___tracy_emit_memory_free_callstack_named :: (ptr: *void, depth: s32, secure: s32, name: *u8) -> void #foreign libtracy;
___tracy_emit_memory_discard :: (name: *u8, secure: s32) -> void #foreign libtracy;
___tracy_emit_memory_discard_callstack :: (name: *u8, secure: s32, depth: s32) -> void #foreign libtracy;

___tracy_emit_message :: (txt: *u8, size: u64, callstack_depth: s32) -> void #foreign libtracy;
___tracy_emit_messageL :: (txt: *u8, callstack_depth: s32) -> void #foreign libtracy;
___tracy_emit_messageC :: (txt: *u8, size: u64, color: u32, callstack_depth: s32) -> void #foreign libtracy;
___tracy_emit_messageLC :: (txt: *u8, color: u32, callstack_depth: s32) -> void #foreign libtracy;

___tracy_emit_frame_mark :: (name: *u8) -> void #foreign libtracy;
___tracy_emit_frame_mark_start :: (name: *u8) -> void #foreign libtracy;
___tracy_emit_frame_mark_end :: (name: *u8) -> void #foreign libtracy;
___tracy_emit_frame_image :: (image: *void, w: u16, h: u16, offset: u8, flip: s32) -> void #foreign libtracy;

___tracy_emit_plot :: (name: *u8, val: float64) -> void #foreign libtracy;
___tracy_emit_plot_float :: (name: *u8, val: float) -> void #foreign libtracy;
___tracy_emit_plot_int :: (name: *u8, val: s64) -> void #foreign libtracy;
___tracy_emit_plot_config :: (name: *u8, type: s32, step: s32, fill: s32, color: u32) -> void #foreign libtracy;
___tracy_emit_message_appinfo :: (txt: *u8, size: u64) -> void #foreign libtracy;

___tracy_announce_lockable_ctx :: (srcloc: *___tracy_source_location_data) -> *__tracy_lockable_context_data #foreign libtracy;
___tracy_terminate_lockable_ctx :: (lockdata: *__tracy_lockable_context_data) -> void #foreign libtracy;
___tracy_before_lock_lockable_ctx :: (lockdata: *__tracy_lockable_context_data) -> s32 #foreign libtracy;
___tracy_after_lock_lockable_ctx :: (lockdata: *__tracy_lockable_context_data) -> void #foreign libtracy;
___tracy_after_unlock_lockable_ctx :: (lockdata: *__tracy_lockable_context_data) -> void #foreign libtracy;
___tracy_after_try_lock_lockable_ctx :: (lockdata: *__tracy_lockable_context_data, acquired: s32) -> void #foreign libtracy;
___tracy_mark_lockable_ctx :: (lockdata: *__tracy_lockable_context_data, srcloc: *___tracy_source_location_data) -> void #foreign libtracy;
___tracy_custom_name_lockable_ctx :: (lockdata: *__tracy_lockable_context_data, name: *u8, nameSz: u64) -> void #foreign libtracy;

#scope_file


#if OS == .WINDOWS {
    libtracy :: #library "windows/libtracy";
} else #if OS == .LINUX {
    libtracy :: #library "linux/libtracy";
} else #if OS == .MACOS {
    libtracy :: #library "macos/libtracy";
} else {
    #assert false;
}

