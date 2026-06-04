//
// This file was auto-generated using the following command:
//
// jai generate.jai - -freetype
//



// Hinting greatly impacts visuals (and glyph sizes).
// - By default, hinting is enabled and the font's native hinter is preferred over the auto-hinter.
// - When disabled, FreeType generates blurrier glyphs, more or less matches the stb_truetype.h
// - The Default hinting mode usually looks good, but may distort glyphs in an unusual way.
// - The Light hinting mode generates fuzzier glyphs but better matches Microsoft's rasterizer.
// You can set those flags globally in ImFontAtlas::FontLoaderFlags
// You can set those flags on a per font basis in ImFontConfig::FontLoaderFlags
FreeTypeLoaderFlags :: enum_flags s32 {
    NoHinting                          :: 0x1;
    NoAutoHint                         :: 0x2;
    ForceAutoHint                      :: 0x4;
    LightHinting                       :: 0x8;
    MonoHinting                        :: 0x10;
    Bold                               :: 0x20;
    Oblique                            :: 0x40;
    Monochrome                         :: 0x80;
    LoadColor                          :: 0x100;
    Bitmap                             :: 0x200;

    FreeTypeBuilderFlags_NoHinting     :: 0x1;
    FreeTypeBuilderFlags_NoAutoHint    :: 0x2;
    FreeTypeBuilderFlags_ForceAutoHint :: 0x4;
    FreeTypeBuilderFlags_LightHinting  :: 0x8;
    FreeTypeBuilderFlags_MonoHinting   :: 0x10;
    FreeTypeBuilderFlags_Bold          :: 0x20;
    FreeTypeBuilderFlags_Oblique       :: 0x40;
    FreeTypeBuilderFlags_Monochrome    :: 0x80;
    FreeTypeBuilderFlags_LoadColor     :: 0x100;
    FreeTypeBuilderFlags_Bitmap        :: 0x200;

    ImGuiFreeTypeLoaderFlags_NoHinting      :: NoHinting;
    ImGuiFreeTypeLoaderFlags_NoAutoHint     :: NoAutoHint;
    ImGuiFreeTypeLoaderFlags_ForceAutoHint  :: ForceAutoHint;
    ImGuiFreeTypeLoaderFlags_LightHinting   :: LightHinting;
    ImGuiFreeTypeLoaderFlags_MonoHinting    :: MonoHinting;
    ImGuiFreeTypeLoaderFlags_Bold           :: Bold;
    ImGuiFreeTypeLoaderFlags_Oblique        :: Oblique;
    ImGuiFreeTypeLoaderFlags_Monochrome     :: Monochrome;
    ImGuiFreeTypeLoaderFlags_LoadColor      :: LoadColor;
    ImGuiFreeTypeLoaderFlags_Bitmap         :: Bitmap;

    ImGuiFreeTypeBuilderFlags_NoHinting     :: FreeTypeBuilderFlags_NoHinting;
    ImGuiFreeTypeBuilderFlags_NoAutoHint    :: FreeTypeBuilderFlags_NoAutoHint;
    ImGuiFreeTypeBuilderFlags_ForceAutoHint :: FreeTypeBuilderFlags_ForceAutoHint;
    ImGuiFreeTypeBuilderFlags_LightHinting  :: FreeTypeBuilderFlags_LightHinting;
    ImGuiFreeTypeBuilderFlags_MonoHinting   :: FreeTypeBuilderFlags_MonoHinting;
    ImGuiFreeTypeBuilderFlags_Bold          :: FreeTypeBuilderFlags_Bold;
    ImGuiFreeTypeBuilderFlags_Oblique       :: FreeTypeBuilderFlags_Oblique;
    ImGuiFreeTypeBuilderFlags_Monochrome    :: FreeTypeBuilderFlags_Monochrome;
    ImGuiFreeTypeBuilderFlags_LoadColor     :: FreeTypeBuilderFlags_LoadColor;
    ImGuiFreeTypeBuilderFlags_Bitmap        :: FreeTypeBuilderFlags_Bitmap;
}

FreeTypeBuilderFlags_ :: FreeTypeLoaderFlags;

FreeType :: struct {
    // This is automatically assigned when using '#define IMGUI_ENABLE_FREETYPE'.
    // If you need to dynamically select between multiple builders:
    // - you can manually assign this builder with 'atlas->SetFontLoader(ImGuiFreeType::GetFontLoader())'
    // - prefer deep-copying this into your own ImFontLoader instance if you use hot-reloading that messes up static data.
    GetFontLoader :: () -> *ImFontLoader #foreign imgui_freetype "?GetFontLoader@ImGuiFreeType@@YAPEBUImFontLoader@@XZ";

    // Override allocators. By default ImGuiFreeType will use IM_ALLOC()/IM_FREE()
    // However, as FreeType does lots of allocations we provide a way for the user to redirect it to a separate memory heap if desired.
    SetAllocatorFunctions :: (alloc_func: #type (sz: u64, user_data: *void) -> *void #c_call, free_func: #type (ptr: *void, user_data: *void) -> void #c_call, user_data: *void = null) -> void #foreign imgui_freetype "?SetAllocatorFunctions@ImGuiFreeType@@YAXP6APEAX_KPEAX@ZP6AX11@Z1@Z";

    // Display UI to edit ImFontAtlas::FontLoaderFlags (shared) or ImFontConfig::FontLoaderFlags (single source)
    DebugEditFontLoaderFlags :: (p_font_loader_flags: *FreeTypeLoaderFlags) -> bool #foreign imgui_freetype "?DebugEditFontLoaderFlags@ImGuiFreeType@@YA_NPEAI@Z";
}

#scope_file

imgui_freetype :: #library,no_dll "ImGui_freetype.static";
