package main

import "core:fmt"
import "core:io"
import "core:os"
import "core:strings"
import "core:unicode"
import "core:unicode/utf8"

Token_Type :: enum u32 {
    STRING,
    LPAREN,
    RPAREN,
    IDENTIFIER,
    EOF,
}

Token :: struct {
    type:     Token_Type,
    position: u32,
    index:    u32,
}

Lexer :: struct {
    reader:   strings.Reader,
    position: u32,
}

create_lexer :: proc(input: string) -> Lexer {
    reader: strings.Reader
    strings.reader_init(&reader, input)

    lexer := Lexer {
        reader   = reader,
        position = 0,
    }
    read_rune(&lexer)
    return lexer
}
LexerError :: union {
    RuneError,
    UnexpectedEOFError,
    EOF,
}

RuneError :: struct {
    location: u32,
}
UnexpectedEOFError :: struct {
    location: u32,
    expected: rune,
}
EOF :: struct {}

read_rune :: proc(lexer: ^Lexer) -> (char: rune, err: LexerError) {
    r_char, size, r_err := strings.reader_read_rune(&lexer.reader)
    if r_err != nil {
        assert(r_err == io.Error.EOF)
        return 0, EOF{}
    }

    if r_char == utf8.RUNE_ERROR {
        return 0, RuneError{lexer.position}
    }

    lexer.position = lexer.position + 1
    return r_char, nil
}

peek_rune :: proc(lexer: ^Lexer) -> (char: rune, err: LexerError) {
    r := read_rune(lexer) or_return
    strings.reader_unread_rune(&lexer.reader)
    return r, nil
}

is_whitespace :: proc(ch: rune) -> bool {
    return unicode.is_space(ch)
}

is_letter :: proc(ch: rune) -> bool {
    return unicode.is_letter(ch) || ch == '_'
}

is_alphanumeric :: proc(ch: rune) -> bool {
    return unicode.is_letter(ch) || unicode.is_digit(ch) || ch == '_'
}

skip_whitespace :: proc(lexer: ^Lexer) -> (no_err: bool, err: LexerError) {
    c, p_err := peek_rune(lexer)
    for is_whitespace(c) && p_err == nil {
        c, p_err = peek_rune(lexer)
        read_rune(lexer)
    }
    return p_err == nil, p_err
}

read_identifier :: proc(lexer: ^Lexer) -> (ident: string, err: LexerError) {
    start_position := lexer.reader.i
    c := peek_rune(lexer) or_return
    for is_letter(c) || is_alphanumeric(c) {
        r_err: LexerError
        c, r_err = read_rune(lexer)
        #partial switch e in r_err {
        case RuneError:
            return "", e
        case EOF:
            break
        }
    }

    end_position := lexer.reader.i

    // Use slicing to extract the identifier
    return lexer.reader.s[start_position:end_position], nil
}

read_string :: proc(lexer: ^Lexer) -> (str: string, err: LexerError) {
    // Skip the opening quote
    read_rune(lexer)
    c := peek_rune(lexer) or_return
    start_position := lexer.reader.i
    for c != '"' {
        r_err: LexerError
        c, r_err = read_rune(lexer)
        #partial switch e in r_err {
        case RuneError:
            return "", e
        case EOF:
            break
        }
    }

    end_position := lexer.reader.i

    // Skip the closing quote
    if c == '"' {
        read_rune(lexer)
    } else {
        return "", UnexpectedEOFError {
            location = lexer.position,
            expected = '"',
        }
    }

    return lexer.reader.s[start_position:end_position], nil
}

tokenize :: proc(lexer: ^Lexer) -> Token {
    errs := make ()
    for true {
        token:= Token{}
        skip_whitespace(lexer)
        c, err := peek_rune(lexer)

        switch c {
        case '(':
            token = Token {
                type     = .LPAREN,
                position = lexer.position,
            }
            read_rune(lexer)
        case ')':
            token = Token {
                type     = .RPAREN,
                position = lexer.position,
            }
            read_rune(lexer)
        case '"':
            token.type = .STRING
            token.position = lexer.position
        case 0:
            token = Token {
                type     = .EOF,
                position = lexer.position,
            }
        case:
            if is_letter(c) {
                token.type = .IDENTIFIER
                token.position = lexer.position
            }
        }

    }
}


main :: proc() {
    for true {
        data := [500]byte{}
        bytes_read, err := os.read(os.stdin, data[:])
        str := strings.string_from_ptr(transmute(^byte)&data, bytes_read)
        fmt.print(str)
    }
}
