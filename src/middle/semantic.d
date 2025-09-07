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
    int callRet = -1;
    int[] fnArgs;
    int fnRet;
    string[] fnArgsP;
    string[] callArgsP;
}

class Semantic
{
private:
    FiberMemory mem;
public:
    FnMemoryAlloc[string] functionsMemory;
    string[string] functionsContext;

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
            if (node.args.length == 2)
            {
                Identifier callRet = cast(Identifier) analyzeNode(node.args[1]); // $0, x, y
                functionsMemory[callFn.name].callRet = callRet.address;
            }
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
            functionsMemory[node.name].callArgsP ~= arg.name;
        }
        return node;
    }

    int allocaMemoryToType(string arg, string type)
    {
        switch (type)
        {
        case "string":
            return mem.allocaString(arg, "");
        case "int":
            return mem.alloca(arg, 0);
        default:
            throw new Exception(format("Unknow type '%s'", type));
        }
    }

    FnDeclaration analyzeFnDeclaration(FnDeclaration node)
    {
        string ctx = mem.getCurrentContext();
        mem.createContext(node.name);
        functionsContext[node.name] = node.name;
        mem.loadContext(node.name);
        for (long i; i < node.args.length; i++)
        {
            auto arg = node.args[i];
            int pointer = this.allocaMemoryToType(arg.name, arg.type);
            functionsMemory[node.name].fnArgs ~= pointer;
            functionsMemory[node.name].fnArgsP ~= arg.name;
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
                    if (instr.args.length == 1)
                    {
                        Identifier fnRet = cast(Identifier) analyzeNode(instr.args[0]);
                        functionsMemory[node.name].fnRet = fnRet.address;
                    }
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
        int addr;

        if (node.initialized)
        {
            Node analyzedValue = this.analyzeNode(node.value);

            // Verifica o tipo do valor e chama o método apropriado
            if (analyzedValue.value.type() == typeid(string) ||
                analyzedValue.value.type() == typeid(immutable(char)[]))
            {
                string strValue = analyzedValue.value.get!string;
                // Remove as aspas se existirem
                if (strValue.length >= 2 && strValue[0] == '"' && strValue[$ - 1] == '"')
                {
                    strValue = strValue[1 .. $ - 1];
                }
                addr = this.mem.allocaString(node.name, strValue);
            }
            else if (analyzedValue.value.type() == typeid(int))
            {
                int intValue = analyzedValue.value.get!int;
                addr = this.mem.alloca(node.name, intValue);
            }
            else
            {
                // Tenta converter para int como fallback
                try
                {
                    int intValue = analyzedValue.value.get!int;
                    addr = this.mem.alloca(node.name, intValue);
                }
                catch (Exception e)
                {
                    // Se não conseguir converter, trata como string
                    string strValue = analyzedValue.value.get!string;
                    if (strValue.length >= 2 && strValue[0] == '"' && strValue[$ - 1] == '"')
                    {
                        strValue = strValue[1 .. $ - 1];
                    }
                    addr = this.mem.allocaString(node.name, strValue);
                }
            }
        }
        else
        {
            addr = this.allocaMemoryToType(node.name, node.type);
        }

        node.address = addr;
        return node;
    }

    // Método auxiliar para determinar se uma instrução precisa trabalhar com string
    bool isStringOperation(Instruction instr, string varName)
    {
        if (varName in mem.getContextInfoCurrent().pointers)
        {
            return mem.getVariableType(varName) == DataType.STRING_REF;
        }
        return false;
    }

    // VariableDeclaration analyzeVarDeclaration(VariableDeclaration node)
    // {
    //     int value = 0;
    //     if (node.initialized)
    //         value = this.analyzeNode(node.value).value.get!int;
    //     int addr = this.mem.alloca(node.name, value);
    //     node.address = addr;
    //     return node;
    // }

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
