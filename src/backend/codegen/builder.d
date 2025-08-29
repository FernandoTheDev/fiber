module backend.codegen.builder;

import std.stdio;
import std.variant;
import std.conv;
import std.format;
import std.string;
import backend.codegen.api;
import middle.memory.memory;
import middle.semantic : FnMemoryAlloc;
import frontend.parser.ast;

class Builder
{
private:
    FiberMemory mem;
    FiberBuilder api;
    FnMemoryAlloc[string] functionsMemory;
    string functionName;

    int getAddr(Node node)
    {
        switch (node.kind)
        {
        case NodeKind.Identifier:
            string id = node.value.get!string;
            // writeln("ID ", id);
            // writeln("CONTEXT ", this.mem.getCurrentContext());
            // writeln("POINTER ", this.mem.getContextInfoCurrent());
            // writeln("POINTER MEMORY ", mem.getContextInfoCurrent().pointers);
            return this.mem.getContextInfoCurrent().pointers[id];
        case NodeKind.IntLiteral:
            return node.value.get!int;
        default:
            throw new Exception(format("GetAddr node desconhecido: ", node.kind));
            break;
        }
    }

    void generateMainSection(MainSection node)
    {
        mem.loadContext("global");
        this.api.label("main");
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

    void generateFnDeclaration(FnDeclaration node)
    {
        // TODO: corrigir isso
        mem.loadContext("ctx_0");
        functionName = node.name;
        this.api.label(node.name);
        for (long i; i < node.body.length; i++)
        {
            this.generate(node.body[i]);
        }
        functionName = "";
        mem.loadContext("global");
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
        case "load":
            int target = this.getAddr(node.args[0]);
            int value = this.getAddr(node.args[1]);
            this.api.load(target, value);
            break;
        case "add":
            int target = this.getAddr(node.args[0]);
            int x = this.getAddr(node.args[1]);
            int y = this.getAddr(node.args[2]);
            this.api.add(target, x, y);
            break;
        case "call":
            CallFn n = cast(CallFn) node.args[0];
            // carrega os argumentos
            FnMemoryAlloc fn = functionsMemory[n.name];
            for (long i; i < fn.callArgs.length; i++)
            {
                api.load(fn.fnArgs[i], fn.callArgs[i]);
            }
            this.api.call(n.name);
            break;
        case "halt":
            this.api.halt();
            break;
        case "ret":
            FnMemoryAlloc fn = functionsMemory[functionName];
            api.load(fn.callRet, fn.fnRet);
            this.api.ret();
            break;
        default:
            throw new Exception(format("Instrução desconhecida: %s", instr));
        }
    }

public:
    this(FiberMemory mem, FnMemoryAlloc[string] memory)
    {
        this.functionsMemory = memory;
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
        case NodeKind.FnDeclaration:
            this.generateFnDeclaration(cast(FnDeclaration) node);
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
