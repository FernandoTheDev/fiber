module frontend.parser.parser;

import std.typecons;
import std.format;
import std.stdio;
import std.conv;
import std.variant;
import frontend.lexer.token;
import frontend.parser.ast;

enum Precedence
{
    LOWEST = 1,
    CALL = 2,
}

class Parser
{
private:
    Token[] tokens;
    ulong pos = 0;

    Node parsePrefix()
    {
        Token token = this.advance();

        switch (token.kind)
        {
            // Literals
        case TokenKind.Int:
            return new IntLiteral(token.value, token.loc);
        case TokenKind.Float:
            return new FloatLiteral(token.value, token.loc);
        case TokenKind.String:
            return new StringLiteral(token.value, token.loc);

            // ID's
        case TokenKind.Dollar:
            Token name = this.consume(TokenKind.Int, "Expected a int (0..9) to name of temp var.");
            if (this.peek()
                .kind == TokenKind.Colon)
                return this.parseVarDeclaration(name, true);
            return new Identifier(name.value.get!string, token.loc);
        case TokenKind.Identifier:
            if (this.peek()
                .kind == TokenKind.Colon)
                return this.parseVarDeclaration(token, false);
            if (this.peek()
                .kind == TokenKind.LParen)
                return this.parseCallFn();
            return new Identifier(token.value.get!string, token.loc);

            // Instructions
        case TokenKind.Print:
            // print <value>
            Node arg = this.parseExpression(Precedence.LOWEST);
            return new Instruction("print", [] ~ arg, token.loc);
        case TokenKind.Halt:
            // halt
            return new Instruction("halt", [], token.loc);
        case TokenKind.Store:
            // store <target>, <value>
            Node[] args;
            args ~= this.parseExpression(Precedence.LOWEST);
            this.consume(TokenKind.Comma, "Expected ',' to separate the statement arguments.");
            args ~= this.parseExpression(Precedence.LOWEST);
            return new Instruction("store", args, token.loc);
        case TokenKind.Load:
            // load <target>, <addr>
            Node[] args;
            args ~= this.parseExpression(Precedence.LOWEST);
            this.consume(TokenKind.Comma, "Expected ',' to separate the statement arguments.");
            args ~= this.parseExpression(Precedence.LOWEST);
            return new Instruction("load", args, token.loc);
        case TokenKind.Add:
            // add <target>, <x>, <y>
            Node[] args;
            args ~= this.parseExpression(Precedence.LOWEST);
            this.consume(TokenKind.Comma, "Expected ',' to separate the statement arguments.");
            args ~= this.parseExpression(Precedence.LOWEST);
            this.consume(TokenKind.Comma, "Expected ',' to separate the statement arguments.");
            args ~= this.parseExpression(Precedence.LOWEST);
            return new Instruction("add", args, token.loc);
        case TokenKind.StrConcat:
            // sconc <target>, <x>, <y>
            Node[] args;
            args ~= this.parseExpression(Precedence.LOWEST);
            this.consume(TokenKind.Comma, "Expected ',' to separate the statement arguments.");
            args ~= this.parseExpression(Precedence.LOWEST);
            this.consume(TokenKind.Comma, "Expected ',' to separate the statement arguments.");
            args ~= this.parseExpression(Precedence.LOWEST);
            return new Instruction("sconc", args, token.loc);
        case TokenKind.Ret:
            // ret <value> ;
            Node[] args = [];
            if (this.match([TokenKind.SemiColon]))
                return new Instruction("ret", args, token.loc);
            Node arg = this.parseExpression(Precedence.LOWEST);
            return new Instruction("ret", args ~ arg, token.loc);
        case TokenKind.Input:
            // ret <value> ;
            Node[] args = [];
            Node arg = this.parseExpression(Precedence.LOWEST);
            return new Instruction("input", args ~ arg, token.loc);
        case TokenKind.Call:
            // call fn(), <var>
            Node[] args;
            args ~= this.parseExpression(Precedence.LOWEST);
            if (this.match([TokenKind.Comma]))
                args ~= this.parseExpression(Precedence.LOWEST);
            return new Instruction("call", args, token.loc);

            // Keywords
        case TokenKind.Fn:
            return this.parseFnDeclaration();

            // Section
        case TokenKind.Dot:
            return this.parseSection();
        default:
            throw new Exception("Noo prefix parse function for " ~ to!string(token));
        }
    }

    Node parseCallFn()
    {
        // Token name = this.consume(TokenKind.Identifier, "Expected identifier to name of function.");
        Token name = this.previous();
        this.consume(TokenKind.LParen, "Expected '(' after function name.");
        CallArg[] args = this.parseCallArguments();
        this.consume(TokenKind.RParen, "Expected ')' after function arguments.");
        return new CallFn(name.value.get!string, args, name.loc);
    }

    CallArg[] parseCallArguments()
    {
        CallArg[] args;
        while (this.peek().kind != TokenKind.RParen && !this.isAtEnd())
        {
            Token type = this.consume(TokenKind.Identifier, "Expected identifier to type name.");
            Node argName = this.parseExpression(Precedence.LOWEST); // Identifier
            if (argName.kind != NodeKind.Identifier)
            {
                throw new Exception(format("The argument should be an identifier but is a '%s'", argName
                        .kind));
            }
            args ~= CallArg(argName.value.get!string, type.value.get!string, argName.loc);
            this.match([TokenKind.Comma]);
        }
        return args;
    }

    Node parseFnDeclaration()
    {
        Token name = this.consume(TokenKind.Identifier, "Expected identifier to function name.");

        this.consume(TokenKind.LParen, "Expected '(' after function name.");
        FnArg[] args = this.parseFnArguments();
        this.consume(TokenKind.RParen, "Expected ')' after function arguments.");

        Token type = this.consume(TokenKind.Identifier, "Expected identifier to type of function.");
        this.consume(TokenKind.LBRace, "Expected '{' after function type.");

        Node[] body;
        while (this.peek().kind != TokenKind.RBrace && !this.isAtEnd())
        {
            body ~= this.parseExpression(Precedence.LOWEST);
        }
        this.consume(TokenKind.RBrace, "Expected '}' after function.");
        return new FnDeclaration(name.value.get!string, args, body, type.value.get!string, name.loc);
    }

    FnArg[] parseFnArguments()
    {
        FnArg[] args;
        while (this.peek().kind != TokenKind.RParen && !this.isAtEnd())
        {
            Token type = this.consume(TokenKind.Identifier, "Expected identifier to type name.");
            Node argName = this.parseExpression(Precedence.LOWEST); // Identifier
            if (argName.kind != NodeKind.Identifier)
            {
                throw new Exception(format("The argument should be an identifier but is a '%s'", argName
                        .kind));
            }
            args ~= FnArg(argName.value.get!string, type.value.get!string, argName
                    .loc);
            this.match([TokenKind.Comma]);
        }
        return args;
    }

    Node parseVarDeclaration(Token name, bool temp = false)
    {
        bool initialized = true;
        Node value;
        this.consume(TokenKind.Colon, "..");
        Token type = this.consume(TokenKind.Identifier, "Expected identifier to name of type.");

        if (this.match([TokenKind.SemiColon]))
        {
            initialized = false;
        }
        else
        {
            this.consume(TokenKind.Equals, "Expected '=' after type name.");
            value = this.parseExpression(Precedence.LOWEST);
        }
        return new VariableDeclaration(name.value.get!string, type.value.get!string, value, initialized, temp, name
                .loc);
    }

    Node parseSection()
    {
        Token tk = this.advance();
        string section = tk.value.get!string;
        switch (section)
        {
        case "main":
            return this.parseSectionMain();
        default:
            throw new Exception(format("Section not exists '%s'.", section));
        }
    }

    Node parseSectionMain()
    {
        Location loc = this.previous().loc;
        this.consume(TokenKind.LBRace, "Expected '{' after section name.");
        Node[] body;
        while (this.peek().kind != TokenKind.RBrace && !this.isAtEnd())
        {
            body ~= this.parseExpression(Precedence.LOWEST);
        }
        this.consume(TokenKind.RBrace, "Expected '}' after section.");
        return new MainSection(body, loc);
    }

    void infix(ref Node leftOld)
    {
        switch (this.peek().kind)
        {
        default:
            return;
        }
    }

    Node parseExpression(Precedence precedence)
    {
        Node left = this.parsePrefix();

        while (!this.isAtEnd() && precedence < this.peekPrecedence())
        {
            ulong oldPos = this.pos;
            this.infix(left);

            if (this.pos == oldPos)
            {
                break;
            }
        }

        return left;
    }

    Node parseNode()
    {
        Node Node = this.parseExpression(Precedence.LOWEST);
        return Node;
    }

    bool isAtEnd()
    {
        return this.peek().kind == TokenKind.Eof;
    }

    Variant next()
    {
        if (this.isAtEnd())
            return Variant(false);
        return Variant(this.tokens[this.pos + 1]);
    }

    Token peek()
    {
        return this.tokens[this.pos];
    }

    Token previous(ulong i = 1)
    {
        return this.tokens[this.pos - i];
    }

    Token advance()
    {
        if (!this.isAtEnd())
            this.pos++;
        return this.previous();
    }

    bool match(TokenKind[] kinds)
    {
        foreach (kind; kinds)
        {
            if (this.check(kind))
            {
                this.advance();
                return true;
            }
        }
        return false;
    }

    bool check(TokenKind kind)
    {
        if (this.isAtEnd())
            return false;
        return this.peek().kind == kind;
    }

    Token consume(TokenKind expected, string message)
    {
        if (this.check(expected))
            return this.advance();
        throw new Exception(format(`Erro de parsing: %s`, message));
    }

    Precedence getPrecedence(TokenKind kind)
    {
        switch (kind)
        {
        default:
            return Precedence.LOWEST;
        }
    }

    Precedence peekPrecedence()
    {
        return this.getPrecedence(this.peek().kind);
    }

    Location makeLoc(ref Location start, ref Location end)
    {
        return Location(start.file, start.line, start.startOffset, end.endOffset);
    }

public:
    this(Token[] tokens = [])
    {
        this.tokens = tokens;
    }

    Program parse()
    {
        Program program = new Program([]);
        program.type = "null";
        program.value = null;

        try
        {
            while (!this.isAtEnd())
            {
                program.body ~= this.parseNode();
            }

            if (this.tokens.length == 0)
            {
                return program;
            }

            program.loc = this.makeLoc(this.tokens[0].loc, this
                    .tokens[$ - 1].loc);
        }
        catch (Exception e)
        {

            writeln("Erro:", e.msg);
            throw e;
        }

        return program;
    }
}
