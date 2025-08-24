module backend.vm.vm;

import std.stdio;
import std.string;
import std.conv;
import middle.memory.memory;
import backend.codegen.api;
import config;

enum OpCode
{
    MOV,
    ADD,
    SUB,
    DIV,
    MUL,
    LOAD,
    STORE,
    PRINT,
    INPUT,
    RET,
    JMP,
    CALL,
    HALT,

    STR_ALLOC, // Aloca string no heap
    STR_LOAD, // Carrega string literal
    STR_CONCAT, // Concatena duas strings
    STR_LEN, // Obtém comprimento da string
    STR_CMP, // Compara duas strings
    STR_PRINT, // Imprime string
    STR_INPUT // Lê string do usuário
}

class FiberVM
{
private:
    int[] program;
    int[MEMORY_BUFFER] memory;
    int[] stack;
    uint pointer;

    ubyte[1024] stringHeap;
    uint heapPointer = 0;

    // Pool de constantes de string
    string[] stringConstants;
    int[string] stringConstantMap;

    // Helpers
    void push(int value)
    {
        stack ~= value;
    }

    int pop()
    {
        if (stack.length == 0)
        {
            writeln("Error: Empty stack!");
            return 0;
        }
        int value = stack[$ - 1];
        stack = stack[0 .. $ - 1];
        return value;
    }

    int allocString(string text)
    {
        if (heapPointer + text.length + 4 >= stringHeap.length)
        {
            writeln("Error: String heap overflow!");
            return -1;
        }

        int startAddr = heapPointer;

        // Armazena comprimento (4 bytes)
        int len = cast(int) text.length;
        stringHeap[heapPointer .. heapPointer + 4] = (cast(ubyte*)&len)[0 .. 4];
        heapPointer += 4;

        // Armazena dados da string
        foreach (char c; text)
        {
            stringHeap[heapPointer++] = cast(ubyte) c;
        }

        return startAddr;
    }

    string readString(int addr)
    {
        if (addr < 0 || addr >= cast(int) stringHeap.length - 4)
            return "";

        // Lê comprimento
        int len = *(cast(int*)(stringHeap.ptr + addr));
        if (len <= 0 || addr + 4 + len > stringHeap.length)
            return "";

        // Lê dados
        char[] chars;
        chars.length = len;
        for (int i = 0; i < len; i++)
        {
            chars[i] = cast(char) stringHeap[addr + 4 + i];
        }

        return chars.idup;
    }

    int addStringConstant(string text)
    {
        if (text in stringConstantMap)
            return stringConstantMap[text];

        int id = cast(int) stringConstants.length;
        stringConstants ~= text;
        stringConstantMap[text] = id;
        return id;
    }

public:
    this(int[] prog, int[MEMORY_BUFFER] mem)
    {
        FiberBuilder.validateAndExtract(prog, this.program);
        stack = [];
        memory = mem;
    }

    ~this()
    {
        program = [];
        stack = [];
    }

    int next()
    {
        if (pointer >= program.length)
        {
            writeln("Error: Attempted to read beyond the end of the program!");
            return 0;
        }
        return program[pointer++];
    }

    void run()
    {
        while (pointer < program.length)
        {
            OpCode op = cast(OpCode) next();
            int r0, r1, r2, r3;
            final switch (op)
            {
            case OpCode.HALT:
                return;
            case OpCode.MOV:
                // MOV R0, 0
                // MOV 0x0, 0
                // MOVE o valor 0 para 0x0 no endereço
                r0 = next();
                int value = next();
                this.memory[r0] = value;
                break;
            case OpCode.ADD:
                // ADD R0, R1, R2
                r0 = next();
                r1 = next();
                r2 = next();
                this.memory[r0] = this.memory[r1] + this.memory[r2];
                break;
            case OpCode.SUB:
                // SUB R0, R1, R2
                r0 = next();
                r1 = next();
                r2 = next();
                this.memory[r0] = this.memory[r1] - this.memory[r2];
                break;
            case OpCode.MUL:
                // MUL R0, R1, R2
                r0 = next();
                r1 = next();
                r2 = next();
                this.memory[r0] = this.memory[r1] * this.memory[r2];
                break;
            case OpCode.DIV:
                // DIV R0, R1, R2
                r0 = next();
                r1 = next();
                r2 = next();
                this.memory[r0] = this.memory[r1] / this.memory[r2];
                break;
            case OpCode.STORE:
                // STORE R0, 0..256
                // 0..256 = addres
                r0 = next();
                int value = next();
                memory[r0] = value;
                break;
            case OpCode.LOAD:
                // LOAD R0, 0..256
                // 0..256 = addres
                r0 = next();
                int addres = next();
                this.memory[r0] = memory[addres];
                break;
            case OpCode.CALL:
                // CALL addres
                int callAddress = next();
                push(cast(int) pointer);
                pointer = cast(uint) callAddress;
                break;
            case OpCode.RET:
                // RET
                pointer = cast(uint) pop();
                break;
            case OpCode.JMP:
                // JMP addres
                int jmpAddress = next();
                pointer = cast(uint) jmpAddress;
                break;
            case OpCode.PRINT:
                // PRINT R0
                r0 = next();
                writeln(this.memory[r0]);
                break;
            case OpCode.INPUT:
                // INPUT R0
                r0 = next();
                write("Input: ");
                int value = to!int(readln().strip());
                this.memory[r0] = value;
                break;

            case OpCode.STR_ALLOC:
                // STR_ALLOC R0, string_constant_id
                // Aloca string do pool de constantes e armazena endereço em R0
                r0 = next();
                int stringId = next();
                if (stringId >= 0 && stringId < stringConstants.length)
                {
                    int addr = allocString(stringConstants[stringId]);
                    this.memory[r0] = addr;
                }
                else
                {
                    this.memory[r0] = -1;
                }
                break;

            case OpCode.STR_LOAD:
                // STR_LOAD R0, string_constant_id
                // Carrega endereço da string constante em R0
                r0 = next();
                int constId = next();
                if (constId >= 0 && constId < stringConstants.length)
                {
                    // Para simplificar, aloca uma nova cópia
                    int addr = allocString(stringConstants[constId]);
                    this.memory[r0] = addr;
                }
                break;

            case OpCode.STR_CONCAT:
                // STR_CONCAT R0, R1, R2
                // Concatena strings em R1 e R2, resultado em R0
                r0 = next();
                r1 = next();
                r2 = next();
                string str1 = readString(this.memory[r1]);
                string str2 = readString(this.memory[r2]);
                int resultAddr = allocString(str1 ~ str2);
                this.memory[r0] = resultAddr;
                break;

            case OpCode.STR_LEN:
                // STR_LEN R0, R1
                // Obtém comprimento da string em R1, resultado em R0
                r0 = next();
                r1 = next();
                string str = readString(this.memory[r1]);
                this.memory[r0] = cast(int) str.length;
                break;

            case OpCode.STR_CMP:
                // STR_CMP R0, R1, R2
                // Compara strings em R1 e R2, resultado em R0 (0=iguais, <0 ou >0)
                r0 = next();
                r1 = next();
                r2 = next();
                string str1 = readString(this.memory[r1]);
                string str2 = readString(this.memory[r2]);
                import std.algorithm : cmp;

                this.memory[r0] = cmp(str1, str2);
                break;

            case OpCode.STR_PRINT:
                // STR_PRINT R0
                // Imprime string cujo endereço está em R0
                r0 = next();
                string str = readString(this.memory[r0]);
                writeln(str);
                break;

            case OpCode.STR_INPUT:
                // STR_INPUT R0
                // Lê string do usuário e armazena endereço em R0
                r0 = next();
                write("Input string: ");
                string input = readln().strip();
                int addr = allocString(input);
                this.memory[r0] = addr;
                break;
            }
        }
    }

    // Método para adicionar constantes de string durante a compilação
    void addStringLiteral(string literal)
    {
        addStringConstant(literal);
    }

    // Método para obter ID de uma string constante
    int getStringConstantId(string literal)
    {
        return addStringConstant(literal);
    }
}

// void main()
// {
//     auto mem = new int[MEMORY_BUFFER];

//     // Programa de exemplo que trabalha com strings
//     FiberVM vm = new FiberVM([], mem);

//     // Adicionar constantes de string
//     int helloId = vm.getStringConstantId("Hello");
//     int worldId = vm.getStringConstantId(" World!");
//     int nameId = vm.getStringConstantId("Fiber");

//     int[] prog = [
//         // Carregar "Hello" em R0
//         OpCode.STR_LOAD, 0, helloId,

//         // Carregar " World!" em R1  
//         OpCode.STR_LOAD, 1, worldId,

//         // Concatenar R0 + R1, resultado em R2
//         OpCode.STR_CONCAT, 2, 0, 1,

//         // Imprimir resultado
//         OpCode.STR_PRINT, 2,

//         // Obter comprimento da string em R2, resultado em R3
//         OpCode.STR_LEN, 3, 2,
//         OpCode.PRINT, 3, // Imprimir comprimento

//         OpCode.HALT
//     ];

//     vm.program = prog;
//     vm.run();
// }
