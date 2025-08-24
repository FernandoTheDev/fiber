module backend.codegen.api;

import std.stdio;
import std.conv;
import std.format;

enum Reg
{
    R0 = 0,
    R1 = 1,
    R2 = 2,
    R3 = 3
}

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
    HALT
}

// Classe principal para construção de código
class FiberBuilder
{
private:
    static immutable int[] HEADER = [
        70, 101, 114, 110, 97, 110, 100, 111, 68, 101, 118
    ]; // "FernandoDev"
    static immutable int[] FOOTER = [70, 105, 98, 101, 114]; // "Fiber"

    int[] instructions; // código binário gerado
    int[string] labels; // mapeamento label -> posição
    string[][int] pendingLabels; // labels pendentes por posição

public:
    FiberBuilder mov(int addr, int value)
    {
        instructions ~= cast(int) OpCode.MOV;
        instructions ~= addr;
        instructions ~= value;
        return this;
    }

    FiberBuilder add(int addr, int addr1, int addr2)
    {
        instructions ~= cast(int) OpCode.ADD;
        instructions ~= addr;
        instructions ~= addr1;
        instructions ~= addr2;
        return this;
    }

    FiberBuilder sub(int addr, int addr1, int addr2)
    {
        instructions ~= cast(int) OpCode.SUB;
        instructions ~= addr;
        instructions ~= addr1;
        instructions ~= addr2;
        return this;
    }

    FiberBuilder mul(int addr, int addr1, int addr2)
    {
        instructions ~= cast(int) OpCode.MUL;
        instructions ~= addr;
        instructions ~= addr1;
        instructions ~= addr2;
        return this;
    }

    FiberBuilder div(int addr, int addr1, int addr2)
    {
        instructions ~= cast(int) OpCode.DIV;
        instructions ~= addr;
        instructions ~= addr1;
        instructions ~= addr2;
        return this;
    }

    FiberBuilder load(int addr, int address)
    {
        instructions ~= cast(int) OpCode.LOAD;
        instructions ~= addr;
        instructions ~= address;
        return this;
    }

    FiberBuilder store(int addr, int address)
    {
        instructions ~= cast(int) OpCode.STORE;
        instructions ~= addr;
        instructions ~= address;
        return this;
    }

    FiberBuilder print(int addr)
    {
        instructions ~= cast(int) OpCode.PRINT;
        instructions ~= addr;
        return this;
    }

    FiberBuilder input(int addr)
    {
        instructions ~= cast(int) OpCode.INPUT;
        instructions ~= addr;
        return this;
    }

    FiberBuilder jmp(string label)
    {
        instructions ~= cast(int) OpCode.JMP;
        int pos = cast(int) instructions.length;
        instructions ~= 0; // placeholder

        // Registra label pendente
        if (label in labels)
        {
            instructions[pos] = labels[label];
        }
        else
        {
            pendingLabels[pos] ~= label;
        }

        return this;
    }

    FiberBuilder jmp(int address)
    {
        instructions ~= cast(int) OpCode.JMP;
        instructions ~= address;
        return this;
    }

    FiberBuilder call(string label)
    {
        instructions ~= cast(int) OpCode.CALL;
        int pos = cast(int) instructions.length;
        instructions ~= 0; // placeholder

        if (label in labels)
        {
            instructions[pos] = labels[label];
        }
        else
        {
            pendingLabels[pos] ~= label;
        }

        return this;
    }

    FiberBuilder call(int address)
    {
        instructions ~= cast(int) OpCode.CALL;
        instructions ~= address;
        return this;
    }

    FiberBuilder ret()
    {
        instructions ~= cast(int) OpCode.RET;
        return this;
    }

    FiberBuilder halt()
    {
        instructions ~= cast(int) OpCode.HALT;
        return this;
    }

    FiberBuilder label(string name)
    {
        int currentPos = cast(int) instructions.length;
        labels[name] = currentPos;

        // Resolve labels pendentes
        if (currentPos in pendingLabels)
        {
            foreach (pendingLabel; pendingLabels[currentPos])
            {
                // Encontra onde esse label estava sendo referenciado
                for (int i = 0; i < instructions.length; i++)
                {
                    if (i in pendingLabels)
                    {
                        foreach (j, pending; pendingLabels[i])
                        {
                            if (pending == name)
                            {
                                instructions[i] = currentPos;
                            }
                        }
                    }
                }
            }
            pendingLabels.remove(currentPos);
        }

        return this;
    }

    int getCurrentAddress()
    {
        return cast(int) instructions.length;
    }

    int[] build()
    {
        foreach (pos, labelList; pendingLabels)
        {
            foreach (labelName; labelList)
            {
                if (labelName in labels)
                {
                    instructions[pos] = labels[labelName];
                }
                else
                {
                    throw new Exception("Label não encontrado: " ~ labelName);
                }
            }
        }

        this.addSignatures(this.instructions);
        return instructions.dup;
    }

    // Para debug - mostra o assembly gerado
    string disassemble()
    {
        string result;
        int pos = 0;

        // Mostra labels
        int[][string] labelsByPos;
        foreach (labelName, labelPos; labels)
        {
            labelsByPos[labelName] = [labelPos];
        }

        int[] instr;
        this.validateAndExtract(this.instructions, instr);

        while (pos < instr.length)
        {
            // Mostra labels nesta posição
            foreach (labelName, positions; labelsByPos)
            {
                if (positions.length > 0 && positions[0] == pos)
                {
                    result ~= labelName ~ ":\n";
                }
            }

            OpCode op = cast(OpCode) instr[pos];
            result ~= format("  %04X: ", pos);

            final switch (op)
            {
            case OpCode.HALT:
                result ~= "HALT\n";
                pos += 1;
                break;

            case OpCode.RET:
                result ~= "RET\n";
                pos += 1;
                break;

            case OpCode.PRINT:
                result ~= format("PRINT 0x%d\n", instr[pos + 1]);
                pos += 2;
                break;

            case OpCode.INPUT:
                result ~= format("INPUT 0x%d\n", instr[pos + 1]);
                pos += 2;
                break;

            case OpCode.JMP:
                result ~= format("JMP 0x%X\n", instr[pos + 1]);
                pos += 2;
                break;

            case OpCode.CALL:
                result ~= format("CALL 0x%X\n", instr[pos + 1]);
                pos += 2;
                break;

            case OpCode.MOV:
                result ~= format("MOV 0x%d, %d\n",
                    instr[pos + 1], instr[pos + 2]);
                pos += 3;
                break;

            case OpCode.LOAD:
                result ~= format("LOAD 0x%d, 0x%X\n",
                    instr[pos + 1], instr[pos + 2]);
                pos += 3;
                break;

            case OpCode.STORE:
                result ~= format("STORE 0x%d, 0x%X\n",
                    instr[pos + 1], instr[pos + 2]);
                pos += 3;
                break;

            case OpCode.ADD:
                result ~= format("ADD 0x%d, 0x%d, 0x%d\n",
                    instr[pos + 1], instr[pos + 2], instr[pos + 3]);
                pos += 4;
                break;

            case OpCode.SUB:
                result ~= format("SUB 0x%d, 0x%d, 0x%d\n",
                    instr[pos + 1], instr[pos + 2], instr[pos + 3]);
                pos += 4;
                break;

            case OpCode.MUL:
                result ~= format("MUL 0x%d, 0x%d, 0x%d\n",
                    instr[pos + 1], instr[pos + 2], instr[pos + 3]);
                pos += 4;
                break;

            case OpCode.DIV:
                result ~= format("DIV 0x%d, 0x%d, 0x%d\n",
                    instr[pos + 1], instr[pos + 2], instr[pos + 3]);
                pos += 4;
                break;
            }
        }

        return result;
    }

    static bool validateHeader(const int[] bytecode)
    {
        if (bytecode.length < HEADER.length)
            return false;

        return bytecode[0 .. HEADER.length] == HEADER;
    }

    static bool validateFooter(const int[] bytecode)
    {
        if (bytecode.length < FOOTER.length)
            return false;

        return bytecode[$ - FOOTER.length .. $] == FOOTER;
    }

    static void addSignatures(ref int[] bytecode)
    {
        int[] newBytecode = HEADER.dup;
        newBytecode ~= bytecode;
        newBytecode ~= FOOTER;

        bytecode = newBytecode;
    }

    static bool validateAndExtract(ref int[] bytecode, out int[] cleanBytecode)
    {
        if (bytecode.length < HEADER.length + FOOTER.length)
        {
            writeln("Error: Bytecode too small for header/footer");
            return false;
        }

        if (!validateHeader(bytecode))
        {
            writeln("Error: Invalid header signature");
            return false;
        }

        if (!validateFooter(bytecode))
        {
            writeln("Error: Invalid footer signature");
            return false;
        }

        cleanBytecode = bytecode[HEADER.length .. $ - FOOTER.length];
        return true;
    }
}
