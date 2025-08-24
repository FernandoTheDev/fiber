module backend.codegen.builder;

import std.stdio;
import std.variant;
import std.conv;
import std.format;
import std.string;
import backend.codegen.api;
import middle.memory.memory;
import frontend.parser.ast;

class Builder
{
private:
    FiberMemory mem;
    FiberBuilder api;

    int getAddr(Node node)
    {
        switch (node.kind)
        {
        case NodeKind.Identifier:
            string id = node.value.get!string;
            // writeln(id);
            // writeln(this.mem.pointers);
            // writeln("mem ", id, ": ", this.mem.pointers[id]);
            return this.mem.pointers[id];
        case NodeKind.IntLiteral:
            return node.value.get!int;
        default:
            throw new Exception(format("GetAddr node desconhecido: ", node.kind));
            break;
        }
    }

    void generateMainSection(MainSection node)
    {
        for (long i; i < node.body.length; i++)
        {
            this.generate(node.body[i]);
        }
    }

    void generateProgram(Program node)
    {
        for (long i; i < node.body.length; i++)
        {
            this.generate(node.body[i]);
        }
    }

    void generateInstruction(Instruction node)
    {
        string instr = node.value.get!string;
        switch (instr)
        {
        case "print":
            int addr = this.getAddr(node.args[0]);
            this.api.print(addr);
            break;
        case "store":
            int target = this.getAddr(node.args[0]);
            int value = this.getAddr(node.args[1]);
            this.api.store(target, value);
            break;
        case "add":
            int target = this.getAddr(node.args[0]);
            int x = this.getAddr(node.args[1]);
            int y = this.getAddr(node.args[2]);
            this.api.add(target, x, y);
            break;
        case "halt":
            this.api.halt();
            break;
        default:
            throw new Exception(format("Instrução desconhecida: %s", instr));
        }
    }

public:
    this(FiberMemory mem)
    {
        this.mem = mem;
        this.api = new FiberBuilder();
    }

    void generate(Node node)
    {
        switch (node.kind)
        {
        case NodeKind.Program:
            this.generateProgram(cast(Program) node);
            break;
        case NodeKind.Instruction:
            this.generateInstruction(cast(Instruction) node);
            break;
        case NodeKind.MainSection:
            this.generateMainSection(cast(MainSection) node);
            break;
        case NodeKind.Identifier:
        case NodeKind.VariableDeclaration:
            // Ignore
            break;
        default:
            node.print(0);
            throw new Exception("Node desconhecido.");
        }
    }

    // Métodos utilitários
    int[] build()
    {
        return this.api.build();
    }

    string disassemble()
    {
        return this.api.disassemble();
    }

    void addLabel(string name)
    {
        this.api.label(name);
    }

    int getCurrentAddress()
    {
        return this.api.getCurrentAddress();
    }
}
