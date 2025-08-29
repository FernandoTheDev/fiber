module middle.semantic;

import std.stdio;
import std.format;
import std.format;
import std.variant;
import std.conv;
import std.random : uniform;
import middle.memory.memory;
import frontend.parser.ast;

struct FnMemoryAlloc
{
    int[] callArgs;
    int callRet;
    int[] fnArgs;
    int fnRet;
}

class Semantic
{
private:
    FiberMemory mem;
public:
    FnMemoryAlloc[string] functionsMemory;

    this(FiberMemory mem)
    {
        this.mem = mem;
    }

    Node analyzeNode(Node node)
    {
        switch (node.kind)
        {
        case NodeKind.Program:
            return analyzeProgram(cast(Program) node);
        case NodeKind.MainSection:
            return analyzeMainSection(cast(MainSection) node);
        case NodeKind.VariableDeclaration:
            return analyzeVarDeclaration(cast(VariableDeclaration) node);
        case NodeKind.FnDeclaration:
            return analyzeFnDeclaration(cast(FnDeclaration) node);
        case NodeKind.CallFn:
            return analyzeCallFn(cast(CallFn) node);
        case NodeKind.Identifier:
            return analyzeID(cast(Identifier) node);
        case NodeKind.Instruction:
            return analyzeInstr(cast(Instruction) node);
        default:
            return node;
        }
    }

    Instruction analyzeInstr(Instruction node)
    {
        string name = node.value.get!string;
        if (name == "call")
        {
            CallFn callFn = cast(CallFn) analyzeNode(node.args[0]); // fn
            Identifier callRet = cast(Identifier) analyzeNode(node.args[1]); // $0, x, y
            functionsMemory[callFn.name].callRet = callRet.address;
        }
        else
        {
            for (long i; i < node.args.length; i++)
            {
                node.args[i] = analyzeNode(node.args[i]);
            }
        }
        return node;
    }

    CallFn analyzeCallFn(CallFn node)
    {
        if (node.name !in functionsMemory)
            functionsMemory[node.name] = FnMemoryAlloc();
        foreach (CallArg arg; node.args)
        {
            // TODO: validar isso
            int pointerToMemory = mem.getContextInfoCurrent().pointers[arg.name];
            functionsMemory[node.name].callArgs ~= pointerToMemory;
        }
        return node;
    }

    FnDeclaration analyzeFnDeclaration(FnDeclaration node)
    {
        string ctx = mem.getCurrentContext();
        string newCtx = mem.createContext();
        mem.loadContext(newCtx);
        for (long i; i < node.args.length; i++)
        {
            auto arg = node.args[i];
            auto pointer = mem.alloca(arg.name, 0);
            functionsMemory[node.name].fnArgs ~= pointer;
        }
        for (long i; i < node.body.length; i++)
        {
            Node body = node.body[i];
            if (body.kind == NodeKind.Instruction)
            {
                Instruction instr = cast(Instruction)
                body;
                if (instr.value.get!string == "ret")
                {
                    Identifier fnRet = cast(Identifier) analyzeNode(instr.args[0]);
                    functionsMemory[node.name].fnRet = fnRet.address;
                }
            }
            node.body[i] = this.analyzeNode(body);
        }
        mem.loadContext(ctx);
        return node;
    }

    Identifier analyzeID(Identifier node)
    {
        node.address = this.mem.getContextInfoCurrent().pointers[node.value.get!string];
        return node;
    }

    VariableDeclaration analyzeVarDeclaration(VariableDeclaration node)
    {
        int value = 0;
        if (node.initialized)
            value = this.analyzeNode(node.value).value.get!int;
        int addr = this.mem.alloca(node.name, value);
        node.address = addr;
        return node;
    }

    MainSection analyzeMainSection(MainSection node)
    {
        for (long i; i < node.body.length; i++)
            node.body[i] = this.analyzeNode(node.body[i]);
        return node;
    }

    Program analyzeProgram(Program node)
    {
        for (long i; i < node.body.length; i++)
            node.body[i] = this.analyzeNode(node.body[i]);
        return node;
    }
}
