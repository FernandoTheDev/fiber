module frontend.lexer.token;

import std.variant;

enum TokenKind
{
    // Keywords
    Add,
    Print,
    Halt,
    Store,
    Load,
    Ret,
    Call,
    Fn,
    Input,
    StrConcat,

    Identifier, // id

    // Types
    Int,
    Float,
    Double,
    Bool,
    String,

    // Symbols
    Plus, // +
    Minus, // -
    Equals, // =
    Colon, // :
    SemiColon, // ;
    Comma, // ,
    Dot, // .
    Dollar, // $
    LParen, // (
    RParen, // )
    LBRace, // {
    RBrace, // }
    Question, // ?

    Eof, // end of file
}

struct Location
{
    string file;
    ulong startOffset;
    ulong endOffset;
    ulong line;
}

struct Token
{
    TokenKind kind;
    Variant value;
    Location loc;
}
