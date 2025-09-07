module backend.codegen.builder;

import std.stdio;
import std.variant;
import std.conv;
import std.format;
import std.string;
import backend.codegen.api;
import middle.memory.memory;
import middle.semantic;
import frontend.parser.ast;

class Builder
{
private:
    FiberMemory mem;
    FiberBuilder api;
    Semantic semantic;
    string functionName;

    int getAddr(Node node)
    {
        switch (node.kind)
        {
        case NodeKind.Identifier:
            string id = node.value.get!string;
            return this.mem.getContextInfoCurrent().pointers[id];
        case NodeKind.IntLiteral:
            return node.value.get!int;
        default:
            throw new Exception(format("GetAddr node desconhecido: ", node.kind));
            break;
        }
    }

    // Novo método para verificar se uma variável é string
    bool isStringVariable(string varName)
    {
        try
        {
            auto ctx = mem.getContextInfoCurrent();
            if (varName in ctx.pointers)
            {
                return mem.getVariableType(varName) == DataType.STRING_REF;
            }
        }
        catch (Exception e)
        {
            // Se der erro, assume que é inteiro
        }
        return false;
    }

    // Método para obter string de uma variável para geração de código
    string getStringValue(string varName)
    {
        try
        {
            return mem.getStringValue(varName);
        }
        catch (Exception e)
        {
            return "";
        }
    }

    void generateMainSection(MainSection node)
    {
        mem.loadContext("global");
        this.api.label("main");

        // Primeiro, gerar carregamento de strings inicializadas
        generateStringInitializations(node.body);

        // Depois gerar o resto das instruções
        for (long i; i < node.body.length; i++)
        {
            this.generate(node.body[i]);
        }
    }

    // Novo método para gerar carregamento de strings
    void generateStringInitializations(Node[] nodes)
    {
        foreach (node; nodes)
        {
            if (node.kind == NodeKind.VariableDeclaration)
            {
                auto varDecl = cast(VariableDeclaration) node;
                if (varDecl.type == "string" && varDecl.initialized)
                {
                    generateStringLoad(varDecl);
                }
            }
        }
    }

    void generateStringLoad(VariableDeclaration varDecl)
    {
        string stringValue = getStringValue(varDecl.name);
        int stringId = mem.addStringToHeap(stringValue);

        // STR_LOAD address, string_id
        this.api.strLoad(varDecl.address, stringId);
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
        string ctx = mem.getCurrentContext();
        mem.loadContext(semantic.functionsContext[node.name]);
        this.functionName = node.name;
        this.api.label(node.name);
        generateStringInitializations(node.body);
        for (long i; i < node.body.length; i++)
        {
            this.generate(node.body[i]);
        }
        this.functionName = "";
        mem.loadContext(ctx);
    }

    void generateInstruction(Instruction node)
    {
        string instr = node.value.get!string;
        switch (instr)
        {
        case "print":
            generatePrintInstruction(node);
            break;
        case "input":
            generateInputInstruction(node);
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
        case "sconc":
            int target = this.getAddr(node.args[0]);
            int x = this.getAddr(node.args[1]);
            int y = this.getAddr(node.args[2]);
            this.api.strConcat(target, x, y);
            break;
        case "call":
            CallFn n = cast(CallFn) node.args[0];
            FnMemoryAlloc fn = semantic.functionsMemory[n.name];
            for (long i; i < fn.callArgs.length; i++)
            {
                if (n.args[i].type == "string")
                {
                    writeln("fN NAME: ", n.name);
                    writeln("fN CONTEXT BEFORE: ", mem.getCurrentContextRef(n.name));

                    writeln("Heap CALL: ", mem.getCurrentContextRef()
                            .stringHeap[mem.memory[fn.callArgs[i]].value]);
                    writeln("Before: ", mem.contexts[n.name]
                            .stringHeap[mem.memory[fn.fnArgs[i]].value]);

                    mem.getCurrentContextRef(n.name)
                        .stringHeap[mem.memory[fn.fnArgs[i]].value] = mem.getCurrentContextRef()
                        .stringHeap[mem.memory[fn.fnArgs[i]].value];
                    writeln("After: ", mem.contexts[n.name]
                            .stringHeap[mem.memory[fn.fnArgs[i]].value]);

                    writeln("fN CONTEXT AFTER: ", mem.getCurrentContextRef(n.name));

                    // api.strLoad(fn.fnArgs[i], fn.callArgs[i]);
                    continue;
                }
                api.load(fn.fnArgs[i], fn.callArgs[i]);
            }
            this.api.call(n.name);
            break;
        case "halt":
            this.api.halt();
            break;
        case "ret":
            FnMemoryAlloc fn = semantic.functionsMemory[functionName];
            if (fn.callRet != -1)
                api.load(fn.callRet, fn.fnRet);
            this.api.ret();
            break;
        default:
            throw new Exception(format("Instrução desconhecida: %s", instr));
        }
    }

    void generatePrintInstruction(Instruction node)
    {
        if (node.args.length == 0)
            throw new Exception("'print' instruction needs one argument");

        int addr = this.getAddr(node.args[0]);
        if (node.args[0].kind == NodeKind.Identifier)
        {
            string varName = node.args[0].value.get!string;
            if (isStringVariable(varName))
            {
                this.api.strPrint(addr);
                return;
            }
        }

        this.api.print(addr);
    }

    void generateInputInstruction(Instruction node)
    {
        if (node.args.length == 0)
            throw new Exception("'input' instruction needs one argument.");

        int addr = this.getAddr(node.args[0]);
        if (node.args[0].kind == NodeKind.Identifier)
        {
            string varName = node.args[0].value.get!string;
            if (isStringVariable(varName))
            {
                this.api.strInput(addr);
                return;
            }
        }

        this.api.input(addr);
    }

public:
    this(ref FiberMemory mem, Semantic semantic)
    {
        this.semantic = semantic;
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

    // Método para finalizar e exportar dados para VM
    void finalize(ref int[512] vmMemory, ref string[] stringConstants)
    {
        mem.exportToVM(vmMemory, stringConstants);
    }

    // Método de debug
    void debugMemoryState()
    {
        writeln("=== Builder Debug - Memory State ===");
        mem.debugMemory();
    }
}
