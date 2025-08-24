module middle.semantic;

import std.stdio;
import std.format;
import std.format;
import std.variant;
import std.conv;
import std.random : uniform;
import middle.memory.memory;
import frontend.parser.ast;

class Semantic
{
private:
    FiberMemory mem;
public:
    this(FiberMemory mem)
    {
        this.mem = mem;
    }

    Node analyzeNode(Node node)
    {
        switch (node.kind)
        {
        case NodeKind.Program:
            return this.analyzeProgram(cast(Program) node);
        case NodeKind.MainSection:
            return this.analyzeMainSection(cast(MainSection) node);
        case NodeKind.VariableDeclaration:
            return this.analyzeVarDeclaration(cast(VariableDeclaration) node);
        case NodeKind.Identifier:
            return analyzeID(cast(Identifier) node);
        case NodeKind.IntLiteral:
            // int randomId = uniform(1000, 999_999);
            // int addr = this.mem.alloca(to!string(randomId), node.value.get!int);
            // node.address = addr;
            return node;
        default:
            return node;
        }
    }

    Identifier analyzeID(Identifier node)
    {
        node.address = this.mem.pointers[node.value.get!string];
        writeln("ADDR: ", node.address);
        return node;
    }

    VariableDeclaration analyzeVarDeclaration(VariableDeclaration node)
    {
        int value = 0;
        if (node.initialized)
        {
            value = this.analyzeNode(node.value).value.get!int;
        }
        int addr = this.mem.alloca(node.name, value);
        node.address = addr;
        return node;
    }

    MainSection analyzeMainSection(MainSection node)
    {
        for (long i; i < node.body.length; i++)
        {
            node.body[i] = this.analyzeNode(node.body[i]);
        }
        return node;
    }

    Program analyzeProgram(Program node)
    {
        for (long i; i < node.body.length; i++)
        {
            node.body[i] = this.analyzeNode(node.body[i]);
        }
        return node;
    }
}
