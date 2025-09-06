module frontend.lexer.lexer;

import std.ascii;
import std.stdio;
import std.conv;
import std.variant;
import frontend.lexer.token;

class Lexer
{
private:
    string file;
    string source;
    ulong line = 1;
    ulong offset = 0;
    ulong offsetLine = 0;

    Token[] tokens;
    TokenKind[string] keywords;
    TokenKind[string] symbols;

    void initializeKeywords()
    {
        keywords["add"] = TokenKind.Add;
        keywords["print"] = TokenKind.Print;
        keywords["halt"] = TokenKind.Halt;
        keywords["store"] = TokenKind.Store;
        // keywords["iload"] = TokenKind.Iload;
        keywords["load"] = TokenKind.Load;
        // keywords["sload"] = TokenKind.Sload;
        keywords["ret"] = TokenKind.Ret;
        keywords["call"] = TokenKind.Call;
        keywords["fn"] = TokenKind.Fn;
        keywords["input"] = TokenKind.Input;
        keywords["sconc"] = TokenKind.StrConcat;
    }

    void initializeSymbols()
    {
        symbols["+"] = TokenKind.Plus;
        symbols["-"] = TokenKind.Minus;
        symbols["="] = TokenKind.Equals;
        symbols[":"] = TokenKind.Colon;
        symbols[";"] = TokenKind.SemiColon;
        symbols[","] = TokenKind.Comma;
        symbols["("] = TokenKind.LParen;
        symbols[")"] = TokenKind.RParen;
        symbols["{"] = TokenKind.LBRace;
        symbols["}"] = TokenKind.RBrace;
        symbols["."] = TokenKind.Dot;
        symbols["$"] = TokenKind.Dollar;
        symbols["?"] = TokenKind.Question;
    }

    bool isAtEnd()
    {
        return offset >= source.length;
    }

    char peek(ulong lookahead = 0)
    {
        ulong pos = offset + lookahead;
        if (pos >= source.length)
            return '\0';
        return source[pos];
    }

    char advance()
    {
        if (isAtEnd())
            return '\0';
        return source[offset++];
    }

    Location getLocation(ulong start, ulong end)
    {
        return Location(
            this.file,
            start,
            end,
            this.line,
        );
    }

    void addToken(TokenKind kind, Variant value, ulong start, ulong length)
    {
        this.tokens ~= Token(
            kind,
            value,
            this.getLocation(start, start + length)
        );
    }

    bool lexString()
    {
        char quote = source[offset - 1];
        string value = "";
        ulong start = offset - 1;

        while (!isAtEnd() && peek() != quote)
        {
            char ch = peek();

            if (ch == '\n')
            {
                line++;
                offsetLine = offset + 1;
            }

            if (ch == '\\' && !isAtEnd())
            {
                advance();
                if (!isAtEnd())
                {
                    char escaped = advance();
                    value ~= getEscapedChar(escaped);
                }
            }
            else
            {
                value ~= advance();
            }
        }

        if (isAtEnd())
        {
            throw new Exception("Unclosed string in line " ~ to!string(line));
        }

        advance();

        addToken(TokenKind.String, Variant(value), start, offset - start);
        return true;
    }

    char getEscapedChar(char ch)
    {
        switch (ch)
        {
        case 'n':
            return '\n';
        case 't':
            return '\t';
        case 'r':
            return '\r';
        case '\\':
            return '\\';
        case '\'':
            return '\'';
        case '"':
            return '"';
        case '0':
            return '\0';
        default:
            return ch;
        }
    }

    bool lexComment()
    {
        if (peek() == '/')
        {
            advance();
            while (!isAtEnd() && peek() != '\n')
            {
                advance();
            }
            return true;
        }
        else if (peek() == '*')
        {
            advance();

            while (!isAtEnd())
            {
                if (peek() == '*' && peek(1) == '/')
                {
                    advance();
                    advance();
                    return true;
                }

                if (peek() == '\n')
                {
                    line++;
                    offsetLine = offset + 1;
                }
                advance();
            }

            throw new Exception("Comentário de bloco não fechado");
        }

        return false;
    }

    void lexIdentifier()
    {
        ulong start = offset - 1;

        while (!isAtEnd() && (isAlpha(peek()) || isDigit(peek()) || peek() == '_'))
        {
            advance();
        }

        string identifier = source[start .. offset];
        TokenKind tokenType = TokenKind.Identifier;

        if (auto keywordType = identifier in keywords)
        {
            tokenType = *keywordType;
        }

        addToken(tokenType, Variant(identifier), start, identifier.length);
    }

    void lexNumber()
    {
        ulong start = offset - 1;

        while (!isAtEnd() && isDigit(peek()))
        {
            advance();
        }

        TokenKind type = TokenKind.Int;

        if (!isAtEnd() && peek() == '.' && isDigit(peek(1)))
        {
            type = TokenKind.Float;
            advance(); // Consome o '.'
            while (!isAtEnd() && isDigit(peek()))
            {
                advance();
            }
        }

        string numberStr = source[start .. offset];
        addToken(type, Variant(numberStr), start, numberStr.length);
    }

    void lexSymbol(char ch)
    {
        string symbol = [ch];
        ulong start = offset - 1;

        if (auto symbolType = symbol in symbols)
        {
            addToken(*symbolType, Variant(symbol), start, 1);
        }
        else
        {
            throw new Exception("Unknown symbol '" ~ symbol ~ "' in line " ~ to!string(
                    line));
        }
    }

public:
    this(string src, string file = "main.fir")
    {
        this.file = file;
        source = src;
        initializeKeywords();
        initializeSymbols();
    }

    Token[] tokenize()
    {
        try
        {
            while (!isAtEnd())
            {
                char ch = advance();

                if (ch == '\n')
                {
                    line++;
                    offsetLine = offset;
                    continue;
                }

                if (isWhite(ch))
                    continue;

                if (ch == '"' || ch == '\'')
                {
                    lexString();
                    continue;
                }

                if (ch == '/')
                {
                    if (lexComment())
                        continue;
                    else
                        lexSymbol(ch);
                    continue;
                }

                if (isDigit(ch))
                {
                    lexNumber();
                    continue;
                }

                if (isAlpha(ch) || ch == '_')
                {
                    lexIdentifier();
                    continue;
                }

                lexSymbol(ch);
            }
        }
        catch (Exception e)
        {
            writeln("Erro no lexer: ", e.msg);
            throw e;
        }

        addToken(TokenKind.Eof, Variant(""), offset, 0);
        return tokens;
    }
}
