Parser :: struct {
    tokens: [..] Token; // owned @Cleanup, use a pool? or mark temporary storage
    current_token: s64;
    data: string; // borrowed

    // If we ever fail parsing, we set `failed` to true.
    //
    // For some kinds of programming, having to check a 'success' return status code,
    // after calling each function, gets tedious and annoying. Especially when parsing,
    // sometimes you don't care if you fail in the middle; you just want to blast through
    // some stuff and then check at the end whether everything succeeded.
    //
    // That's what `failed` is for. It starts false, and if anything ever fails, it gets
    // set to true. Parser will never set it back to false.
    //
    // See also `Text_File_Handler`
    failed  := false;
}

deinit :: (using p : Parser) {
    defer array_reset(*tokens);
}

error :: (p: *Parser, format: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) {
    log(format, ..args, flags=Log_Flags.ERROR|.CONTENT|flags, loc=loc);
    p.failed = true;
} @PrintLike

error :: (p: *Parser, token : Token, format: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) {
    using token.location;
    new_format := tprint("Parse error at '%:%:%'. %", fully_pathed_filename, line_number, character_number, format);
    log(new_format, ..args, flags=Log_Flags.ERROR|.CONTENT|flags, loc=loc);
    p.failed = true;
} @PrintLike

warning :: (p: *Parser, token : Token, format: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) {
    using token.location;
    new_format := tprint("Parse warning at '%:%:%'. %", fully_pathed_filename, line_number, character_number, format);
    log(new_format, ..args, flags=Log_Flags.WARNING|.CONTENT|flags, loc=loc);
} @PrintLike

eat_token :: next_token;
next_token :: (using p: *Parser) -> Token {
    tok := peek_token(p);
    current_token += 1;
    return tok;
}

// @Cleanup this should not take a pointer!
peek_token :: (using p: Parser) -> Token {
    if current_token >= tokens.count return tokens[tokens.count-1];
    return tokens[current_token];
}

peek_ahead :: (using p: *Parser, steps : s64 = 0) -> Token, clamped : bool {
    clamped := current_token + steps >= tokens.count;

    token : Token = ---;
    if clamped token = tokens[tokens.count  - 1];
    else       token = tokens[current_token + steps];

    return token, clamped;
}

eat_possible_token :: (p: *Parser, type: Token.Type) -> did_eat: bool {
    tok := peek_token(p);
    if tok.type == type {
        eat_token(p);
        return true;
    }

    return false;
}

eat_possible_identifier :: (p: *Parser, name: string) -> did_eat: bool {
    tok := peek_token(p);

    if tok.type == Token.Type.IDENTIFIER {
        if name == tok.string_value {
            eat_token(p);
            return true;
        }
    }

    return false;
}

expect :: (p: *Parser, type: Token.Type, source_loc := #caller_location) {
    tok := peek_token(p);

    if tok.type != type {
        error(p, "Parse error at %:%:%. Expected token type % but got type % (%).\n",
              tok.location.fully_pathed_filename,
              tok.location.line_number,
              tok.location.character_number,
              type,
              tok.type,
              to_string(tok));
    }
}

expect_and_eat :: (p: *Parser, type: Token.Type, loc := #caller_location) {
    expect(p, type, loc);
    eat_token(p);
}

parse_float :: (p: *Parser) -> float {
    tok : Token = peek_token(p);

    value: float;
    if tok.type == .INTEGER {

        value = cast(float) tok.integer_value;
        expect_and_eat(p, .INTEGER);

    } else if tok.type == .FLOAT {

        tok = eat_token(p);
        value = cast(float) tok.float_value;

    } else if tok.type == .IDENTIFIER {

        tok = eat_token(p);
        if equal_nocase(tok.string_value, "inf") {
            value = cast(float)FLOAT64_INFINITY;
        } else if equal_nocase(tok.string_value, "nan") {
            value = cast(float)FLOAT64_NAN;
        } else {
            error(p, "Parse error at %:%:%. Could not parse float from token %.\n",
                  tok.location.fully_pathed_filename,
                  tok.location.line_number,
                  tok.location.character_number,
                  to_string(tok));
        }

    } else if tok.type == xx #char "+" {

        tok = eat_token(p); // Eat the sign
        tok = eat_token(p); // Each the identifier
        if tok.type == .IDENTIFIER && equal_nocase(tok.string_value, "inf") {
            value = cast(float)FLOAT64_INFINITY;
        } else {
            error(p, "Parse error at %:%:%. Could not parse float from token %.\n",
                  tok.location.fully_pathed_filename,
                  tok.location.line_number,
                  tok.location.character_number,
                  to_string(tok));
        }

    } else if tok.type == xx #char "-" {

        tok = eat_token(p); // Eat the sign
        tok = eat_token(p); // Each the identifier
        if tok.type == .IDENTIFIER && equal_nocase(tok.string_value, "inf") {
            value = -cast(float)FLOAT64_INFINITY;
        } else {
            error(p, "Parse error at %:%:%. Could not parse float from token %.\n",
                  tok.location.fully_pathed_filename,
                  tok.location.line_number,
                  tok.location.character_number,
                  to_string(tok));
        }

   } else {

        error(p, "Parse error at %:%:%. Could not parse float from token %.\n",
              tok.location.fully_pathed_filename,
              tok.location.line_number,
              tok.location.character_number,
              to_string(tok));

   }

   return xx value;
}

parse_integer :: (p: *Parser) -> s64 {
    expect(p, Token.Type.INTEGER);
    tok := next_token(p);
    return tok.integer_value;
}

// @Incomplete Report when the fallback was used so we can tell the user about nans/infs

parse_vector3 :: (p: *Parser) -> Vector3 {
    using result : Vector3 = ---;
    x = parse_float(p);
    y = parse_float(p);
    z = parse_float(p);
    return result;
}

parse_vector2 :: (p: *Parser) -> Vector2 {
    using result : Vector2 = ---;
    x = parse_float(p);
    y = parse_float(p);
    return result;
}