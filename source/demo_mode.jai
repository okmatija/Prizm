// @Incomplete Demo mode: Rendering key and mouse state to the viewport to help with recording gifs etc. This will make it easier to demo prizm, there can be UI/options for:
// - Configuring where to put the text e.g., follow the cursor, text color etc
// - There should be a TTL option on the demo text and a stack that pushes older text down while it fades

Demo_Mode :: struct {
    enabled : bool;

    keys_down : [..]SDL_Keycode;
    scrolling_up : bool;
    scrolling_down : bool;

    SCROLLING_TIMER :: .3;
    scrolling_up_countdown := SCROLLING_TIMER;
    scrolling_down_countdown := SCROLLING_TIMER;
}

render_demo_mode :: () {
    using app.demo_mode;

    if !enabled {
        return;
    }

    ImGui.PushFont(app.font_set.huge);
    defer ImGui.PopFont();

    label_window_flags :: ImGui.WindowFlags.NoTitleBar|.NoResize|.NoMove|.NoScrollbar|.NoSavedSettings|.NoInputs;

    // @Hack :LabelWindowSize The factor of 2 multiplying the window_size is a bit too much, but this
    // should probably be SetNextWindowContentSize anyway but using that adds a frame delay causing
    // horrible flickering. We need to figure fix this factor of 2 in order to be able to frame the
    // labels with a box about the right size
    MARGIN :: 30.;
    H := 50.;
    W := 290.; // Chosen to make longest fit
    longest : string = tprint("---Shift Scroll---");

    ImGui.SetNextWindowSize(.{W, H});
    // ImGui.SetNextWindowPos(.{MARGIN, app.current_window_height - H - MARGIN});
    ImGui.SetNextWindowPos(.{(app.current_window_width - W) / 2., MARGIN});

    // @Incomplete When we size the window with the text better we could give the window a background/border
    ImGui.SetNextWindowBgAlpha(0.);
    // ImGui.SetNextWindowBgAlpha(.25);
    // ImGui.PushStyleColor(xx ImGui.Col.WindowBg, BLACK);
    // defer ImGui.PopStyleColor();
    old_window_border_size := ImGui.GetStyle().WindowBorderSize;
    ImGui.GetStyle().WindowBorderSize = 0;
    defer ImGui.GetStyle().WindowBorderSize = old_window_border_size;

    ImGui.Begin("##DemoMode", flags=label_window_flags);
    defer ImGui.End();

    builder : String_Builder;
    init_string_builder(*builder);
    defer reset(*builder);

    if io().KeyCtrl print_to_builder(*builder,  " Ctrl");
    if io().KeyShift print_to_builder(*builder, " Shift");
    if io().KeyAlt print_to_builder(*builder,   " Alt");

    if io_mouse_left_down() print_to_builder(*builder,   " LMB");
    if io_mouse_right_down() print_to_builder(*builder,  " RMB");
    if io_mouse_middle_down() print_to_builder(*builder, " MMB");

    if scrolling_up {
        print_to_builder(*builder, " Scroll");

        countdown(*scrolling_up_countdown);
        if scrolling_up_countdown <= 0 {
            scrolling_up = false;
            scrolling_up_countdown = Demo_Mode.SCROLLING_TIMER;
        }
    }
    if scrolling_down {
        print_to_builder(*builder, " Scroll");

        countdown(*scrolling_down_countdown);
        if scrolling_down_countdown <= 0 {
            scrolling_down = false;
            scrolling_down_countdown = Demo_Mode.SCROLLING_TIMER;
        }
    }

    for keys_down {
        str := to_string(it);
        if str { // Check for empty string here since we add a space prefix
            print_to_builder(*builder, tprint(" %", to_string(it)));
        }
    }

    input_string := builder_to_string(*builder);
    defer free(input_string);

    padding := (longest.count - input_string.count) / 2;
    cursor := 0;
    for 1..padding {
        longest[cursor] = #char " ";
        cursor += 1;
    }
    for 0..input_string.count-1 {
        longest[cursor] = input_string[it];
        cursor += 1;
    }
    while cursor < longest.count {
        longest[cursor] = #char " ";
        cursor += 1;
    }

    ImGui.Text(longest);
}

#scope_file

countdown :: (value_pointer: *float) {
    value := << value_pointer;
    value -= io().DeltaTime;
    if value < 0 value = 0;
    <<value_pointer = value;
}

// This is NOT a general function, it only works for demo mode
to_string :: (using code : SDL_Keycode) -> string {
    if code == {
    case; return "";
    case .SDLK_UNKNOWN; return "";

    case .SDLK_RETURN; return "Return";
    case .SDLK_ESCAPE; return "Escape";
    case .SDLK_BACKSPACE; return "Backspace";
    case .SDLK_TAB; return "Tab";
    case .SDLK_SPACE; return "Space";
    case .SDLK_EXCLAIM; return "!";
    case .SDLK_QUOTEDBL; return "\"";
    case .SDLK_HASH; return "#";
    case .SDLK_PERCENT; return "%";
    case .SDLK_DOLLAR; return "$";
    case .SDLK_AMPERSAND; return "&";
    case .SDLK_QUOTE; return "' (Quote)";
    case .SDLK_LEFTPAREN; return "(";
    case .SDLK_RIGHTPAREN; return ")";
    case .SDLK_ASTERISK; return "*";
    case .SDLK_PLUS; return "+";
    case .SDLK_COMMA; return ", (Comma)";
    case .SDLK_MINUS; return "- (Minus)";
    case .SDLK_PERIOD; return ". (Period)";
    case .SDLK_SLASH; return "/ (Slash)";
    case .SDLK_0; return "0";
    case .SDLK_1; return "1";
    case .SDLK_2; return "2";
    case .SDLK_3; return "3";
    case .SDLK_4; return "4";
    case .SDLK_5; return "5";
    case .SDLK_6; return "6";
    case .SDLK_7; return "7";
    case .SDLK_8; return "8";
    case .SDLK_9; return "9";
    case .SDLK_COLON; return ":";
    case .SDLK_SEMICOLON; return "; (Semicolon)";
    case .SDLK_LESS; return "<";
    case .SDLK_EQUALS; return "= (Equals)";
    case .SDLK_GREATER; return ">";
    case .SDLK_QUESTION; return "?";
    case .SDLK_AT; return "@";
    /*
       Skip uppercase letters
    */
    case .SDLK_LEFTBRACKET; return "[ (LBracket)";
    case .SDLK_BACKSLASH; return "\\ (Backslash)";
    case .SDLK_RIGHTBRACKET; return "] (RBracket)";
    case .SDLK_CARET; return "^";
    case .SDLK_UNDERSCORE; return "_";
    case .SDLK_BACKQUOTE; return "` (Backtick)";
    case .SDLK_a; return "A";
    case .SDLK_b; return "B";
    case .SDLK_c; return "C";
    case .SDLK_d; return "D";
    case .SDLK_e; return "E";
    case .SDLK_f; return "F";
    case .SDLK_g; return "G";
    case .SDLK_h; return "H";
    case .SDLK_i; return "I";
    case .SDLK_j; return "J";
    case .SDLK_k; return "K";
    case .SDLK_l; return "L";
    case .SDLK_m; return "M";
    case .SDLK_n; return "N";
    case .SDLK_o; return "O";
    case .SDLK_p; return "P";
    case .SDLK_q; return "Q";
    case .SDLK_r; return "R";
    case .SDLK_s; return "S";
    case .SDLK_t; return "T";
    case .SDLK_u; return "U";
    case .SDLK_v; return "V";
    case .SDLK_w; return "W";
    case .SDLK_x; return "X";
    case .SDLK_y; return "Y";
    case .SDLK_z; return "Z";

    //SDLK_SCANCODE_MASK :: 1 << 30;

    //
    // Note: All this #run SDL_SCANCODE_TO_KEYCODE is crazy in terms of
    // expense required to do simple things. Eventually we will probably be
    // able to substitute a macro here (when we have macros) but that will
    // still be perhaps a bit more expensive than I'd like.
    //

    case .SDLK_CAPSLOCK; return "CapsLock";

    case .SDLK_F1; return "F1";
    case .SDLK_F2; return "F2";
    case .SDLK_F3; return "F3";
    case .SDLK_F4; return "F4";
    case .SDLK_F5; return "F5";
    case .SDLK_F6; return "F6";
    case .SDLK_F7; return "F7";
    case .SDLK_F8; return "F8";
    case .SDLK_F9; return "F9";
    case .SDLK_F10; return "F10";
    case .SDLK_F11; return "F11";
    case .SDLK_F12; return "F12";

    // case .SDLK_PRINTSCREEN :: #run Hack.K(SDL_SCANCODE_PRINTSCREEN);
    // case .SDLK_SCROLLLOCK :: #run Hack.K(SDL_SCANCODE_SCROLLLOCK);
    // case .SDLK_PAUSE :: #run Hack.K(SDL_SCANCODE_PAUSE);
    case .SDLK_INSERT; return "Insert";
    case .SDLK_HOME; return "Home";
    case .SDLK_PAGEUP; return "PageUp";
    case .SDLK_DELETE; return "Delete";
    case .SDLK_END; return "End";
    case .SDLK_PAGEDOWN; return "PageDown";
    case .SDLK_RIGHT; return "Right";
    case .SDLK_LEFT; return "Left";
    case .SDLK_DOWN; return "Down";
    case .SDLK_UP; return "Up";

    // case .SDLK_NUMLOCKCLEAR :: #run Hack.K(SDL_SCANCODE_NUMLOCKCLEAR);
    // case .SDLK_KP_DIVIDE :: #run Hack.K(SDL_SCANCODE_KP_DIVIDE);
    // case .SDLK_KP_MULTIPLY :: #run Hack.K(SDL_SCANCODE_KP_MULTIPLY);
    case .SDLK_KP_MINUS; return "-";
    case .SDLK_KP_PLUS; return "+";
    case .SDLK_KP_ENTER; return "Return";
    case .SDLK_KP_1; return "1";
    case .SDLK_KP_2; return "2";
    case .SDLK_KP_3; return "3";
    case .SDLK_KP_4; return "4";
    case .SDLK_KP_5; return "5";
    case .SDLK_KP_6; return "6";
    case .SDLK_KP_7; return "7";
    case .SDLK_KP_8; return "8";
    case .SDLK_KP_9; return "9";
    case .SDLK_KP_0; return "0";
    case .SDLK_KP_PERIOD; return ".";
    case .SDLK_KP_EQUALS; return "=";
    case .SDLK_KP_COMMA; return ",";
    case .SDLK_KP_EQUALSAS400; return "=";
    case .SDLK_KP_LEFTPAREN; return "(";
    case .SDLK_KP_RIGHTPAREN; return ")";
    case .SDLK_KP_LEFTBRACE; return "{";
    case .SDLK_KP_RIGHTBRACE; return "}";
    case .SDLK_KP_TAB; return "Tab";
    case .SDLK_KP_BACKSPACE; return "Backspace";

    // case .SDLK_APPLICATION :: #run Hack.K(SDL_SCANCODE_APPLICATION);
    // case .SDLK_POWER :: #run Hack.K(SDL_SCANCODE_POWER);
    // case .SDLK_F13 :: #run Hack.K(SDL_SCANCODE_F13);
    // case .SDLK_F14 :: #run Hack.K(SDL_SCANCODE_F14);
    // case .SDLK_F15 :: #run Hack.K(SDL_SCANCODE_F15);
    // case .SDLK_F16 :: #run Hack.K(SDL_SCANCODE_F16);
    // case .SDLK_F17 :: #run Hack.K(SDL_SCANCODE_F17);
    // case .SDLK_F18 :: #run Hack.K(SDL_SCANCODE_F18);
    // case .SDLK_F19 :: #run Hack.K(SDL_SCANCODE_F19);
    // case .SDLK_F20 :: #run Hack.K(SDL_SCANCODE_F20);
    // case .SDLK_F21 :: #run Hack.K(SDL_SCANCODE_F21);
    // case .SDLK_F22 :: #run Hack.K(SDL_SCANCODE_F22);
    // case .SDLK_F23 :: #run Hack.K(SDL_SCANCODE_F23);
    // case .SDLK_F24 :: #run Hack.K(SDL_SCANCODE_F24);
    // case .SDLK_EXECUTE :: #run Hack.K(SDL_SCANCODE_EXECUTE);
    // case .SDLK_HELP :: #run Hack.K(SDL_SCANCODE_HELP);
    // case .SDLK_MENU :: #run Hack.K(SDL_SCANCODE_MENU);
    // case .SDLK_SELECT :: #run Hack.K(SDL_SCANCODE_SELECT);
    // case .SDLK_STOP :: #run Hack.K(SDL_SCANCODE_STOP);
    // case .SDLK_AGAIN :: #run Hack.K(SDL_SCANCODE_AGAIN);
    // case .SDLK_UNDO :: #run Hack.K(SDL_SCANCODE_UNDO);
    // case .SDLK_CUT :: #run Hack.K(SDL_SCANCODE_CUT);
    // case .SDLK_COPY :: #run Hack.K(SDL_SCANCODE_COPY);
    // case .SDLK_PASTE :: #run Hack.K(SDL_SCANCODE_PASTE);
    // case .SDLK_FIND :: #run Hack.K(SDL_SCANCODE_FIND);
    // case .SDLK_MUTE :: #run Hack.K(SDL_SCANCODE_MUTE);
    // case .SDLK_VOLUMEUP :: #run Hack.K(SDL_SCANCODE_VOLUMEUP);
    // case .SDLK_VOLUMEDOWN :: #run Hack.K(SDL_SCANCODE_VOLUMEDOWN);

    // case .SDLK_ALTERASE :: #run Hack.K(SDL_SCANCODE_ALTERASE);
    // case .SDLK_SYSREQ :: #run Hack.K(SDL_SCANCODE_SYSREQ);
    // case .SDLK_CANCEL :: #run Hack.K(SDL_SCANCODE_CANCEL);
    // case .SDLK_CLEAR :: #run Hack.K(SDL_SCANCODE_CLEAR);
    // case .SDLK_PRIOR :: #run Hack.K(SDL_SCANCODE_PRIOR);
    // case .SDLK_RETURN2 :: #run Hack.K(SDL_SCANCODE_RETURN2);
    // case .SDLK_SEPARATOR :: #run Hack.K(SDL_SCANCODE_SEPARATOR);
    // case .SDLK_OUT :: #run Hack.K(SDL_SCANCODE_OUT);
    // case .SDLK_OPER :: #run Hack.K(SDL_SCANCODE_OPER);
    // case .SDLK_CLEARAGAIN :: #run Hack.K(SDL_SCANCODE_CLEARAGAIN);
    // case .SDLK_CRSEL :: #run Hack.K(SDL_SCANCODE_CRSEL);
    // case .SDLK_EXSEL :: #run Hack.K(SDL_SCANCODE_EXSEL);

    // case .SDLK_KP_00 :: #run Hack.K(SDL_SCANCODE_KP_00);
    // case .SDLK_KP_000 :: #run Hack.K(SDL_SCANCODE_KP_000);
    // case .SDLK_THOUSANDSSEPARATOR :: #run Hack.K(SDL_SCANCODE_THOUSANDSSEPARATOR);
    // case .SDLK_DECIMALSEPARATOR :: #run Hack.K(SDL_SCANCODE_DECIMALSEPARATOR);
    // case .SDLK_CURRENCYUNIT :: #run Hack.K(SDL_SCANCODE_CURRENCYUNIT);
    // case .SDLK_CURRENCYSUBUNIT :: #run Hack.K(SDL_SCANCODE_CURRENCYSUBUNIT);
    // case .SDLK_KP_A :: #run Hack.K(SDL_SCANCODE_KP_A);
    // case .SDLK_KP_B :: #run Hack.K(SDL_SCANCODE_KP_B);
    // case .SDLK_KP_C :: #run Hack.K(SDL_SCANCODE_KP_C);
    // case .SDLK_KP_D :: #run Hack.K(SDL_SCANCODE_KP_D);
    // case .SDLK_KP_E :: #run Hack.K(SDL_SCANCODE_KP_E);
    // case .SDLK_KP_F :: #run Hack.K(SDL_SCANCODE_KP_F);
    // case .SDLK_KP_XOR :: #run Hack.K(SDL_SCANCODE_KP_XOR);
    // case .SDLK_KP_POWER :: #run Hack.K(SDL_SCANCODE_KP_POWER);
    // case .SDLK_KP_PERCENT :: #run Hack.K(SDL_SCANCODE_KP_PERCENT);
    // case .SDLK_KP_LESS :: #run Hack.K(SDL_SCANCODE_KP_LESS);
    // case .SDLK_KP_GREATER :: #run Hack.K(SDL_SCANCODE_KP_GREATER);
    // case .SDLK_KP_AMPERSAND :: #run Hack.K(SDL_SCANCODE_KP_AMPERSAND);
    // case .SDLK_KP_DBLAMPERSAND :: #run Hack.K(SDL_SCANCODE_KP_DBLAMPERSAND);
    // case .SDLK_KP_VERTICALBAR :: #run Hack.K(SDL_SCANCODE_KP_VERTICALBAR);
    // case .SDLK_KP_DBLVERTICALBAR :: #run Hack.K(SDL_SCANCODE_KP_DBLVERTICALBAR);
    // case .SDLK_KP_COLON :: #run Hack.K(SDL_SCANCODE_KP_COLON);
    // case .SDLK_KP_HASH :: #run Hack.K(SDL_SCANCODE_KP_HASH);
    // case .SDLK_KP_SPACE :: #run Hack.K(SDL_SCANCODE_KP_SPACE);
    // case .SDLK_KP_AT :: #run Hack.K(SDL_SCANCODE_KP_AT);
    // case .SDLK_KP_EXCLAM :: #run Hack.K(SDL_SCANCODE_KP_EXCLAM);
    // case .SDLK_KP_MEMSTORE :: #run Hack.K(SDL_SCANCODE_KP_MEMSTORE);
    // case .SDLK_KP_MEMRECALL :: #run Hack.K(SDL_SCANCODE_KP_MEMRECALL);
    // case .SDLK_KP_MEMCLEAR :: #run Hack.K(SDL_SCANCODE_KP_MEMCLEAR);
    // case .SDLK_KP_MEMADD :: #run Hack.K(SDL_SCANCODE_KP_MEMADD);
    // case .SDLK_KP_MEMSUBTRACT :: #run Hack.K(SDL_SCANCODE_KP_MEMSUBTRACT);
    // case .SDLK_KP_MEMMULTIPLY :: #run Hack.K(SDL_SCANCODE_KP_MEMMULTIPLY);
    // case .SDLK_KP_MEMDIVIDE :: #run Hack.K(SDL_SCANCODE_KP_MEMDIVIDE);
    // case .SDLK_KP_PLUSMINUS :: #run Hack.K(SDL_SCANCODE_KP_PLUSMINUS);
    // case .SDLK_KP_CLEAR :: #run Hack.K(SDL_SCANCODE_KP_CLEAR);
    // case .SDLK_KP_CLEARENTRY :: #run Hack.K(SDL_SCANCODE_KP_CLEARENTRY);
    // case .SDLK_KP_BINARY :: #run Hack.K(SDL_SCANCODE_KP_BINARY);
    // case .SDLK_KP_OCTAL :: #run Hack.K(SDL_SCANCODE_KP_OCTAL);
    // case .SDLK_KP_DECIMAL :: #run Hack.K(SDL_SCANCODE_KP_DECIMAL);
    // case .SDLK_KP_HEXADECIMAL :: #run Hack.K(SDL_SCANCODE_KP_HEXADECIMAL);

    // Note: We handle these elsewhere
    // case .SDLK_LCTRL; return "Ctrl";
    // case .SDLK_LSHIFT; return "Shift";
    // case .SDLK_LALT; return "Alt";
    // case .SDLK_LGUI :: #run Hack.K(SDL_SCANCODE_LGUI);
    // case .SDLK_RCTRL; return "Ctrl";
    // case .SDLK_RSHIFT; return "Shift";
    // case .SDLK_RALT; return "Alt";
    // case .SDLK_RGUI :: #run Hack.K(SDL_SCANCODE_RGUI);

    // case .SDLK_MODE :: #run Hack.K(SDL_SCANCODE_MODE);

    // case .SDLK_AUDIONEXT :: #run Hack.K(SDL_SCANCODE_AUDIONEXT);
    // case .SDLK_AUDIOPREV :: #run Hack.K(SDL_SCANCODE_AUDIOPREV);
    // case .SDLK_AUDIOSTOP :: #run Hack.K(SDL_SCANCODE_AUDIOSTOP);
    // case .SDLK_AUDIOPLAY :: #run Hack.K(SDL_SCANCODE_AUDIOPLAY);
    // case .SDLK_AUDIOMUTE :: #run Hack.K(SDL_SCANCODE_AUDIOMUTE);
    // case .SDLK_MEDIASELECT :: #run Hack.K(SDL_SCANCODE_MEDIASELECT);
    // case .SDLK_WWW :: #run Hack.K(SDL_SCANCODE_WWW);
    // case .SDLK_MAIL :: #run Hack.K(SDL_SCANCODE_MAIL);
    // case .SDLK_CALCULATOR :: #run Hack.K(SDL_SCANCODE_CALCULATOR);
    // case .SDLK_COMPUTER :: #run Hack.K(SDL_SCANCODE_COMPUTER);
    // case .SDLK_AC_SEARCH :: #run Hack.K(SDL_SCANCODE_AC_SEARCH);
    // case .SDLK_AC_HOME :: #run Hack.K(SDL_SCANCODE_AC_HOME);
    // case .SDLK_AC_BACK :: #run Hack.K(SDL_SCANCODE_AC_BACK);
    // case .SDLK_AC_FORWARD :: #run Hack.K(SDL_SCANCODE_AC_FORWARD);
    // case .SDLK_AC_STOP :: #run Hack.K(SDL_SCANCODE_AC_STOP);
    // case .SDLK_AC_REFRESH :: #run Hack.K(SDL_SCANCODE_AC_REFRESH);
    // case .SDLK_AC_BOOKMARKS :: #run Hack.K(SDL_SCANCODE_AC_BOOKMARKS);

    // case .SDLK_BRIGHTNESSDOWN :: #run Hack.K(SDL_SCANCODE_BRIGHTNESSDOWN);
    // case .SDLK_BRIGHTNESSUP :: #run Hack.K(SDL_SCANCODE_BRIGHTNESSUP);
    // case .SDLK_DISPLAYSWITCH :: #run Hack.K(SDL_SCANCODE_DISPLAYSWITCH);
    // case .SDLK_KBDILLUMTOGGLE :: #run Hack.K(SDL_SCANCODE_KBDILLUMTOGGLE);
    // case .SDLK_KBDILLUMDOWN :: #run Hack.K(SDL_SCANCODE_KBDILLUMDOWN);
    // case .SDLK_KBDILLUMUP :: #run Hack.K(SDL_SCANCODE_KBDILLUMUP);
    // case .SDLK_EJECT :: #run Hack.K(SDL_SCANCODE_EJECT);
    // case .SDLK_SLEEP :: #run Hack.K(SDL_SCANCODE_SLEEP);
    // case .SDLK_APP1 :: #run Hack.K(SDL_SCANCODE_APP1);
    // case .SDLK_APP2 :: #run Hack.K(SDL_SCANCODE_APP2);

    // case .SDLK_AUDIOREWIND :: #run Hack.K(SDL_SCANCODE_AUDIOREWIND);
    // case .SDLK_AUDIOFASTFORWARD :: #run Hack.K(SDL_SCANCODE_AUDIOFASTFORWARD);
    }
}