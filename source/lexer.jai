// Copyright Epic Games, Inc. All Rights Reserved.

Token :: struct {

    // @Idea If this was an enum flags we could test for multiple token types using fewer characters and would help with printing error messages when we expect more than one token type
    Type :: enum u32 {
        UNINITIALIZED;
        IDENTIFIER :: 256;
        SQSTRING;
        DQSTRING;

         // These represent positive numbers only!
         // Negative numbers must be parsed by finding a preceeding #char "-" token
        INTEGER;
        FLOAT;

        EOF;
    }

    type: Type;

    integer_value: s64;
    float_value: float64;
    string_value: string;

    using location: Source_Code_Location; // location points into the file being lexed
    offset_into_buffer: s64;
}

to_string :: (tok: Token) -> string {
    if #complete tok.type == {
        case .UNINITIALIZED;
            return copy_temporary_string("(uninitialized token)");
        case .IDENTIFIER;
            return copy_temporary_string(tok.string_value);
        case .INTEGER;
            return tprint("%", tok.integer_value);
        case .FLOAT;
            return tprint("%", tok.float_value);
        case .SQSTRING;
            return tprint("'%'", tok.string_value);
        case .DQSTRING;
            return tprint("\"%\"", tok.string_value);
        case .EOF;
            return copy_temporary_string("(end-of-file)");
        case;
            // @Hack
            c: u8 = xx tok.type;
            s: string;
            s.data = *c;
            s.count = 1;
            return tprint("#char \"%\"", s);
    }
}

Lexer :: struct {
    data: string;

    line_number: s64 = 1;
    character_number: s64 = 1;
    offset_into_buffer: s64;
    filename: string;

    error_callback := default_error_callback;

    cpp_style_comments := false;
    hash_character_starts_comment := false;
}

default_error_callback :: (loc: Source_Code_Location, fmt: string, args: .. Any) {
    message := tprint(fmt, ..args);
    log("%:%,%: %", loc.fully_pathed_filename, loc.line_number, loc.character_number, message);
}

get_tokens :: (filename: string, input: string, cpp_style_comments := false, hash_character_starts_comment := false) -> [] Token {
    tokens: [..] Token;

    lex: Lexer;
    lex.data = input;
    lex.filename = filename;
    lex.cpp_style_comments = cpp_style_comments;
    lex.hash_character_starts_comment = hash_character_starts_comment;

    success := true;
    while success {
        tok: Token;
        success, tok = get_token(*lex);
        array_add(*tokens, tok);
    }

    return tokens;
}

make_token :: (lex: *Lexer, type: Token.Type) -> Token {
    t: Token;
    t.type = type;
    t.location = get_location(lex);
    t.offset_into_buffer = lex.offset_into_buffer;
    return t;
}

decimal_string_contains_dot_or_e :: (data: string) -> bool {
    str := data;

    while str.count && (is_number(str[0]) || str[0] == #char "_" || str[0] == #char "." || str[0] == #char "e") {
        if str[0] == #char "." || str[0] == #char "e" return true;
        advance(*str);
    }

    return false;
}

is_whitespace :: (c: u32) -> bool {
    // We got rid of the \v escape code so I took it out of here. It is unlikely you would
    // have this in your map data!   -jblow, 3 June 2018.
    return c == #char " " || c == #char "\t" || /*c == #char "\v" ||*/ c == #char "\r" || c == #char "\n";
}

starts_identifier :: (c: u32) -> bool {
    return c == #char "_" || (c >= #char "a" && c <= #char "z") || (c >= #char "A" && c <= #char "Z");
}

is_number :: (c: u32) -> bool {
    return (c >= #char "0" && c <= #char "9");
}

is_hex_number :: (c: u32) -> bool {
    return (c >= #char "a" && c <= #char "f") || (c >= #char "A" && c <= #char "F") || is_number(c);
}

continues_identifier :: (c: u32) -> bool {
    // :HandleFilenames @Cleanup @Hack Identifiers should probably not contain dots! We do this for now to make filenames work
    return starts_identifier(c) || is_number(c) || c == #char ".";
}

at_end :: (lex: *Lexer) -> bool {
    return lex.data.count <= 0;
}

eat_char :: (lex: *Lexer, count := 1) {
    advance(*lex.data, count);
    lex.character_number += count;
    lex.offset_into_buffer += count;
}

get_location :: (lex: *Lexer) -> Source_Code_Location {
    s: Source_Code_Location;
    s.fully_pathed_filename = lex.filename;
    s.line_number = lex.line_number;
    s.character_number = lex.character_number;
    return s;
}

// TEST_STRING :: #string DONE
// 12_3456_7890
// DONE

// #run {
//     context.logger = logger;
//     tokens := get_tokens(#file, TEST_STRING);
//     return;
// };

get_token :: (lex: *Lexer) -> success: bool, tok: Token {

    while true {
        starting := lex.data.count;
        while !at_end(lex) && is_whitespace(lex.data[0]) {
            c := lex.data[0];
            if c == #char "\n" {
                lex.line_number += 1;
                lex.character_number = 0;
            }

            eat_char(lex);
        }

        if at_end(lex) return false, make_token(lex, .EOF);

        // handle comments
        if lex.cpp_style_comments && lex.data[0] == #char "/" && lex.data.count > 1 {
            if lex.data[1] == #char "/" {
                eat_char(lex, 2);

                while !at_end(lex) && lex.data[0] != #char "\n" {
                    eat_char(lex);
                }
            } else if lex.data[1] == #char "*" {
                eat_char(lex, 2);

                while !at_end(lex) {
                    if lex.data[0] == #char "\n"{
                        lex.line_number += 1;
                        lex.character_number = 0;
                    } else if lex.data[0] == #char "*" && lex.data.count > 1 {
                        if lex.data[1] == #char "/" {
                            eat_char(lex, 2);
                            break;
                        }
                    }

                    eat_char(lex);
                }
            }
        } else if lex.hash_character_starts_comment {
            if lex.data[0] == #char "#" {
                eat_char(lex);


                while !at_end(lex) && lex.data[0] != #char "\n" {
                    eat_char(lex);
                }
            }
        }

        // if we've made no progress on eliminating whitespace or comments then move on!
        if lex.data.count == starting
            break;
    }

    if starts_identifier(lex.data[0]) {
        tok := make_token(lex, .IDENTIFIER);
        length: s64;
        ident := lex.data;
        while !at_end(lex) && continues_identifier(lex.data[0]) {
            length += 1;
            eat_char(lex, 1);
        }
        ident.count = length;

        tok.string_value = ident;
        return true, tok;
    }

    if lex.data[0] == #char "'" || lex.data[0] == #char "\"" {

        quote := lex.data[0];
        eat_char(lex, 1); // eat opening quote

        tok := make_token(lex, ifx quote == #char "'" then Token.Type.SQSTRING else .DQSTRING);

        success := false;
        tok.string_value.data = lex.data.data;
        while !at_end(lex) && lex.data[0] != quote {
            tok.string_value.count += 1;
            eat_char(lex, 1);
        }

        if at_end(lex) {
            lex.error_callback(get_location(lex), "missing terminating % in string constant.\n", slice(lex.data, 0, 1));
            return false, make_token(lex, .EOF);
        }

        eat_char(lex, 1); // eat closing quote
        return true, tok;
    }

    // :HandleFilenames Probably also need to check that there is a number following the dot, otherwise the dot should be it's own token, and probably combined with a preceeding identifier token to make a filename
    if is_number(lex.data[0]) || lex.data[0] == #char "." {

        if decimal_string_contains_dot_or_e(lex.data) {

            // decimal float
            tok := make_token(lex, .FLOAT);
            value, success, remainder := string_to_float(lex.data);
            if !success {
                lex.error_callback(get_location(lex), "string_to_float failed.\n");
            }
            eat_char(lex, lex.data.count - remainder.count);
            tok.float_value = value;
            return success, tok;

        } else if lex.data.count > 2 &&
                  lex.data[0] == #char "0" &&
                 (lex.data[1] == #char "x" || lex.data[1] == #char "X") {

            // hexadecimal integer
            tok := make_token(lex, .INTEGER);
            value: u64;
            eat_char(lex); // eat 0
            eat_char(lex); // eat x

            success := true;
            while !at_end(lex) && continues_identifier(lex.data[0]) {
                if lex.data[0] == #char "_" {
                    eat_char(lex);
                    continue;
                }

                if !is_hex_number(lex.data[0]) {
                    lex.error_callback(get_location(lex), "invalid character \"%\" in hex constant.\n", slice(lex.data, 0, 1));
                    success = false;
                    break;
                }

                value = value << 4;
                if is_number(lex.data[0]) value |= (lex.data[0] - #char "0");
                else value |= ((to_lower(lex.data[0]) - #char "a") + 0xA);
                eat_char(lex);
            }

            tok.integer_value = cast(s64) value;
            return success, tok;

        } else if lex.data.count > 1 && lex.data[0] == #char "0" {

            // octal integer
            tok := make_token(lex, .INTEGER);
            value: u64;
            eat_char(lex); // eat 0

            success := true;
            while !at_end(lex) && is_number(lex.data[0]) {
                if lex.data[0] > #char "7" {
                    lex.error_callback(get_location(lex), "invalid digit \"%\" in octal constant.\n", slice(lex.data, 0, 1));
                    success = false;
                    break;
                }

                value = value << 3;
                value |= (lex.data[0] - #char "0");
                eat_char(lex);
            }

            tok.integer_value = cast(s64) value;
            return success, tok;

        } else {

            // decimal integer
            tok := make_token(lex, .INTEGER);
            value: u64;

            success := true;
            while !at_end(lex) && (is_number(lex.data[0]) || lex.data[0] == #char "_" ) {
                if lex.data[0] == #char "_" {
                    eat_char(lex);
                    continue;
                }

                value = value * 10;
                value += (lex.data[0] - #char "0");
                eat_char(lex);
            }

            tok.integer_value = cast(s64) value;
            return success, tok;
        }
    }


    // single character
    char := lex.data[0];
    tok := make_token(lex, cast(Token.Type) char);
    eat_char(lex, 1);
    return true, tok;
}
