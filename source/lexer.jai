// @Incomplete support floats in hex 0h7fbf_ffff
// @Incomplete return errors when we have 123542abdc ie number with letters in it
// @Incomplete support binary 0b10101001

// ISSUE_001 :: "The lexer does not support files containing 'inf'"; @KnownIssue
// ISSUE_002 :: "The lexer does not gracefully handle files containing 'nan'"; @KnownIssue

Token :: struct {

    // @Idea If this was an enum flags we could test for multiple token types using fewer characters and would help with printing error messages when we expect more than one token type
    Type :: enum u32 {
        UNINITIALIZED;
        // EXTENDED_ASCII codes occupy values between [1, 255]
        IDENTIFIER :: 256;
        COMMENT;
        SQSTRING;
        DQSTRING;
        INTEGER;
        FLOAT;
        EOF;
    }

    type: Type = .UNINITIALIZED;

    // Specified as:
    // - (optional) plus or minus sign
    // - prefix 0 and a non-empty sequence of octal digits OR
    // - prefix 0x or 0x and a non-empty sequence of hexadecimal digits OR
    // - non-empty sequence of decimal digits, underscores may be used to separate groups of digits
    integer_value: s64;

    // Specified as:
    // - (optional) plus or minus sign
    // - non-empty sequence of decimal digits optionally containing decimal-point character (defines significand)
    // - (optional) e or E followed with optional minus or plus sign and nonempty sequence of decimal digits (defines exponent to base 10)
    // Note:
    // - The decimal format is the same as https://en.cppreference.com/w/cpp/string/basic_string/stof but note that
    // - The hexadecimal prefix is used for integers only, unlike https://en.cppreference.com/w/cpp/string/basic_string/stof
    // - String values like +/-inf and nan are not encoded here, these must be deduced by the parser so that in a non-floating point context these could be identifiers
    float_value: float64;

    string_value: string;

    using location: Source_Code_Location; // location points into the file being lexed
    offset_into_buffer: s64;
}

to_string :: (tok: Token) -> string {
    if #complete tok.type == {
        case .UNINITIALIZED;
            return copy_temporary_string("(uninitialized)");
        case .IDENTIFIER;
            return copy_temporary_string(tok.string_value);
        case .COMMENT;
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
            return tprint("(%)", s);
    }
}

Lexer :: struct {
    data: string;

    // @Cleanup Use Souce_Code_Location to bundle line, char and filename
    line_number: s64 = 1;
    character_number: s64 = 1;
    offset_into_buffer: s64;
    filename: string;

    error_callback := default_error_callback;

    cpp_style_comments := false; // Slash-slash for line comments, or slash-asterisk/asterisk-slash for block comments
    obj_style_comments := false; // Hash character starts line comments
}

default_error_callback :: (loc: Source_Code_Location, fmt: string, args: .. Any) {
    message := tprint(fmt, ..args);
    log("%:%,%: %", loc.fully_pathed_filename, loc.line_number, loc.character_number, message);
}

get_tokens :: (filename: string, input: string, cpp_style_comments := false, obj_style_comments := false) -> [..] Token {
    tokens: [..] Token;
    defer assert(tokens[tokens.count-1].type == .EOF);

    lex: Lexer;
    lex.data = input;
    lex.filename = filename;
    lex.cpp_style_comments = cpp_style_comments;
    lex.obj_style_comments = obj_style_comments;

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

starts_number :: (data : string) -> bool {
    if data.count == 0 {
        return false;
    }

    if data.count >= 1 {
        if is_number(data[0]) {
            return true;
        }
    }

    if data.count >= 2 {
        if data[0] == #char "+" || data[0] == #char "-" || data[0] == #char "." {
            if is_number(data[1]) {
                return true;
            }
        }
    }

    if data.count >= 3 {
        if data[0] == #char "+" || data[0] == #char "-" {
            if data[1] == #char "." && is_number(data[2]) {
                return true;
            }
        }
    }

    return false;
}

starts_float :: (data: string) -> bool {
    s := data;

    while s.count {
        if s[0] == #char "+" || s[0] == #char "-" || s[0] == #char "_" || is_number(s[0]) {
            advance(*s);
        } else {
            return s[0] == #char "." || s[0] == #char "e" || s[0] == #char "E";
        }
    }

    return false;
}

// Returns the constant string starting the comment, or the empty string if no comment start was found
starts_comment :: (s : string, cpp_style_comments : bool, obj_style_comments : bool) -> string {

    if cpp_style_comments && s.count > 1 && s[0] == #char "/" {
        if s[1] == #char "/" {
            return "//";
        } else if s[1] == #char "*" {
            return "/*";
        }
    }

    if obj_style_comments && s.count > 0 {
        if s[0] == #char "#" {
            return "#";
        }
    }

    return "";
}

continues_comment :: (s : string, cpp_style_comments : bool, obj_style_comments : bool) -> (end_of_comment : bool #must, increment : int) {
    if s.count == 0 {
        // We were passed an empty string
        return true, 0;
    }

    if cpp_style_comments && s.count > 1 && s[0] == #char "*" && s[1] == #char "/" {
        // We ended a cpp style block comment
        return true, 2;
    }

    start : string = starts_comment(s, cpp_style_comments=cpp_style_comments, obj_style_comments=obj_style_comments);
    if start != "" {
        // We started a comment
        return false, start.count;
    }

    // We're inside a comment, consume a single character
    return false, 1;
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

#if false {
#run {
    TEST_STRING :: #string DONE
    #AAA
    #BBB
    // CCC

    /* EEE */
    /*
    FFF
    FFF
      */
    12_3456_7890
    1234abc # GGG
    1.e-4 ## HHH1 # HHH2
    1.E-3
DONE
    tokens := get_tokens(#file, TEST_STRING, obj_style_comments=true, cpp_style_comments=true);
    for tok : tokens {
        // FIXME This code is broken if the token type is not a string
        for c : 0..tok.string_value.count-1 {
            if tok.string_value.data[c] == #char "\r" {
                tok.string_value.data[c] = #char " ";
            }
        }
        print("token [%] = '%'\n", it_index, tok);
    }
    return;
}
}

get_token :: (lex: *Lexer) -> success: bool, tok: Token {

    while true {
        starting := lex.data.count;

        // handle whitespace
        while !at_end(lex) && is_whitespace(lex.data[0]) {
            c := lex.data[0];
            if c == #char "\n" {
                lex.line_number += 1;
                lex.character_number = 0;
            }

            eat_char(lex);
        }

        if at_end(lex) {
            return false, make_token(lex, .EOF);
        }

        // if we've made no progress on eliminating whitespace then move on!
        if lex.data.count == starting {
            break;
        }
    }

    if starts_identifier(lex.data[0]) {
        tok := make_token(lex, .IDENTIFIER);

        // @Cleanup Just use ident, don't need separate length variable?
        length: s64;
        ident : string = lex.data;
        while !at_end(lex) && continues_identifier(lex.data[0]) {
            length += 1;
            eat_char(lex, 1);
        }
        ident.count = length;

        tok.string_value = ident;
        return true, tok;
    }

    comment_start := starts_comment(lex.data, cpp_style_comments=lex.cpp_style_comments, obj_style_comments=lex.obj_style_comments);
    if comment_start != "" {

        tok : Token = make_token(lex, .COMMENT);

        tok.string_value.data = lex.data.data;
        while !at_end(lex) {
            end_of_comment, increment := continues_comment(lex.data, cpp_style_comments=lex.cpp_style_comments, obj_style_comments=lex.obj_style_comments);
            tok.string_value.count += increment;
            if increment == 1 && lex.data[0] == #char "\n" {
                lex.line_number += 1;
                lex.character_number += 1;
                if comment_start != "/*" {
                    end_of_comment = true;
                }
            }
            eat_char(lex, increment);
            if end_of_comment {
                break;
            }
        }

        return true, tok;
    }

    if lex.data[0] == #char "'" || lex.data[0] == #char "\"" {

        quote := lex.data[0];
        eat_char(lex, 1); // eat opening quote

        tok := make_token(lex, ifx quote == #char "'" then Token.Type.SQSTRING else .DQSTRING);

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


    if starts_number(lex.data) {

        if starts_float(lex.data) {

            // Note special values like nan/inf/-inf/+inf are handled in the parser and deduced from a sign and identifier token

            // decimal float
            tok := make_token(lex, .FLOAT);
            value, success, remainder := string_to_float64(lex.data);
            if !success {
                lex.error_callback(get_location(lex), "string_to_float64 failed.\n");
                return false, make_token(lex, .EOF);
            }
            eat_char(lex, lex.data.count - remainder.count);
            tok.float_value = value;
            return success, tok;

        } else {
            negate := lex.data[0] == #char "-";
            if lex.data[0] == #char "-" || lex.data[0] == #char "+" {
                eat_char(lex);
            }

            if begins_with(lex.data, "0x") || begins_with(lex.data, "0X") {

                // hexadecimal integer
                tok := make_token(lex, .INTEGER);
                value: u64;
                eat_char(lex, 2); // eat prefix

                success := true;
                while !at_end(lex) && continues_identifier(lex.data[0]) {
                    if lex.data[0] == #char "_" {
                        eat_char(lex);
                        continue;
                    }

                    if !is_hex_number(lex.data[0]) {
                        lex.error_callback(get_location(lex), "invalid character \"%\" in hex constant.\n", slice(lex.data, 0, 1));
                        return false, make_token(lex, .EOF);
                    }

                    value = value << 4;
                    if is_number(lex.data[0]) value |= (lex.data[0] - #char "0");
                    else value |= ((to_lower(lex.data[0]) - #char "a") + 0xA);
                    eat_char(lex);
                }

                tok.integer_value = cast(s64) value;
                if negate tok.integer_value *= -1;
                return success, tok;

            } else if begins_with(lex.data, "0") {

                // octal integer
                tok := make_token(lex, .INTEGER);
                value: u64;
                eat_char(lex); // eat 0

                success := true;
                while !at_end(lex) && is_number(lex.data[0]) {
                    if lex.data[0] > #char "7" {
                        lex.error_callback(get_location(lex), "invalid digit \"%\" in octal constant.\n", slice(lex.data, 0, 1));
                        return false, make_token(lex, .EOF);
                    }

                    value = value << 3;
                    value |= (lex.data[0] - #char "0");
                    eat_char(lex);
                }

                if negate tok.integer_value *= -1;
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
                if negate tok.integer_value *= -1;
                return success, tok;
            }
        }
    }


    // single character
    char := lex.data[0];
    tok := make_token(lex, cast(Token.Type) char);
    eat_char(lex, 1);
    return true, tok;
}
