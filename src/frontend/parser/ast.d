module frontend.parser.ast;

import std.variant;
import std.stdio;
import std.conv;
import frontend.lexer.token : Location;
import frontend.parser.utils;

enum NodeKind
{
    Program,
    Identifier,
    IntLiteral,
    StringLiteral,
    VariableDeclaration,
    MainSection,
    Instruction
}

abstract class Node
{
    NodeKind kind;
    string type;
    Variant value;
    Location loc;
    int address;

    abstract void print(ulong ident);
}

class Program : Node
{
    Node[] body;

    this(Node[] body)
    {
        this.kind = NodeKind.Program;
        this.value = null;
        this.body = body;
    }

    override void print(ulong ident)
    {
        writeln("» Program Node");
        writeln("Body: [");
        foreach (Node n; body)
        {
            n.print(ident + 4);
        }
        writeln("]");
    }
}

class MainSection : Node
{
    Node[] body;

    this(Node[] body = [], Location loc)
    {
        this.kind = NodeKind.MainSection;
        this.value = null;
        this.body = body;
        this.type = "null";
    }

    override void print(ulong ident)
    {
        writeln(strRepeat(" ", ident) ~ "» MainSectionNode");
        writeln(strRepeat(" ", ident) ~ "Body: [");
        foreach (Node n; body)
        {
            n.print(ident + 4);
        }
        writeln(strRepeat(" ", ident) ~ "]");
    }
}

class Identifier : Node
{
    this(string id, Location loc)
    {
        this.kind = NodeKind.Identifier;
        this.value = id;
        this.type = "?";
        this.loc = loc;
    }

    override void print(ulong ident)
    {
        writeln(strRepeat(" ", ident) ~ "» Identifier");
        writefln(strRepeat(" ", ident) ~ "ID: %s", value);
    }
}

class IntLiteral : Node
{
    this(Variant value, Location loc)
    {
        this.kind = NodeKind.IntLiteral;
        this.type = "int";
        this.value = to!int(value.get!string);
        this.loc = loc;
    }

    override void print(ulong ident)
    {
        writeln(strRepeat(" ", ident) ~ "» IntLiteral");
        writefln(strRepeat(" ", ident) ~ "Value: %s", value.get!int);
    }
}

class StringLiteral : Node
{
    this(Variant value, Location loc)
    {
        this.kind = NodeKind.StringLiteral;
        this.type = "string";
        this.value = value.get!string;
        this.loc = loc;
    }

    override void print(ulong ident)
    {
        writeln(strRepeat(" ", ident) ~ "» StringLiteral");
        writefln(strRepeat(" ", ident) ~ "Value: %s", value.get!string);
    }
}

class VariableDeclaration : Node
{
    // x : int = 10
    // $0 : int = 10
    // $1 : int;
    string name;
    Node value;
    bool initialized, temp;

    this(string name, string type, Node value, bool initialized, bool temp, Location loc)
    {
        this.kind = NodeKind.VariableDeclaration;
        this.name = name;
        this.type = type;
        this.initialized = initialized;
        this.temp = temp;
        this.value = value;
        this.loc = loc;
    }

    override void print(ulong ident)
    {
        writeln(strRepeat(" ", ident) ~ "» VariableDeclaration");
        writefln(strRepeat(" ", ident) ~ "Name: %s", to!string(name));
        writefln(strRepeat(" ", ident) ~ "Type: %s", to!string(type));
        writefln(strRepeat(" ", ident) ~ "Value: %s", to!string(value));
        writefln(strRepeat(" ", ident) ~ "Initialized: %s", to!string(initialized));
        writefln(strRepeat(" ", ident) ~ "Temp: %s", to!string(temp));
    }
}

class Instruction : Node
{
    // HALT -> args = []
    // ADD $0, $1, $2 -> args = [ $0, $1, $2 ]
    // ADD $0, 0x00, 0x01 -> args = [ $0, 0x00, 0x01 ]
    Node[] args;
    this(string ins, Node[] args, Location loc)
    {
        this.kind = NodeKind.Instruction;
        this.args = args;
        this.type = "?";
        this.value = Variant(ins);
        this.loc = loc;
    }

    override void print(ulong ident)
    {
        writeln(strRepeat(" ", ident) ~ "» Instruction");
        writefln(strRepeat(" ", ident) ~ "Value: %s", to!string(value));
        writeln(strRepeat(" ", ident) ~ "Args: [");
        foreach (Node n; args)
        {
            n.print(ident + 4);
        }
        writeln(strRepeat(" ", ident) ~ "]");
    }
}
